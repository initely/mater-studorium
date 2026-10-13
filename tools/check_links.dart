// Проверка ссылок и цитат колоды (ТЗ M12, AC12.2, §5.3 п. 3).
//
//   dart run tools/check_links.dart <deck.json>... [--timeout=<сек>]
//       [--delay-ms=<мс>] [--user-agent=<строка>]
//
// Для каждого источника из `sources` делает GET (с редиректами) и требует
// итоговый ответ 200. Для каждой `ref` ищет `quote` в тексте страницы после
// нормализации (без HTML-тегов, скриптов и стилей; сущности раскрыты;
// типографские кавычки и тире приведены к ASCII; регистр и пробелы не важны).
// Ссылки с `quote_unverifiable: true` проверяются только на 200.
//
// Сетевой инструмент: в CI не запускается, только вручную (content/PIPELINE.md).
// Коды выхода: 0 — проблем нет, 1 — найдены проблемы, 2 — неверные аргументы
// или колода не читается.
//
// Только чистый Dart: никаких импортов Flutter.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mater_studorium/features/catalog/domain/deck.dart';

const exitOk = 0;
const exitProblems = 1;
const exitUsage = 2;

const defaultTimeout = Duration(seconds: 30);
const defaultDelay = Duration(milliseconds: 1000);
const defaultUserAgent =
    'MaterStudoriumCheckLinks/1.0 (content pipeline; polite, 1 req/s)';

/// Страницы больше этого размера не читаем до конца (защита от мусора).
const _maxBodyBytes = 10 * 1024 * 1024;
const _maxRedirects = 5;

const _usage = '''
Использование: dart run tools/check_links.dart <deck.json>... [опции]
  --timeout=<сек>       таймаут одного запроса (по умолчанию 30)
  --delay-ms=<мс>       пауза между запросами (по умолчанию 1000)
  --user-agent=<строка> заголовок User-Agent''';

Future<void> main(List<String> args) async {
  exitCode = await runCheckLinks(args, out: stdout, err: stderr);
}

/// Точка входа без `exit`, чтобы её можно было вызывать из тестов.
Future<int> runCheckLinks(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) async {
  var timeout = defaultTimeout;
  var delay = defaultDelay;
  var userAgent = defaultUserAgent;
  final files = <String>[];
  for (final arg in args) {
    if (arg == '-h' || arg == '--help') {
      out.writeln(_usage);
      return exitOk;
    } else if (arg.startsWith('--timeout=')) {
      final s = int.tryParse(arg.substring('--timeout='.length));
      if (s == null || s <= 0) return _usageError(err, 'Плохой $arg');
      timeout = Duration(seconds: s);
    } else if (arg.startsWith('--delay-ms=')) {
      final ms = int.tryParse(arg.substring('--delay-ms='.length));
      if (ms == null || ms < 0) return _usageError(err, 'Плохой $arg');
      delay = Duration(milliseconds: ms);
    } else if (arg.startsWith('--user-agent=')) {
      userAgent = arg.substring('--user-agent='.length);
    } else if (arg.startsWith('-')) {
      return _usageError(err, 'Неизвестный флаг: $arg');
    } else {
      files.add(arg);
    }
  }
  if (files.isEmpty) return _usageError(err, 'Не указана колода');

  final client = HttpClient()
    ..userAgent = userAgent
    ..connectionTimeout = timeout;
  final fetcher = _Fetcher(client, timeout, delay);
  try {
    var code = exitOk;
    for (final file in files) {
      final fileCode = await _checkFile(file, fetcher, out, err);
      if (fileCode > code) code = fileCode;
    }
    return code;
  } finally {
    client.close(force: true);
  }
}

int _usageError(StringSink err, String message) {
  err.writeln('$message\n$_usage');
  return exitUsage;
}

Future<int> _checkFile(
  String file,
  _Fetcher fetcher,
  StringSink out,
  StringSink err,
) async {
  final Deck deck;
  try {
    final json = jsonDecode(File(file).readAsStringSync());
    deck = Deck.fromJson(json as Map<String, dynamic>);
  } on Object catch (e) {
    err.writeln(
      '$file: колода не читается ($e); сначала tools/validate_deck.dart',
    );
    return exitUsage;
  }

  final problems = <String>[];
  final pages = <String, _Page>{};
  for (final (i, source) in deck.sources.indexed) {
    final page = await fetcher.get(source.url);
    pages[source.id] = page;
    if (page.error != null) {
      problems.add(
        '[url] /sources/$i ${source.id} ${source.url}: ${page.error}',
      );
    }
  }

  var quotesChecked = 0;
  var statusOnly = 0;
  for (final (i, item) in deck.items.indexed) {
    for (final (r, ref) in item.refs.indexed) {
      final where = '/items/$i/refs/$r (${item.id}, ${ref.sourceId})';
      final page = pages[ref.sourceId];
      if (page == null) {
        problems.add('[ref] $where: источник не объявлен в /sources');
        continue;
      }
      // Недоступная страница уже в отчёте как [url]; цитату не ищем.
      if (page.error != null) continue;
      if (ref.quoteUnverifiable) {
        statusOnly++;
        continue;
      }
      quotesChecked++;
      if (!page.text.contains(normalizeText(ref.quote))) {
        problems.add(
          '[quote] $where: цитата не найдена на странице: '
          '"${_preview(ref.quote)}"',
        );
      }
    }
  }

  for (final p in problems) {
    err.writeln('$file: $p');
  }
  final stats =
      'источников: ${deck.sources.length}, цитат проверено: $quotesChecked, '
      'только HTTP 200 (quote_unverifiable): $statusOnly';
  if (problems.isNotEmpty) {
    err.writeln('$file: ПРОБЛЕМЫ (${problems.length}) — $stats');
    return exitProblems;
  }
  out.writeln('$file: OK — $stats');
  return exitOk;
}

