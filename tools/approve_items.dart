// Проставляет review.status = approved указанным знаниям колоды (шаг 5
// конвейера, content/PIPELINE.md). Запускает человек после вычитки: модель
// approved не ставит (ТЗ §5.3 п. 2).
//
//   dart run tools/approve_items.dart <deck.json> <item-id>... --by <имя>
//
// Меняются только перечисленные знания: status и by; notes и остальное не
// трогаются. Колода перезаписывается в каноническом виде (отступ 2 пробела).
// Файл записывается, только если все id найдены, а результат проходит
// validate_deck; иначе колода остаётся как была.
//
// Коды выхода: 0 — готово; 1 — отказ (неизвестный id, результат не проходит
// валидацию); 2 — неверные аргументы или файл не читается.
//
// Только чистый Dart: никаких импортов Flutter (ТЗ §6.1, CLAUDE.md).
import 'dart:convert';
import 'dart:io';

import 'validate_deck.dart';

const exitOk = 0;
const exitRejected = 1;
const exitUsage = 2;

const _usage = '''
Использование: dart run tools/approve_items.dart <deck.json> <item-id>... --by <имя>
  <item-id>  id знаний, которым ставится approved (только вычитанные человеком)
  --by       имя вычитавшего; пишется в review.by (также --by=<имя>)''';

void main(List<String> args) {
  exitCode = runApproveItems(args, out: stdout, err: stderr);
}

/// Точка входа без `exit`, чтобы её можно было вызывать из тестов.
int runApproveItems(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) {
  String? by;
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-h' || arg == '--help') {
      out.writeln(_usage);
      return exitOk;
    } else if (arg == '--by') {
      if (i + 1 >= args.length) {
        err.writeln('Флагу --by нужно имя.\n$_usage');
        return exitUsage;
      }
      by = args[++i];
    } else if (arg.startsWith('--by=')) {
      by = arg.substring('--by='.length);
    } else if (arg.startsWith('-')) {
      err.writeln('Неизвестный флаг: $arg\n$_usage');
      return exitUsage;
    } else {
      positional.add(arg);
    }
  }

  final name = by?.trim() ?? '';
  if (name.isEmpty) {
    err.writeln('Нужно имя вычитавшего: --by <имя>.\n$_usage');
    return exitUsage;
  }
  if (positional.length < 2) {
    err.writeln('Нужны файл колоды и хотя бы один id знания.\n$_usage');
    return exitUsage;
  }
  final file = positional.first;
  final ids = positional.skip(1).toSet();

  final Map<String, dynamic> deck;
  try {
    final decoded = jsonDecode(File(file).readAsStringSync());
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      err.writeln('$file: не колода (нет списка items).');
      return exitUsage;
    }
    deck = decoded;
  } on FileSystemException catch (e) {
    err.writeln('$file: не удалось прочитать файл: ${e.message}');
    return exitUsage;
  } on FormatException catch (e) {
    err.writeln('$file: невалидный JSON: ${e.message} (позиция ${e.offset})');
    return exitUsage;
  }

  final byId = <String, Map<String, dynamic>>{};
  for (final item in deck['items'] as List<dynamic>) {
    if (item is Map<String, dynamic> && item['id'] is String) {
      byId[item['id'] as String] = item;
    }
  }
  final unknown = ids.where((id) => !byId.containsKey(id)).toList();
  if (unknown.isNotEmpty) {
    for (final id in unknown) {
      err.writeln('$file: знания с id "$id" нет; ничего не изменено.');
    }
    return exitRejected;
  }

  final approved = <String>[];
  for (final id in ids) {
    final item = byId[id]!;
    final review = (item['review'] as Map<String, dynamic>?) ?? const {};
    if (review['status'] == 'approved') {
      out.writeln('$id: уже approved (by ${review['by']}), пропущено');
      continue;
    }
    if (review['status'] == 'needs_fix') {
      out.writeln('$id: был needs_fix, ставлю approved по вашему указанию');
    }
    item['review'] = {
      'status': 'approved',
      'by': name,
      if (review['notes'] != null) 'notes': review['notes'],
    };
    approved.add(id);
  }

  if (approved.isNotEmpty) {
    final code = _writeValidated(file, deck, out: out, err: err);
    if (code != exitOk) return code;
  }
  out.writeln(
    '$file: approved проставлено: ${approved.length} из '
    '${ids.length}',
  );
  return exitOk;
}

/// Пишет колоду во временный файл рядом, проверяет `validate_deck` и только
/// тогда подменяет исходный файл.
int _writeValidated(
  String file,
  Map<String, dynamic> deck, {
  required StringSink out,
  required StringSink err,
}) {
  final tmp = File('$file.approve.tmp');
  try {
    tmp.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(deck)}\n',
    );
    final problems = StringBuffer();
    final code = runValidateDeck(
      [tmp.path],
      out: StringBuffer(),
      err: problems,
    );
    if (code != exitOk) {
      err
        ..writeln(
          'Результат не проходит validate_deck; '
          '$file не изменён:',
        )
        ..write(problems.toString().replaceAll(tmp.path, file));
      return exitRejected;
    }
    tmp.renameSync(file);
    return exitOk;
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}
