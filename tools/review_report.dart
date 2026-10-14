// Отчёт для вычитки колоды человеком (шаг 5 конвейера, content/PIPELINE.md):
// по каждому знанию факт, вопросы, цитаты, вердикт независимой проверки
// (шаг 4) и чекбокс.
//
//   dart run tools/review_report.dart <deck.json> [--verify=<report.json>]
//       [--out=docs/reviews/REVIEW_<deck-id>.md]
//
// Без --out отчёт печатается в stdout. `--verify` — JSON из
// `content/prompts/verify.md`; без него в отчёте нет вердиктов проверки.
// Колоду инструмент не меняет. Коды выхода: 0 — готово; 1 — отчёт проверки не
// соответствует колоде; 2 — неверные аргументы или файлы не читаются.
//
// Только чистый Dart: никаких импортов Flutter (ТЗ §6.1, CLAUDE.md).
import 'dart:convert';
import 'dart:io';

const exitOk = 0;
const exitMismatch = 1;
const exitUsage = 2;

const _usage = '''
Использование: dart run tools/review_report.dart <deck.json> [--verify=<report.json>] [--out=<file.md>]''';

void main(List<String> args) {
  exitCode = runReviewReport(args, out: stdout, err: stderr);
}

/// Точка входа без `exit`, чтобы её можно было вызывать из тестов.
int runReviewReport(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) {
  String? deckPath;
  String? verifyPath;
  String? outPath;
  for (final arg in args) {
    if (arg == '-h' || arg == '--help') {
      out.writeln(_usage);
      return exitOk;
    } else if (arg.startsWith('--verify=')) {
      verifyPath = arg.substring('--verify='.length);
    } else if (arg.startsWith('--out=')) {
      outPath = arg.substring('--out='.length);
    } else if (arg.startsWith('-') || deckPath != null) {
      err.writeln('Неожиданный аргумент: $arg\n$_usage');
      return exitUsage;
    } else {
      deckPath = arg;
    }
  }
  if (deckPath == null) {
    err.writeln(_usage);
    return exitUsage;
  }

  final Map<String, dynamic> deck;
  Map<String, dynamic>? verify;
  try {
    deck = _readObject(deckPath);
    if (verifyPath != null) verify = _readObject(verifyPath);
  } on FormatException catch (e) {
    err.writeln(e.message);
    return exitUsage;
  } on FileSystemException catch (e) {
    err.writeln('${e.path}: не удалось прочитать файл: ${e.message}');
    return exitUsage;
  }

  final String report;
  try {
    report = buildReviewReport(deck, deckPath: deckPath, verify: verify);
  } on FormatException catch (e) {
    err.writeln(e.message);
    return exitMismatch;
  }
  if (outPath == null) {
    out.write(report);
  } else {
    File(outPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(report);
    out.writeln('$outPath: отчёт записан');
  }
  return exitOk;
}

Map<String, dynamic> _readObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$path: ожидался JSON-объект');
  }
  return decoded;
}

