import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';

import '../../tools/validate_deck.dart';
import '../helpers/deck_fixtures.dart';

typedef _Run = ({int code, String out, String err});

_Run _run(List<String> args) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runValidateDeck(args, out: out, err: err);
  return (code: code, out: out.toString(), err: err.toString());
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('validate_deck_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Пишет «плохую» фикстуру: хорошая колода + одна поломка.
  String badFixture(String name, void Function(Map<String, dynamic>) mutate) {
    final json = readJsonFile(goodDeckPath);
    mutate(json);
    final file = File('${tmp.path}/$name.json')
      ..writeAsStringSync(jsonEncode(json));
    return file.path;
  }

  group('корректные колоды', () {
    test('good.json проходит, в том числе с --release', () {
      final result = _run([goodDeckPath, '--release']);
      expect(result.code, exitOk, reason: result.err);
      expect(result.out, contains('OK (release)'));
      expect(result.out, contains('знаний: 3, вопросов: 6'));
    });

    test('все content/decks/*.json проходят схему и семантику', () {
      final decks = Directory('content/decks')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .map((f) => f.path)
          .toList();
      expect(decks, contains(endsWith('sample.json')));

      final result = _run(decks);
      expect(result.code, exitOk, reason: result.err);
    });
  });

  group('плохие фикстуры: код 1 и путь до проблемы', () {
    final cases = <(String, void Function(Map<String, dynamic>), String)>[
      (
        'schema_source_without_license',
        (d) => nodeAt(d, '/sources/0').remove('license'),
        '[схема] /sources/0: required prop missing: license',
      ),
      (
        'schema_payload_of_other_type',
        (d) => nodeAt(d, '/items/0/questions/0')['payload'] = {'back': 'B'},
        '[схема] /items/0/questions/0/payload: (mcq) required prop missing',
      ),
      (
        'schema_unknown_type',
        (d) => nodeAt(d, '/items/0/questions/0')['type'] = 'essay',
        '[схема] /items/0/questions/0/type: enum violated',
      ),
      (
        'duplicate_question_id',
        (d) => nodeAt(d, '/items/0/questions/1')['id'] = 't.a.q1',
        '[семантика] /items/0/questions/1/id: id "t.a.q1" повторяется',
      ),
      (
        'unknown_source_id',
        (d) => nodeAt(d, '/items/2/refs/1')['source_id'] = 'src-x',
        '[семантика] /items/2/refs/1/source_id: источник "src-x"',
      ),
      (
        'mcq_correct_not_in_options',
        (d) => nodeAt(d, '/items/0/questions/0/payload')['correct'] = ['d'],
        '[семантика] /items/0/questions/0/payload/correct/0: вариант "d"',
      ),
      (
        'mcq_single_option',
        (d) => (nodeAt(d, '/items/0/questions/0/payload')['options'] as List)
            .removeRange(1, 3),
        '[схема] /items/0/questions/0/payload/options: (mcq) minItems',
      ),
      (
        'order_two_steps',
        (d) => (nodeAt(d, '/items/1/questions/1/payload')['steps'] as List)
            .removeLast(),
        '[схема] /items/1/questions/1/payload/steps: (order) minItems',
      ),
      (
        'find_error_line_out_of_range',
        (d) => nodeAt(d, '/items/2/questions/1/payload')['error_lines'] = [7],
        '[семантика] /items/2/questions/1/payload/error_lines/0: строка 7 '
            'вне диапазона 1–4',
      ),
      (
        'cloze_placeholder_mismatch',
        (d) => nodeAt(d, '/items/1/questions/0')['prompt'] = '{{x}} и {{y}}.',
        '[семантика] /items/1/questions/0/prompt: для плейсхолдера {{y}}',
      ),
      (
        'open_without_required_point',
        (d) => nodeAt(d, '/items/0/questions/1/payload/rubric/0')['required'] =
            false,
        '[схема] /items/0/questions/1/payload/rubric: (open) нет ни одного '
            'элемента',
      ),
      (
        'open_six_rubric_points',
        (d) => (nodeAt(d, '/items/0/questions/1/payload')['rubric'] as List)
            .addAll([
              for (var i = 3; i <= 6; i++)
                {'id': 'p$i', 'text': 'П', 'weight': 1, 'required': false},
            ]),
        '[схема] /items/0/questions/1/payload/rubric: (open) maxItems',
      ),
    ];

    for (final (name, mutate, expected) in cases) {
      test(name, () {
        final result = _run([badFixture(name, mutate)]);
        expect(result.code, exitInvalid);
        expect(result.err, contains(expected));
        expect(result.out, isEmpty);
      });
    }

    test('--release: знание не approved', () {
      final path = badFixture(
        'not_approved',
        (d) => nodeAt(d, '/items/2/review')['status'] = 'draft',
      );
      expect(_run([path]).code, exitOk);

      final result = _run([path, '--release']);
      expect(result.code, exitInvalid);
      expect(
        result.err,
        contains(
          '[семантика] /items/2/review/status: для релиза нужен '
          '"approved", сейчас "draft"',
        ),
      );
    });

    test('approved без by — нарушение схемы', () {
      final path = badFixture(
        'approved_without_by',
        (d) => nodeAt(d, '/items/0/review').remove('by'),
      );
      final result = _run([path]);
      expect(result.code, exitInvalid);
      expect(result.err, contains('[схема] /items/0/review'));
    });

    test('невалидный JSON', () {
      final file = File('${tmp.path}/broken.json')..writeAsStringSync('{"id":');
      final result = _run([file.path]);
      expect(result.code, exitInvalid);
      expect(result.err, contains('невалидный JSON'));
    });

    test('одна плохая колода среди нескольких даёт код 1', () {
      final bad = badFixture(
        'bad',
        (d) => nodeAt(d, '/sources/0').remove('license'),
      );
      final result = _run([goodDeckPath, bad]);
      expect(result.code, exitInvalid);
      expect(result.out, contains('good.json: OK'));
    });
  });

  group('аргументы: код 2', () {
    test('без файлов', () {
      final result = _run([]);
      expect(result.code, exitUsage);
      expect(result.err, contains('Использование'));
    });

    test('неизвестный флаг', () {
      expect(_run([goodDeckPath, '--fast']).code, exitUsage);
    });

    test('файл не найден', () {
      final result = _run(['${tmp.path}/missing.json']);
      expect(result.code, exitUsage);
      expect(result.err, contains('не удалось прочитать'));
    });

    test('схема не найдена', () {
      final result = _run([goodDeckPath, '--schema=${tmp.path}/none.json']);
      expect(result.code, exitUsage);
      expect(result.err, contains('Не удалось загрузить схему'));
    });

    test('--help', () {
      final result = _run(['--help']);
      expect(result.code, exitOk);
      expect(result.out, contains('--release'));
    });
  });

  test('enum type в схеме совпадает с QuestionType', () {
    final schema = readJsonFile(deckSchemaPath);
    final enumValues = nodeAt(
      schema,
      r'/$defs/Question/properties/type',
    )['enum'];
    // Значения в JSON — snake_case имён QuestionType.
    final modelValues = QuestionType.values.map(
      (t) => t.name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m[0]!.toLowerCase()}',
      ),
    );
    expect(enumValues, unorderedEquals(modelValues));
  });
}
