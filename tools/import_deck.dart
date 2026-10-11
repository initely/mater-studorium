// Импорт колоды в Supabase (ТЗ M2, M12, AC12.3, ADR-21).
//
//   dart run tools/import_deck.dart <deck.json> [--env=.env] [--allow-draft]
//       [--schema=content/schema/deck.schema.json]
//
// Шаги: validate_deck --release → проверка версии и коллизий item_id →
// загрузка файла `decks/<id>/v<version>.json` в Storage → upsert строки `decks`.
// Файл грузится раньше строки, чтобы клиент не увидел колоду без файла.
//
// URL проекта и ключ service role берутся из env-файла (по умолчанию `.env` в
// корне; он в .gitignore): SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY. Ключ
// service role никогда не попадает в клиент и в git (CLAUDE.md, правило 6).
//
// `--allow-draft` пропускает `--release` (знания не approved) и разрешён только
// для локального Supabase: SUPABASE_URL должен указывать на localhost,
// 127.0.0.1 или ::1. Для остальных проектов флаг отклоняется.
//
// Коды выхода: 0 — импортировано; 1 — колода отклонена (валидация, версия,
// коллизия item_id); 2 — неверные аргументы или env; 3 — сбой сервера или сети.
//
// Только чистый Dart, без Flutter.
import 'dart:convert';
import 'dart:io';

import 'package:mater_studorium/features/catalog/domain/deck.dart';

import 'supabase_deck_backend.dart';
import 'validate_deck.dart'
    show defaultSchemaPath, exitInvalid, exitOk, runValidateDeck;

const defaultEnvPath = '.env';

// Код 0 — `exitOk` из validate_deck.dart.
const importRejected = 1;
const importUsage = 2;
const importBackendFailed = 3;

const _usage =
    '''
Использование: dart run tools/import_deck.dart <deck.json> [--env=<path>] [--allow-draft] [--schema=<path>]
  --env=<path>     env-файл с SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY (по умолчанию $defaultEnvPath)
  --allow-draft    не требовать review.status = approved; только для локального Supabase
  --schema=<path>  JSON Schema колоды (по умолчанию $defaultSchemaPath)''';

Future<void> main(List<String> args) async {
  exitCode = await runImportDeck(args, out: stdout, err: stderr);
}

/// Локальный Supabase: только loopback, чтобы `--allow-draft` не попал в
/// настоящий проект.
bool isLocalSupabaseUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) return false;
  return const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
}

/// Разбор env-файла: `KEY=VALUE`, комментарии `#`, необязательные кавычки.
Map<String, String> parseEnv(String text) {
  final env = <String, String>{};
  for (var line in const LineSplitter().convert(text)) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        (value.startsWith('"') && value.endsWith('"') ||
            value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    env[line.substring(0, eq).trim()] = value;
  }
  return env;
}