/// Собирает Markdown-отчёт. [verify] — отчёт проверяющего (verify.md);
/// если он не сходится с колодой по id знаний и вопросов, бросает
/// [FormatException].
String buildReviewReport(
  Map<String, dynamic> deck, {
  required String deckPath,
  Map<String, dynamic>? verify,
}) {
  final items = (deck['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  final sources = {
    for (final s
        in (deck['sources'] as List<dynamic>).cast<Map<String, dynamic>>())
      s['id'] as String: s,
  };
  final verdicts = verify == null ? null : _indexVerify(verify, items);

  final buf = StringBuffer()
    ..writeln('# Вычитка колоды `${deck['id']}` (v${deck['version']})')
    ..writeln()
    ..writeln(
      '${deck['title']}. Знаний: ${items.length}. '
      'Файл: `$deckPath`.',
    )
    ..writeln()
    ..writeln(
      'Статусы в колоде: draft или needs_fix; `approved` ставит '
      'только человек командой в конце отчёта. Дословность цитат и код '
      '200 страниц проверяет `tools/check_links.dart` (шаг 3), смысл — '
      'независимая сессия по `content/prompts/verify.md` (шаг 4).',
    )
    ..writeln();

  if (verdicts != null) {
    final ok = items.where((i) => _itemVerdict(verdicts, i) == 'ok').length;
    buf
      ..writeln('| Проверка | Знаний |')
      ..writeln('|---|---|')
      ..writeln('| ok | $ok |')
      ..writeln('| needs_fix | ${items.length - ok} |')
      ..writeln();
  } else {
    buf
      ..writeln('Независимая проверка к отчёту не приложена.')
      ..writeln();
  }

  buf
    ..writeln('## Как вычитывать')
    ..writeln()
    ..writeln(
      '1. Для каждого знания откройте страницу источника по ссылке и '
      'сверьте цитату и факт.',
    )
    ..writeln(
      '2. Проверьте вопросы: в `mcq` ровно один верный ответ, в '
      '`cloze` учтены естественные варианты, в `find_error` нет ошибок в '
      'строках, не помеченных ошибочными.',
    )
    ..writeln(
      '3. Отметьте чекбокс у знаний, которые одобряете. Правки '
      'вносите в колоду, а не в отчёт.',
    )
    ..writeln(
      '4. Выполните команду из раздела «Одобрение» '
      '(оставьте только отмеченные id).',
    )
    ..writeln();

  for (var n = 0; n < items.length; n++) {
    _writeItem(buf, n + 1, items[n], sources, verdicts);
  }

  buf
    ..writeln('## Одобрение')
    ..writeln()
    ..writeln(
      'Команда ниже перечисляет знания с вердиктом проверки `ok`; '
      'уберите те, что не одобряете, и подставьте своё имя. Знания с '
      '`needs_fix` сначала исправьте.',
    )
    ..writeln()
    ..writeln('```');
  final okIds = [
    for (final i in items)
      if (verdicts != null && _itemVerdict(verdicts, i) == 'ok')
        i['id'] as String,
  ];
  buf
    ..writeln('dart run tools/approve_items.dart $deckPath \\')
    ..writeln(
      okIds.isEmpty
          ? '  <id>... --by "<имя>"'
          : '  ${okIds.join(' \\\n  ')} \\\n  --by "<имя>"',
    )
    ..writeln('```')
    ..writeln()
    ..writeln(
      'После этого: `dart run tools/validate_deck.dart $deckPath '
      '--release` (пройдёт, когда одобрены все знания).',
    );
  return buf.toString();
}

typedef _Verify = Map<String, Map<String, dynamic>>;

/// Индекс отчёта проверяющего по `item_id`; проверяет полноту и соответствие.
_Verify _indexVerify(
  Map<String, dynamic> verify,
  List<Map<String, dynamic>> items,
) {
  final list = (verify['items'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  final byId = {for (final v in list) v['item_id'] as String: v};
  for (final item in items) {
    final id = item['id'] as String;
    final v = byId[id];
    if (v == null) {
      throw FormatException('В отчёте проверки нет знания $id');
    }
    final qIds = {
      for (final q
          in (v['questions'] as List<dynamic>).cast<Map<String, dynamic>>())
        q['question_id'] as String,
    };
    for (final q
        in (item['questions'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      if (!qIds.contains(q['id'])) {
        throw FormatException('В отчёте проверки нет вопроса ${q['id']}');
      }
    }
  }
  final known = items.map((i) => i['id']).toSet();
  for (final id in byId.keys) {
    if (!known.contains(id)) {
      throw FormatException('В отчёте проверки лишнее знание $id');
    }
  }
  return byId;
}

String _itemVerdict(_Verify verdicts, Map<String, dynamic> item) =>
    verdicts[item['id']]!['verdict'] as String;

void _writeItem(
  StringBuffer buf,
  int number,
  Map<String, dynamic> item,
  Map<String, Map<String, dynamic>> sources,
  _Verify? verdicts,
) {
  final id = item['id'] as String;
  final v = verdicts?[id];
  final verdict = v?['verdict'] as String?;
  final mark = switch (verdict) {
    'ok' => '✅ ok',
    null => 'проверка не приложена',
    _ => '⚠️ $verdict',
  };
  final review = item['review'] as Map<String, dynamic>;

  buf
    ..writeln('## $number. ${item['title']}')
    ..writeln()
    ..writeln('- [ ] одобряю `$id`')
    ..writeln(
      '- Вердикт независимой проверки: **$mark**; статус в колоде: '
      '`${review['status']}`',
    )
    ..writeln()
    ..writeln('**Факт.** ${item['fact']}')
    ..writeln()
    ..writeln('**Коротко.** ${item['explanation_short']}')
    ..writeln();

  buf.writeln('**Цитаты:**');
  buf.writeln();
  for (final r
      in (item['refs'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    final s = sources[r['source_id']]!;
    buf
      ..writeln('> ${_oneLine(r['quote'] as String)}')
      ..writeln('>')
      ..writeln(
        '> — [${s['title']}](${s['url']}), ${s['license']}'
        '${r['quote_unverifiable'] == true ? ' (цитата не проверяется автоматически)' : ''}',
      )
      ..writeln();
  }

  buf.writeln('**Вопросы:**');
  buf.writeln();
  final qVerdicts = {
    for (final q
        in (v?['questions'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
      q['question_id'] as String: q,
  };
  for (final q
      in (item['questions'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    _writeQuestion(buf, q, qVerdicts[q['id']]);
  }

  final claims = (v?['unsupported_claims'] as List<dynamic>? ?? const []);
  if (claims.isNotEmpty) {
    buf.writeln('**Утверждения без опоры в цитатах (по мнению проверки):**');
    buf.writeln();
    for (final c in claims) {
      buf.writeln('- ${_oneLine('$c')}');
    }
    buf.writeln();
  }
  final notes = (review['notes'] as String?) ?? '';
  if (notes.trim().isNotEmpty) {
    buf
      ..writeln('**Заметки генерации (что проверить):** ${_oneLine(notes)}')
      ..writeln();
  }
  buf
    ..writeln('---')
    ..writeln();
}

void _writeQuestion(
  StringBuffer buf,
  Map<String, dynamic> q,
  Map<String, dynamic>? v,
) {
  final payload = q['payload'] as Map<String, dynamic>;
  buf.writeln(
    '- `${q['id']}` · **${q['type']}** · ${_oneLine(q['prompt'] as String)}',
  );
  switch (q['type']) {
    case 'mcq':
      final correct = (payload['correct'] as List<dynamic>).toSet();
      for (final o
          in (payload['options'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        final right = correct.contains(o['id']);
        buf.writeln(
          '  - ${right ? '✅' : '▫️'} ${o['id']}) ${_oneLine(o['text'] as String)}',
        );
      }
    case 'flip':
      buf.writeln('  - Оборот: ${_oneLine(payload['back'] as String)}');
    case 'open':
      buf.writeln(
        '  - Эталон: ${_oneLine(payload['reference_answer'] as String)}',
      );
      for (final p
          in (payload['rubric'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        buf.writeln(
          '  - Рубрика ${p['id']} (вес ${p['weight']}'
          '${p['required'] == true ? ', обязательный' : ''}): '
          '${_oneLine(p['text'] as String)}',
        );
      }
    case 'cloze':
      for (final b
          in (payload['blanks'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        buf.writeln(
          '  - Пропуск {{${b['id']}}}: '
          '${(b['accepted'] as List<dynamic>).map((a) => '`$a`').join(', ')}',
        );
      }
    case 'order':
      final steps = (payload['steps'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (var i = 0; i < steps.length; i++) {
        buf.writeln('  - ${i + 1}. ${_oneLine(steps[i]['text'] as String)}');
      }
    case 'find_error':
      final errors = (payload['error_lines'] as List<dynamic>).toSet();
      final lines = (payload['lines'] as List<dynamic>).cast<String>();
      buf.writeln('  ```${payload['language'] ?? ''}');
      for (var i = 0; i < lines.length; i++) {
        buf.writeln(
          '  ${errors.contains(i + 1) ? '>>' : '  '} ${i + 1}: ${lines[i]}',
        );
      }
      buf.writeln('  ```');
      final expl = payload['line_explanations'] as Map<String, dynamic>;
      for (final e in expl.entries) {
        buf.writeln('  - Строка ${e.key}: ${_oneLine(e.value as String)}');
      }
  }
  if (v != null) {
    final issues = (v['issues'] as List<dynamic>).cast<String>();
    buf.writeln(
      '  - Проверка: цитата подтверждает ответ — '
      '`${v['quote_supports_answer']}`; вторая верная — '
      '`${v['second_correct_option']}`; однозначно — `${v['unambiguous']}`'
      '${issues.isEmpty ? '' : '; замечания: ${issues.map(_oneLine).join(' / ')}'}',
    );
  }
  buf.writeln();
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
