import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/questions/find_error/find_error_question.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

import '../../../helpers/pump_app.dart';

FindErrorPayload _code() => const QuestionPayload.findError(
  mode: FindErrorMode.code,
  language: 'nginx',
  lines: [
    'server {',
    '    listen 443 ssl;',
    '    add_header Strict-Transport-Security "max-age=0; includeSubDomains" always; # очень длинная строка, которая не помещается в 360 dp и не должна ломать разметку',
    '}',
  ],
  errorLines: [3],
  lineExplanations: {3: 'max-age=0 отменяет HSTS'},
) as FindErrorPayload;

FindErrorPayload _text() => const QuestionPayload.findError(
  mode: FindErrorMode.text,
  lines: ['Первое утверждение', 'Второе утверждение', 'Третье'],
  errorLines: [1, 3],
  lineExplanations: {1: 'ошибка в первом', 3: 'ошибка в третьем'},
) as FindErrorPayload;

Future<List<QuestionResult>> _pump(
  WidgetTester tester,
  FindErrorPayload payload, {
  double textScale = 1,
}) async {
  final results = <QuestionResult>[];
  await tester.pumpApp(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: FindErrorQuestion(
            prompt: 'Где ошибка?',
            payload: payload,
            onAnswered: results.add,
          ),
        ),
      ),
    ),
  );
  return results;
}

Finder _line(int n) => find.byKey(Key('find-error-line-$n'));
String? _label(WidgetTester tester, int n) => tester
    .widget<Semantics>(
      find.descendant(of: _line(n), matching: find.byType(Semantics)).first,
    )
    .properties
    .label;

/// Строка кода может быть шире экрана: тапаем по её видимому началу.
Future<void> _tapLine(WidgetTester tester, int n) async {
  await tester.tapAt(tester.getTopLeft(_line(n)) + const Offset(40, 20));
  await tester.pump();
}

Finder get _check => find.byKey(const Key('find-error-check'));

void main() {
  group('режим code', () {
    testWidgets('рисует вопрос, номера и строки; «Проверить» выключена', (
      tester,
    ) async {
      await _pump(tester, _code());
      expect(find.text('Где ошибка?'), findsOneWidget);
      expect(find.text('server {'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.widget<FilledButton>(_check).onPressed, isNull);
    });

    testWidgets('моноширинный шрифт и горизонтальный скролл', (tester) async {
      await _pump(tester, _code());
      final text = tester.widget<Text>(find.text('server {'));
      expect(text.style?.fontFamily, 'monospace');
      expect(text.softWrap, isFalse);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('find-error-scroll')),
      );
      expect(scroll.scrollDirection, Axis.horizontal);
    });

    testWidgets('верная строка: autoCorrect и пояснение', (tester) async {
      final results = await _pump(tester, _code());
      await _tapLine(tester, 3);
      await tester.pump();
      await tester.tap(_check);
      await tester.pump();

      expect(results.single.outcome, AnswerOutcome.autoCorrect);
      expect(results.single.answer, {
        'lines': [3],
      });
      expect(find.text('Ошибка найдена'), findsOneWidget);
      expect(find.byKey(const Key('find-error-explanation-3')), findsOneWidget);
      expect(find.textContaining('max-age=0 отменяет HSTS'), findsOneWidget);
      expect(_check, findsNothing);
    });

    testWidgets(
      'не та строка: autoIncorrect, показаны выбранная и пропущенная',
      (tester) async {
        final results = await _pump(tester, _code());
        await _tapLine(tester, 2);
        await tester.tap(_check);
        await tester.pump();

        expect(results.single.outcome, AnswerOutcome.autoIncorrect);
        expect(find.text('Здесь ошибки нет'), findsOneWidget);
        expect(find.text('Пропущенная ошибка'), findsOneWidget);
        expect(
          find.byKey(const Key('find-error-explanation-3')),
          findsOneWidget,
        );
      },
    );

    testWidgets('длинная строка на 360 dp без переполнения', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester, _code());
      expect(tester.takeException(), isNull);
    });
  });

  group('режим text', () {
    testWidgets('выделение: повторный тап снимает, третье не добавляется', (
      tester,
    ) async {
      await _pump(tester, _text());
      await tester.tap(_line(1));
      await tester.tap(_line(2));
      await tester.tap(_line(3));
      await tester.pump();
      // Третья строка не выбрана: выбраны 1 и 2.
      expect(_label(tester, 3), 'Строка 3: Третье');
      expect(_label(tester, 1), 'Строка 1: Первое утверждение, выбрана');
      await tester.tap(_line(2));
      await tester.pump();
      await tester.tap(_line(3));
      await tester.pump();
      expect(_label(tester, 3), 'Строка 3: Третье, выбрана');
    });

    testWidgets('две верные строки: autoCorrect, два пояснения', (
      tester,
    ) async {
      final results = await _pump(tester, _text());
      await tester.tap(_line(1));
      await tester.tap(_line(3));
      await tester.pump();
      await tester.tap(_check);
      await tester.pump();

      expect(results.single.outcome, AnswerOutcome.autoCorrect);
      expect(results.single.answer, {
        'lines': [1, 3],
      });
      expect(find.byKey(const Key('find-error-explanation-1')), findsOneWidget);
      expect(find.byKey(const Key('find-error-explanation-3')), findsOneWidget);
    });

    testWidgets('после ответа выбор заблокирован', (tester) async {
      final results = await _pump(tester, _text());
      await tester.tap(_line(2));
      await tester.pump();
      await tester.tap(_check);
      await tester.pump();
      await tester.tap(_line(1));
      await tester.pump();
      expect(results, hasLength(1));
      expect(_label(tester, 1), startsWith('Строка 1: Первое утверждение'));
      expect(_label(tester, 1), isNot(contains('выбрана')));
    });

    testWidgets('масштаб текста 200% без переполнения', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester, _text(), textScale: 2);
      await tester.tap(_line(1));
      await tester.pump();
      await tester.ensureVisible(_check);
      await tester.tap(_check);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
