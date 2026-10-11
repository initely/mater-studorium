// Проверка колоды: JSON Schema + семантика (ТЗ M12, AC12.1).
//
//   dart run tools/validate_deck.dart <deck.json>... [--release]
//       [--schema=content/schema/deck.schema.json]
//
// Запускать из корня репозитория. Коды выхода: 0 — все колоды корректны,
// 1 — найдены ошибки, 2 — неверные аргументы или не читается схема/файл.
//
// Только чистый Dart: никаких импортов Flutter (ТЗ §6.1, CLAUDE.md).
import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/deck_validator.dart';

const defaultSchemaPath = 'content/schema/deck.schema.json';

const exitOk = 0;
const exitInvalid = 1;
const exitUsage = 2;

const _usage = '''
Использование: dart run tools/validate_deck.dart <deck.json>... [--release] [--schema=<path>]
  --release        требовать review.status = approved у всех знаний
  --schema=<path>  JSON Schema колоды (по умолчанию $defaultSchemaPath)''';

/// Схемы payload по значению `type` вопроса — для подробных ошибок вместо
/// общего «oneOf violated».
const _payloadDefs = {
  'mcq': 'McqPayload',
  'flip': 'FlipPayload',
  'open': 'OpenPayload',
  'cloze': 'ClozePayload',
  'order': 'OrderPayload',
  'find_error': 'FindErrorPayload',
};

void main(List<String> args) {
  exitCode = runValidateDeck(args, out: stdout, err: stderr);
}

/// Точка входа без `exit`, чтобы её можно было вызывать из тестов.
int runValidateDeck(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) {
  var release = false;
  var schemaPath = defaultSchemaPath;
  final files = <String>[];
  for (final arg in args) {
    if (arg == '--release') {
      release = true;
    } else if (arg.startsWith('--schema=')) {
      schemaPath = arg.substring('--schema='.length);
    } else if (arg == '-h' || arg == '--help') {
      out.writeln(_usage);
      return exitOk;
    } else if (arg.startsWith('-')) {
      err.writeln('Неизвестный флаг: $arg\n$_usage');
      return exitUsage;
    } else {
      files.add(arg);
    }
  }
  if (files.isEmpty) {
    err.writeln(_usage);
    return exitUsage;
  }

  final JsonSchema schema;
  try {
    schema = JsonSchema.create(
      File(schemaPath).readAsStringSync(),
      schemaVersion: SchemaVersion.draft2020_12,
    );
  } on Object catch (e) {
    err.writeln('Не удалось загрузить схему $schemaPath: $e');
    return exitUsage;
  }

  var code = exitOk;
  for (final file in files) {
    final fileCode = _validateFile(file, schema, release, out, err);
    if (fileCode > code) code = fileCode;
  }
  return code;
}

int _validateFile(
  String file,
  JsonSchema schema,
  bool release,
  StringSink out,
  StringSink err,
) {
  final String text;
  try {
    text = File(file).readAsStringSync();
  } on FileSystemException catch (e) {
    err.writeln('$file: не удалось прочитать файл: ${e.message}');
    return exitUsage;
  }

  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    err.writeln('$file: невалидный JSON: ${e.message} (позиция ${e.offset})');
    return exitInvalid;
  }

  final schemaIssues = _schemaIssues(schema, json);
  if (schemaIssues.isNotEmpty) {
    _printIssues(file, 'схема', schemaIssues, err);
    err.writeln(
      '$file: ОШИБКИ (${schemaIssues.length}); семантика не проверялась, '
      'сначала исправьте схему',
    );
    return exitInvalid;
  }

  final Deck deck;
  try {
    deck = Deck.fromJson(json! as Map<String, dynamic>);
  } on Object catch (e) {
    // Схема пройдена, но модель не собралась: схема и модели разошлись.
    err.writeln('$file: колода не разбирается в Dart-модели: $e');
    return exitInvalid;
  }

  final issues = validateDeck(deck, release: release);
  if (issues.isNotEmpty) {
    _printIssues(file, 'семантика', issues, err);
    err.writeln('$file: ОШИБКИ (${issues.length})');
    return exitInvalid;
  }

  final questions = deck.items.fold(0, (n, i) => n + i.questions.length);
  out.writeln(
    '$file: OK${release ? ' (release)' : ''} — '
    'знаний: ${deck.items.length}, вопросов: $questions',
  );
  return exitOk;
}

void _printIssues(
  String file,
  String kind,
  List<DeckIssue> issues,
  StringSink err,
) {
  for (final issue in issues) {
    err.writeln(
      '$file: [$kind] ${issue.path.isEmpty ? '/' : issue.path}: '
      '${issue.message}',
    );
  }
}

List<DeckIssue> _schemaIssues(JsonSchema schema, Object? json) {
  final issues = <DeckIssue>[];
  final seenMissing = <String>{};
  void add(String path, String message) {
    // json_schema дублирует «required prop missing» (с дампом объекта) на
    // уровне объекта и свойства — оставляем первое.
    if (message.contains('required prop missing') &&
        !seenMissing.add(message)) {
      return;
    }
    issues.add(DeckIssue(path, _shorten(message)));
  }

  for (final error in schema.validate(json).errors) {
    final refined = error.schemaPath.endsWith('/oneOf')
        ? _payloadErrors(schema, json, error.instancePath)
        : null;
    if (refined == null) {
      add(error.instancePath, _describe(error));
    } else {
      for (final (path, message) in refined) {
        add(path, message);
      }
    }
  }
  return issues;
}

/// Для вопроса, не прошедшего `oneOf`, проверяет payload схемой его `type`
/// и возвращает конкретные ошибки с путями. `null` — уточнить нечего.
List<(String, String)>? _payloadErrors(
  JsonSchema schema,
  Object? json,
  String questionPath,
) {
  final question = _resolvePointer(json, questionPath);
  if (question is! Map) return null;
  final def = _payloadDefs[question['type']];
  // Неизвестный type уже сообщён ошибкой enum; «oneOf violated» — шум.
  if (def == null) return const [];
  final payloadSchema = schema.resolvePath(Uri.parse('#/\$defs/$def'));
  final errors = payloadSchema.validate(question['payload']).errors;
  if (errors.isEmpty) return null;
  return [
    for (final e in errors)
      (
        '$questionPath/payload${e.instancePath}',
        '(${question['type']}) ${_describe(e)}',
      ),
  ];
}

/// «contains violated» без пути к правилу непонятно — добавляем его.
String _describe(ValidationError e) => e.message.startsWith('contains violated')
    ? 'нет ни одного элемента, подходящего под ${e.schemaPath}/contains'
    : e.message;

/// json_schema вставляет в сообщения весь объект; обрезаем до читаемого.
String _shorten(String message) {
  const max = 160;
  final from = message.indexOf(' from {');
  final short = from == -1 ? message : message.substring(0, from);
  return short.length <= max ? short : '${short.substring(0, max)}…';
}

Object? _resolvePointer(Object? json, String pointer) {
  var node = json;
  for (final raw in pointer.split('/').skip(1)) {
    final key = raw.replaceAll('~1', '/').replaceAll('~0', '~');
    final index = int.tryParse(key);
    node = switch (node) {
      final Map<dynamic, dynamic> map => map[key],
      final List<dynamic> list
          when index != null && index >= 0 && index < list.length =>
        list[index],
      _ => null,
    };
  }
  return node;
}