String _preview(String s) => s.length <= 80 ? s : '${s.substring(0, 80)}…';

/// Загруженная страница: нормализованный текст или описание ошибки.
final class _Page {
  const _Page.ok(this.text) : error = null;
  const _Page.failed(String this.error) : text = '';

  final String text;
  final String? error;
}

/// GET с таймаутом, редиректами и паузой между запросами.
final class _Fetcher {
  _Fetcher(this._client, this._timeout, this._delay);

  final HttpClient _client;
  final Duration _timeout;
  final Duration _delay;
  final _cache = <String, _Page>{};
  var _first = true;

  Future<_Page> get(String url) async {
    final cached = _cache[url];
    if (cached != null) return cached;
    if (!_first) await Future<void>.delayed(_delay);
    _first = false;
    final page = await _load(url);
    _cache[url] = page;
    return page;
  }

  Future<_Page> _load(String url) async {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException catch (e) {
      return _Page.failed('некорректный URL: ${e.message}');
    }
    try {
      return await _request(uri).timeout(_timeout);
    } on TimeoutException {
      return _Page.failed('таймаут ${_timeout.inSeconds} с');
    } on Object catch (e) {
      return _Page.failed('ошибка запроса: $e');
    }
  }

  Future<_Page> _request(Uri uri) async {
    final request = await _client.getUrl(uri);
    request
      ..followRedirects = true
      ..maxRedirects = _maxRedirects
      ..headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5',
      );
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      final via = response.redirects.isEmpty
          ? ''
          : ' (после редиректа на ${response.redirects.last.location})';
      return _Page.failed('HTTP ${response.statusCode}$via');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBodyBytes) {
        return const _Page.failed('страница больше $_maxBodyBytes байт');
      }
    }
    return _Page.ok(
      normalizeText(htmlToText(utf8.decode(bytes, allowMalformed: true))),
    );
  }
}

// ---------------------------------------------------------------------------
// Текст страницы и нормализация. Публичные — для тестов.

final _comment = RegExp(r'<!--.*?-->', dotAll: true);
final _invisible = RegExp(
  r'<(script|style|noscript|template|svg)\b[^>]*>.*?</\1\s*>',
  caseSensitive: false,
  dotAll: true,
);

/// Теги, на границе которых в тексте страницы есть разрыв: заменяются
/// пробелом, чтобы слова соседних блоков не слиплись. Остальные (inline:
/// `a`, `code`, `em`…) удаляются без пробела, как их и видит читатель.
final _blockTag = RegExp(
  r'</?(?:address|article|aside|blockquote|br|caption|dd|details|div|dl|dt|'
  r'figcaption|figure|footer|form|h[1-6]|header|hr|li|main|nav|ol|option|p|'
  r'pre|section|summary|table|tbody|td|tfoot|th|thead|title|tr|ul)\b[^>]*>',
  caseSensitive: false,
);
final _anyTag = RegExp(r'<[^>]*>');

/// Видимый текст HTML: без комментариев, скриптов, стилей и тегов;
/// HTML-сущности раскрыты. Для не-HTML текста почти ничего не меняет.
String htmlToText(String html) => decodeEntities(
  html
      .replaceAll(_comment, ' ')
      .replaceAll(_invisible, ' ')
      .replaceAll(_blockTag, ' ')
      .replaceAll(_anyTag, ''),
);

final _entity = RegExp(r'&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);');

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'lsquo': '‘',
  'rsquo': '’',
  'sbquo': '‚',
  'ldquo': '“',
  'rdquo': '”',
  'bdquo': '„',
  'laquo': '«',
  'raquo': '»',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'shy': '\u00AD',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'para': '¶',
  'sect': '§',
  'times': '×',
  'thinsp': ' ',
  'zwj': '\u200D',
  'zwnj': '\u200C',
};

/// Раскрывает числовые и распространённые именованные сущности;
/// неизвестные оставляет как есть.
String decodeEntities(String s) => s.replaceAllMapped(_entity, (m) {
  final body = m[1]!;
  if (body.startsWith('#')) {
    final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
    final code = int.tryParse(
      hex ? body.substring(2) : body.substring(1),
      radix: hex ? 16 : 10,
    );
    if (code == null || code <= 0 || code > 0x10FFFF) return m[0]!;
    return String.fromCharCode(code);
  }
  return _namedEntities[body] ?? m[0]!;
});

final _singleQuotes = RegExp('[‘’‚‛′`´]');
final _doubleQuotes = RegExp('[“”„‟″«»]');
final _dashes = RegExp('[‐‑‒–—―−]');
final _invisibleChars = RegExp('[\u00AD\u200B\u200C\u200D\u2060\uFEFF]');
final _spaces = RegExp(r'\s+');

/// Нормализация для поиска цитаты (обе стороны): регистр, ё→е,
/// типографские кавычки и тире → ASCII, многоточие → три точки,
/// невидимые символы удалены, любые пробелы схлопнуты.
String normalizeText(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(_singleQuotes, "'")
    .replaceAll(_doubleQuotes, '"')
    .replaceAll(_dashes, '-')
    .replaceAll('…', '...')
    .replaceAll(_invisibleChars, '')
    .replaceAll(_spaces, ' ')
    .trim();
