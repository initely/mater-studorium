import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/approve_items.dart';
import '../../tools/validate_deck.dart' as validate;
import '../helpers/deck_fixtures.dart';

typedef _Run = ({int code, String out, String err});

_Run _run(List<String> args) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runApproveItems(args, out: out, err: err);
  return (code: code, out: out.toString(), err: err.toString());
}

Map<String, dynamic> _review(Map<String, dynamic> deck, String id) {
  final items = deck['items'] as List<dynamic>;
  final item = items.cast<Map<String, dynamic>>().firstWhere(
    (i) => i['id'] == id,
  );
  return item['review'] as Map<String, dynamic>;
}

void main() {
  late Directory tmp;
  late String path;

  /// Колода из `good.json` (t.a, t.b, t.c), у которой все знания draft.
  void writeDraftDeck([void Function(Map<String, dynamic>)? mutate]) {
    final deck = readJsonFile(goodDeckPath);
    for (final item in deck['items'] as List<dynamic>) {
      (item as Map<String, dynamic>)['review'] = {
        'status': 'draft',
        'notes': 'проверить цитату',
      };
    }
    mutate?.call(deck);
    File(path).writeAsStringSync(jsonEncode(deck));
  }

  Map<String, dynamic> read() =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('approve_items_');
    path = '${tmp.path}/deck.json';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('успешное одобрение', () {
    test('одобряет только перечисленные, остальное не трогает', () {
      writeDraftDeck();
      final before = read();

      final result = _run([path, 't.a', 't.c', '--by', 'Анна']);

      expect(result.code, exitOk, reason: result.err);
      expect(result.out, contains('approved проставлено: 2 из 2'));
      final after = read();
      expect(_review(after, 't.a'), {
        'status': 'approved',
        'by': 'Анна',
        'notes': 'проверить цитату',
      });
      expect(_review(after, 't.c')['status'], 'approved');
      expect(_review(after, 't.b'), {
        'status': 'draft',
        'notes': 'проверить цитату',
      });
      // Кроме review.* колода не изменилась.
      for (final deck in [before, after]) {
        for (final item in deck['items'] as List<dynamic>) {
          (item as Map<String, dynamic>).remove('review');
        }
      }
      expect(after, before);
    });

    test('форма --by=имя и пробелы вокруг имени', () {
      writeDraftDeck();

      final result = _run([path, 't.b', '--by=  Борис  ']);

      expect(result.code, exitOk, reason: result.err);
      expect(_review(read(), 't.b')['by'], 'Борис');
    });

    test('флаг можно ставить до файла и ids', () {
      writeDraftDeck();

      final result = _run(['--by', 'Анна', path, 't.a']);

      expect(result.code, exitOk, reason: result.err);
      expect(_review(read(), 't.a')['status'], 'approved');
    });

    test('повтор id в аргументах считается один раз', () {
      writeDraftDeck();

      final result = _run([path, 't.a', 't.a', '--by', 'Анна']);

      expect(result.code, exitOk);
      expect(result.out, contains('approved проставлено: 1 из 1'));
    });

    test('знание без notes остаётся без notes', () {
      writeDraftDeck(
        (d) => nodeAt(d, '/items/0')['review'] = {'status': 'draft'},
      );

      _run([path, 't.a', '--by', 'Анна']);

      expect(_review(read(), 't.a'), {'status': 'approved', 'by': 'Анна'});
    });

    test('needs_fix одобряется по явному указанию, с пометкой в выводе', () {
      writeDraftDeck(
        (d) => nodeAt(d, '/items/1')['review'] = {
          'status': 'needs_fix',
          'notes': 'вторая верная опция',
        },
      );

      final result = _run([path, 't.b', '--by', 'Анна']);

      expect(result.code, exitOk, reason: result.err);
      expect(result.out, contains('t.b: был needs_fix'));
      expect(_review(read(), 't.b')['status'], 'approved');
      expect(_review(read(), 't.b')['notes'], 'вторая верная опция');
    });

    test('уже approved не перезаписывается и файл не трогается', () {
      writeDraftDeck();
      expect(_run([path, 't.a', '--by', 'Анна']).code, exitOk);
      final bytes = File(path).readAsBytesSync();

      final result = _run([path, 't.a', '--by', 'Борис']);

      expect(result.code, exitOk);
      expect(result.out, contains('t.a: уже approved (by Анна), пропущено'));
      expect(result.out, contains('approved проставлено: 0 из 1'));
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('после одобрения всех колода проходит validate_deck --release', () {
      writeDraftDeck();
      final out = StringBuffer();
      final err = StringBuffer();
      expect(
        validate.runValidateDeck([path, '--release'], out: out, err: err),
        validate.exitInvalid,
      );

      final result = _run([path, 't.a', 't.b', 't.c', '--by', 'Анна']);

      expect(result.code, exitOk, reason: result.err);
      final err2 = StringBuffer();
      expect(
        validate.runValidateDeck(
          [path, '--release'],
          out: StringBuffer(),
          err: err2,
        ),
        validate.exitOk,
        reason: err2.toString(),
      );
    });

    test('временный файл не остаётся', () {
      writeDraftDeck();

      _run([path, 't.a', '--by', 'Анна']);

      expect(File('$path.approve.tmp').existsSync(), isFalse);
      expect(tmp.listSync().map((e) => e.path), [path]);
    });
  });

  group('отказы: колода не меняется', () {
    test('неизвестный id: код 1, даже если другие id верны', () {
      writeDraftDeck();
      final bytes = File(path).readAsBytesSync();

      final result = _run([path, 't.a', 'нет.такого', '--by', 'Анна']);

      expect(result.code, exitRejected);
      expect(result.err, contains('знания с id "нет.такого" нет'));
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('результат не проходит валидацию: код 1, файл как был', () {
      // В колоде заранее сломана другая часть: дубль id знания.
      writeDraftDeck(
        (d) => nodeAt(d, '/items/2')['id'] = nodeAt(d, '/items/1')['id'],
      );
      final bytes = File(path).readAsBytesSync();

      final result = _run([path, 't.a', '--by', 'Анна']);

      expect(result.code, exitRejected);
      expect(result.err, contains('не проходит validate_deck'));
      expect(result.err, contains(path));
      expect(result.err, isNot(contains('.approve.tmp')));
      expect(File(path).readAsBytesSync(), bytes);
      expect(File('$path.approve.tmp').existsSync(), isFalse);
    });
  });

  group('аргументы: код 2', () {
    test('без --by', () {
      writeDraftDeck();
      final result = _run([path, 't.a']);
      expect(result.code, exitUsage);
      expect(result.err, contains('--by'));
    });

    test('пустое и пробельное имя', () {
      writeDraftDeck();
      expect(_run([path, 't.a', '--by', '']).code, exitUsage);
      expect(_run([path, 't.a', '--by=   ']).code, exitUsage);
    });

    test('--by последним без значения', () {
      writeDraftDeck();
      expect(_run([path, 't.a', '--by']).code, exitUsage);
    });

    test('не указан ни один id', () {
      writeDraftDeck();
      expect(_run([path, '--by', 'Анна']).code, exitUsage);
    });

    test('неизвестный флаг', () {
      writeDraftDeck();
      final result = _run([path, 't.a', '--by', 'Анна', '--all']);
      expect(result.code, exitUsage);
      expect(result.err, contains('Неизвестный флаг: --all'));
    });

    test('файла нет', () {
      final result = _run(['${tmp.path}/нет.json', 't.a', '--by', 'Анна']);
      expect(result.code, exitUsage);
      expect(result.err, contains('не удалось прочитать файл'));
    });

    test('невалидный JSON и не колода', () {
      File(path).writeAsStringSync('{ не json');
      expect(_run([path, 't.a', '--by', 'Анна']).code, exitUsage);

      File(path).writeAsStringSync('[1, 2]');
      expect(_run([path, 't.a', '--by', 'Анна']).code, exitUsage);
    });

    test('--help выводит справку с кодом 0', () {
      final result = _run(['--help']);
      expect(result.code, exitOk);
      expect(result.out, contains('Использование'));
    });
  });

  test('на настоящей колоде меняется только review выбранного знания', () {
    const deckPath = 'content/decks/infosec-basics.json';
    final original = readJsonFile(deckPath);
    final firstId = (original['items'] as List<dynamic>).first['id'] as String;
    File(path).writeAsStringSync(File(deckPath).readAsStringSync());

    final result = _run([path, firstId, '--by', 'Тест']);

    expect(result.code, exitOk, reason: result.err);
    final after = read();
    expect(_review(after, firstId)['status'], 'approved');
    expect(_review(after, firstId)['by'], 'Тест');
    _review(after, firstId)
      ..clear()
      ..addAll(_review(original, firstId));
    expect(after, original);
  });

  test('каноническая запись: повторная запись не меняет файл', () {
    // Колода из репозитория записана в том же виде, который выдаёт
    // инструмент, поэтому одобрение даёт минимальный diff.
    const deckPath = 'content/decks/infosec-basics.json';
    final text = File(deckPath).readAsStringSync();
    final canonical =
        '${const JsonEncoder.withIndent('  ').convert(jsonDecode(text))}\n';
    expect(text, canonical);
  });
}
