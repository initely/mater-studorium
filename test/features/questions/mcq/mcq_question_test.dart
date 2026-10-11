import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/questions/mcq/mcq_question.dart';
import 'package:mater_studorium/features/questions/mcq/option_order.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

import '../../../helpers/pump_app.dart';

const _options = [
  McqOption(id: 'a', text: 'Первый вариант'),
  McqOption(id: 'b', text: 'Второй вариант'),
  McqOption(id: 'c', text: 'Третий вариант'),
  McqOption(id: 'd', text: 'Четвёртый вариант'),
];

McqPayload _single() => const QuestionPayload.mcq(
  options: _options,
  correct: ['b'],
  multiple: false,
) as McqPayload;

McqPayload _multi() => const QuestionPayload.mcq(
  options: _options,
  correct: ['a', 'c'],
  multiple: true,
) as McqPayload;

Future<List<QuestionResult>> _pump(
  WidgetTester tester,
  McqPayload payload, {
  int seed = 1,
}) async {
  final results = <QuestionResult>[];
  await tester.pumpApp(
    Scaffold(
      body: SingleChildScrollView(
        child: McqQuestion(
          prompt: 'Что верно?',
          payload: payload,
          shuffleSeed: seed,
          onAnswered: results.add,
        ),
      ),
    ),
  );
  return results;
}

Finder _opt(String id) => find.byKey(Key('mcq-option-$id'));

/// Порядок вариантов на экране (сверху вниз).
List<String> _onScreenOrder(WidgetTester tester) {
  final tops = {
    for (final o in _options) o.id: tester.getTopLeft(_opt(o.id)).dy,
  };
  return (tops.keys.toList()..sort((a, b) => tops[a]!.compareTo(tops[b]!)));
}