/// Точка входа без `exit`, чтобы её можно было вызывать из тестов.
///
/// [backendFactory] по умолчанию — REST-клиент Supabase; тесты подставляют фейк.
Future<int> runImportDeck(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  DeckImportBackend Function(Uri baseUrl, String serviceKey)? backendFactory,
}) async {
  var envPath = defaultEnvPath;
  var schemaPath = defaultSchemaPath;
  var allowDraft = false;
  final files = <String>[];
  for (final arg in args) {
    if (arg == '--allow-draft') {
      allowDraft = true;
    } else if (arg.startsWith('--env=')) {
      envPath = arg.substring('--env='.length);
    } else if (arg.startsWith('--schema=')) {
      schemaPath = arg.substring('--schema='.length);
    } else if (arg == '-h' || arg == '--help') {
      out.writeln(_usage);
      return exitOk;
    } else if (arg.startsWith('-')) {
      err.writeln('Неизвестный флаг: $arg\n$_usage');
      return importUsage;
    } else {
      files.add(arg);
    }
  }
  if (files.length != 1) {
    err.writeln(_usage);
    return importUsage;
  }
  final file = files.single;

  // 1. Окружение. Проверка URL идёт до любых обращений к сети и до валидации.
  final Map<String, String> env;
  try {
    env = parseEnv(File(envPath).readAsStringSync());
  } on FileSystemException catch (e) {
    err.writeln('Не удалось прочитать env-файл $envPath: ${e.message}');
    return importUsage;
  }
  final url = env['SUPABASE_URL'] ?? '';
  final serviceKey = env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
  if (url.isEmpty || serviceKey.isEmpty) {
    err.writeln(
      '$envPath: нужны SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY '
      '(см. content/PIPELINE.md, шаг 7).',
    );
    return importUsage;
  }
  final baseUrl = Uri.tryParse(url);
  if (baseUrl == null || !baseUrl.hasAuthority || baseUrl.host.isEmpty) {
    err.writeln('$envPath: SUPABASE_URL не похож на URL: $url');
    return importUsage;
  }
  final local = isLocalSupabaseUrl(url);
  if (allowDraft && !local) {
    err.writeln(
      '--allow-draft разрешён только для локального Supabase '
      '(SUPABASE_URL на localhost, 127.0.0.1 или ::1), а в $envPath указан '
      '${baseUrl.host}. Колоду для настоящего проекта нужно вычитать '
      '(review.status = approved) и импортировать без этого флага.',
    );
    return importUsage;
  }
  if (!local && baseUrl.scheme != 'https') {
    err.writeln(
      'Ключ service role нельзя слать по ${baseUrl.scheme}: '
      'для не-локального проекта нужен https.',
    );
    return importUsage;
  }

  // 2. Валидация: схема, семантика, для релиза — все знания approved.
  final validateOut = StringBuffer();
  final validateErr = StringBuffer();
  final validateCode = runValidateDeck(
    [file, '--schema=$schemaPath', if (!allowDraft) '--release'],
    out: validateOut,
    err: validateErr,
  );
  out.write(validateOut);
  if (validateCode != exitOk) {
    err.write(validateErr);
    err.writeln(
      validateCode == exitInvalid
          ? '$file: колода не прошла проверку, импорт отменён.'
          : '$file: проверка колоды не выполнена, импорт отменён.',
    );
    return validateCode == exitInvalid ? importRejected : importUsage;
  }
  if (allowDraft) {
    out.writeln(
      'ВНИМАНИЕ: --allow-draft, колода не проверена на approved. '
      'Импорт в локальный Supabase (${baseUrl.host}).',
    );
  }

  final bytes = File(file).readAsBytesSync();
  final deck = Deck.fromJson(
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
  );
  final row = DeckRow(
    id: deck.id,
    title: deck.title,
    topic: deck.topic,
    lang: deck.lang,
    version: deck.version,
    itemCount: deck.items.length,
  );

  final backend = (backendFactory ?? SupabaseDeckBackend.new)(
    baseUrl,
    serviceKey,
  );
  try {
    // 3. Версия строго больше текущей.
    final current = await backend.currentVersion(deck.id);
    if (current != null && deck.version <= current) {
      err.writeln(
        '${deck.id}: версия ${deck.version} не больше текущей на сервере '
        '($current). Увеличьте "version" в $file и повторите импорт.',
      );
      return importRejected;
    }

    // 4. item_id глобально уникальны между колодами (ADR-21).
    final owners = await backend.itemOwners(excludeDeckId: deck.id);
    final clashes = [
      for (final item in deck.items)
        if (owners[item.id] case final other?) '${item.id} (колода $other)',
    ];
    if (clashes.isNotEmpty) {
      err.writeln(
        '${deck.id}: id знаний уже принадлежат другим колодам '
        '(ADR-21: item_id уникален между колодами):',
      );
      for (final c in clashes) {
        err.writeln('  - $c');
      }
      return importRejected;
    }

    // 5. Файл, затем строка.
    await backend.upload(row.storagePath, bytes);
    await backend.upsertRow(row);
  } on ImportBackendException catch (e) {
    err.writeln('Ошибка сервера: ${e.message}');
    return importBackendFailed;
  }

  out.writeln(
    '${deck.id}: импортирована версия ${deck.version} '
    '(знаний: ${row.itemCount}, файл decks/${row.storagePath}).',
  );
  return exitOk;
}
