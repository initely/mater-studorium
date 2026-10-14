import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/review_report.dart';
import '../helpers/deck_fixtures.dart';

typedef _Run = ({int code, String out, String err});

_Run _run(List<String> args) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runReviewReport(args, out: out, err: err);
  return (code: code, out: out.toString(), err: err.toString());
}

Map<String, dynamic> _verifyFor(
  Map<String, dynamic> deck, {
  Set<String> needsFix = const {},
}) {
  final items = (deck['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  return {
    'deck_id': deck['id'],
    'deck_version': deck['version'],
    'items': [
      for (final item in items)
        {
          'item_id': item['id'],
          'verdict': needsFix.contains(item['id']) ? 'needs_fix' : 'ok',
          'unsupported_claims': needsFix.contains(item['id'])
              ? ['лишнее утверждение']
              : <String>[],
          'questions': [
            for (final q
                in (item['questions'] as List<dynamic>)
                    .cast<Map<String, dynamic>>())
              {
                'question_id': q['id'],
                'type': q['type'],
                'quote_supports_answer': 'yes',
                'second_correct_option': 'no',
                'unambiguous': 'yes',
                'issues': needsFix.contains(item['id'])
                    ? ['спорная опция b']
                    : <String>[],
              },
          ],
        },
    ],
  };
}

void main() {
  late Directory tmp;
  late Map<String, dynamic> deck;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('review_report_');
    deck = readJsonFile(goodDeckPath);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String report({Map<String, dynamic>? verify}) =>
      buildReviewReport(deck, deckPath: 'content/decks/x.json', verify: verify);

  test('по каждому знанию: чекбокс, факт, цитаты со ссылкой и лицензией', () {
    final text = report(verify: _verifyFor(deck));

    for (final id in ['t.a', 't.b', 't.c']) {
      expect(text, contains('- [ ] одобряю `$id`'));
    }
    final items = (deck['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (final item in items) {
      expect(text, contains('**Факт.** ${item['fact']}'));
    }
    final source = (deck['sources'] as List<dynamic>).first as Map;
    expect(text, contains('(${source['url']})'));
    expect(text, contains('${source['license']}'));
    expect(text, contains('> '));
  });

  test('все шесть типов вопросов выводятся с эталонным ответом', () {
    final text = report();

    for (final type in [
      'mcq',
      'open',
      'cloze',
      'order',
      'find_error',
      'flip',
    ]) {
      expect(text, contains('**$type**'));
    }
    expect(text, contains('✅'));
    expect(text, contains('Рубрика p1'));
    expect(text, contains('Пропуск {{x}}'));
    expect(text, contains('>>'));
    expect(text, contains('Оборот:'));
  });

  test(
    'вердикты: ok и needs_fix, замечания и команда одобрения только для ok',
    () {
      final text = report(verify: _verifyFor(deck, needsFix: {'t.b'}));

      expect(text, contains('✅ ok'));
      expect(text, contains('⚠️ needs_fix'));
      expect(text, contains('лишнее утверждение'));
      expect(text, contains('спорная опция b'));
      expect(text, contains('| ok | 2 |'));
      expect(text, contains('| needs_fix | 1 |'));
      final command = text.substring(
        text.indexOf('dart run tools/approve_items'),
      );
      expect(command, contains('t.a'));
      expect(command, contains('t.c'));
      expect(command.split('```').first, isNot(contains('t.b')));
    },
  );

  test('без отчёта проверки: пометка и команда-заготовка', () {
    final text = report();

    expect(text, contains('Независимая проверка к отчёту не приложена'));
    expect(text, contains('<id>... --by "<имя>"'));
  });

  test('заметки генерации и неавтоматическая цитата попадают в отчёт', () {
    final item = (deck['items'] as List<dynamic>).first as Map<String, dynamic>;
    (item['review'] as Map<String, dynamic>)['notes'] = 'сверить год';
    (item['refs'] as List<dynamic>).first['quote_unverifiable'] = true;

    final text = report();

    expect(text, contains('сверить год'));
    expect(text, contains('цитата не проверяется автоматически'));
  });

  group('несоответствие отчёта проверки колоде: FormatException', () {
    test('нет знания', () {
      final verify = _verifyFor(deck);
      (verify['items'] as List<dynamic>).removeLast();
      expect(() => report(verify: verify), throwsA(isA<FormatException>()));
    });

    test('нет вопроса', () {
      final verify = _verifyFor(deck);
      final first = (verify['items'] as List<dynamic>).first as Map;
      (first['questions'] as List<dynamic>).removeLast();
      expect(
        () => report(verify: verify),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('t.a.q2'),
          ),
        ),
      );
    });

    test('лишнее знание', () {
      final verify = _verifyFor(deck);
      (verify['items'] as List<dynamic>).add({
        'item_id': 'x.y',
        'verdict': 'ok',
        'questions': <Object>[],
      });
      expect(() => report(verify: verify), throwsA(isA<FormatException>()));
    });
  });

  group('командная строка', () {
    test('--out пишет файл и создаёт каталоги', () {
      final verify = File('${tmp.path}/v.json')
        ..writeAsStringSync(jsonEncode(_verifyFor(deck)));
      final out = '${tmp.path}/docs/reviews/R.md';

      final result = _run([
        goodDeckPath,
        '--verify=${verify.path}',
        '--out=$out',
      ]);

      expect(result.code, exitOk, reason: result.err);
      expect(File(out).readAsStringSync(), contains('одобряю `t.a`'));
    });

    test('без --out отчёт идёт в stdout', () {
      final result = _run([goodDeckPath]);
      expect(result.code, exitOk);
      expect(result.out, startsWith('# Вычитка колоды'));
    });

    test('рассогласованный отчёт проверки: код 1', () {
      final verify = _verifyFor(deck);
      (verify['items'] as List<dynamic>).removeLast();
      final file = File('${tmp.path}/v.json')
        ..writeAsStringSync(jsonEncode(verify));

      final result = _run([goodDeckPath, '--verify=${file.path}']);

      expect(result.code, exitMismatch);
      expect(result.err, contains('нет знания'));
    });

    test('ошибки аргументов и файлов: код 2', () {
      expect(_run([]).code, exitUsage);
      expect(_run([goodDeckPath, '--x']).code, exitUsage);
      expect(_run([goodDeckPath, 'second.json']).code, exitUsage);
      expect(_run(['${tmp.path}/нет.json']).code, exitUsage);
      File('${tmp.path}/bad.json').writeAsStringSync('[1]');
      expect(_run(['${tmp.path}/bad.json']).code, exitUsage);
    });
  });
}