void main() {
  group('один верный ответ', () {
    testWidgets('рисует вопрос и все варианты', (tester) async {
      await _pump(tester, _single());
      expect(find.text('Что верно?'), findsOneWidget);
      for (final o in _options) {
        expect(find.text(o.text), findsOneWidget);
      }
      expect(find.byKey(const Key('mcq-answer')), findsNothing);
      expect(find.byKey(const Key('mcq-hint-multiple')), findsNothing);
    });

    testWidgets(
      'тап по верному сразу отвечает: autoCorrect и подпись «Верно»',
      (tester) async {
        final results = await _pump(tester, _single());
        await tester.tap(_opt('b'));
        await tester.pump();

        expect(results, hasLength(1));
        expect(results.single.outcome, AnswerOutcome.autoCorrect);
        expect(
          find.descendant(of: _opt('b'), matching: find.text('Верно')),
          findsOneWidget,
        );
        expect(find.text('Неверно'), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    testWidgets(
      'тап по неверному: autoIncorrect, верный подсвечен как пропущенный',
      (tester) async {
        final results = await _pump(tester, _single());
        await tester.tap(_opt('c'));
        await tester.pump();

        expect(results.single.outcome, AnswerOutcome.autoIncorrect);
        expect(
          find.descendant(of: _opt('c'), matching: find.text('Неверно')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _opt('b'), matching: find.text('Верный ответ')),
          findsOneWidget,
        );
        // Не только цвет: неверный и верный отличаются иконками.
        expect(find.byIcon(Icons.cancel), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      },
    );

    testWidgets(
      'после ответа варианты заблокированы: второй тап не отвечает снова',
      (tester) async {
        final results = await _pump(tester, _single());
        await tester.tap(_opt('c'));
        await tester.pump();
        await tester.tap(_opt('b'));
        await tester.pump();
        expect(results, hasLength(1));
        expect(results.single.outcome, AnswerOutcome.autoIncorrect);
      },
    );
  });

  group('несколько верных ответов', () {
    testWidgets('показывает подсказку и кнопку «Ответить» (пока неактивную)', (
      tester,
    ) async {
      await _pump(tester, _multi());
      expect(find.text('Выберите все верные варианты'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('mcq-answer')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('тап только отмечает; ответ уходит по «Ответить»', (
      tester,
    ) async {
      final results = await _pump(tester, _multi());
      await tester.tap(_opt('a'));
      await tester.pump();
      await tester.tap(_opt('c'));
      await tester.pump();
      expect(results, isEmpty);
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));

      // Повторный тап снимает отметку.
      await tester.tap(_opt('c'));
      await tester.pump();
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      await tester.tap(_opt('c'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('mcq-answer')));
      await tester.pump();

      expect(results, hasLength(1));
      expect(results.single.outcome, AnswerOutcome.autoCorrect);
      expect(find.byKey(const Key('mcq-answer')), findsNothing);
      expect(find.text('Верно'), findsNWidgets(2));
    });

    testWidgets('верный плюс лишний: autoIncorrect, подписи у каждого', (
      tester,
    ) async {
      final results = await _pump(tester, _multi());
      for (final id in ['a', 'c', 'd']) {
        await tester.tap(_opt(id));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('mcq-answer')));
      await tester.pump();

      expect(results.single.outcome, AnswerOutcome.autoIncorrect);
      expect(
        find.descendant(of: _opt('d'), matching: find.text('Неверно')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _opt('a'), matching: find.text('Верно')),
        findsOneWidget,
      );
    });

    testWidgets('выбрана часть верных: пропущенный подписан «Верный ответ»', (
      tester,
    ) async {
      final results = await _pump(tester, _multi());
      await tester.tap(_opt('a'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mcq-answer')));
      await tester.pump();

      expect(results.single.outcome, AnswerOutcome.autoIncorrect);
      expect(
        find.descendant(of: _opt('c'), matching: find.text('Верный ответ')),
        findsOneWidget,
      );
    });

    testWidgets('отметки и порядок вариантов переживают поворот экрана', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      await _pump(tester, _multi());
      final before = _onScreenOrder(tester);

      await tester.tap(_opt('a'));
      await tester.pump();
      tester.view.physicalSize = const Size(800, 400);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(_onScreenOrder(tester), before);
    });
  });

  group('порядок вариантов', () {
    testWidgets(
      'на экране совпадает с shuffledOptions и не зависит от перестроения',
      (tester) async {
        await _pump(tester, _single(), seed: 7);
        final expected = shuffledOptions(_options, 7).map((o) => o.id).toList();
        expect(_onScreenOrder(tester), expected);

        await tester.pump();
        expect(_onScreenOrder(tester), expected);
      },
    );

    test(
      'одно зерно — один порядок, это перестановка, исходный список цел',
      () {
        final first = shuffledOptions(_options, 42);
        final second = shuffledOptions(_options, 42);
        expect(first.map((o) => o.id), second.map((o) => o.id));
        expect(
          first.map((o) => o.id).toSet(),
          _options.map((o) => o.id).toSet(),
        );
        expect(_options.map((o) => o.id), ['a', 'b', 'c', 'd']);
      },
    );

    test('разные зёрна дают разный порядок', () {
      final orders = {
        for (var seed = 0; seed < 20; seed++)
          shuffledOptions(_options, seed).map((o) => o.id).join(),
      };
      expect(orders.length, greaterThan(1));
    });
  });

  group('доступность', () {
    testWidgets('цели нажатия не меньше 48 dp, у каждой есть подпись', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _multi());
      await tester.tap(_opt('a'));
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final o in _options) {
        expect(tester.getSize(_opt(o.id)).height, greaterThanOrEqualTo(48));
      }
      handle.dispose();
    });

    testWidgets(
      'семантика: чекбоксы с состоянием, после ответа — вердикт в подписи',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _multi());
        await tester.tap(_opt('a'));
        await tester.pump();

        final selected = tester.getSemantics(_opt('a'));
        expect(selected.label, 'Первый вариант');
        expect(selected.flagsCollection.isChecked, CheckedState.isTrue);
        expect(
          tester.getSemantics(_opt('b')).flagsCollection.isChecked,
          CheckedState.isFalse,
        );

        await tester.tap(find.byKey(const Key('mcq-answer')));
        await tester.pump();
        expect(tester.getSemantics(_opt('a')).label, 'Первый вариант, Верно');
        expect(
          tester.getSemantics(_opt('c')).label,
          'Третий вариант, Верный ответ',
        );
        expect(tester.getSemantics(_opt('d')).label, 'Четвёртый вариант');
        handle.dispose();
      },
    );

    testWidgets('один ответ: варианты — взаимоисключающая группа кнопок', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _single());
      final data = tester.getSemantics(_opt('a'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      handle.dispose();
    });
  });
}
