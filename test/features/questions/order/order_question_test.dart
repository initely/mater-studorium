import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/grading/domain/order_grader.dart';
import 'package:mater_studorium/features/questions/order/order_question.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

import '../../../helpers/pump_app.dart';

final _steps = [
  for (final id in ['s1', 's2', 's3', 's4']) OrderStep(id: id, text: 'Шаг $id'),
];
final _payload = QuestionPayload.order(steps: _steps) as OrderPayload;

Future<List<QuestionResult>> _pump(
  WidgetTester tester, {
  int seed = 1,
  double textScale = 1,
}) async {
  final results = <QuestionResult>[];
  await tester.pumpApp(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: OrderQuestion(
            prompt: 'Расставьте шаги',
            payload: _payload,
            shuffleSeed: seed,
            onAnswered: results.add,
          ),
        ),
      ),
    ),
  );
  return results;
}

List<String> _onScreen(WidgetTester tester) {
  final ids = ['s1', 's2', 's3', 's4'];
  final tops = {
    for (final id in ids) id: tester.getTopLeft(find.text('Шаг $id')).dy,
  };
  return ids..sort((a, b) => tops[a]!.compareTo(tops[b]!));
}

/// Кнопками ставит шаги в эталонный порядок.
Future<void> _solve(WidgetTester tester) async {
  for (var target = 0; target < 3; target++) {
    final id = 's${target + 1}';
    while (_onScreen(tester).indexOf(id) > target) {
      await tester.tap(find.byKey(Key('order-up-$id')));
      await tester.pump();
    }
  }
}

void main() {
  testWidgets('показывает шаги в порядке, отличном от эталона', (tester) async {
    await _pump(tester);
    expect(_onScreen(tester), isNot(['s1', 's2', 's3', 's4']));
    expect(find.text('Расставьте шаги'), findsOneWidget);
  });

  testWidgets('кнопки ↑↓ двигают шаг; на краях отключены', (tester) async {
    await _pump(tester);
    final first = _onScreen(tester).first;
    final up = tester.widget<IconButton>(find.byKey(Key('order-up-$first')));
    expect(up.onPressed, isNull);

    final before = _onScreen(tester);
    await tester.tap(find.byKey(Key('order-down-$first')));
    await tester.pump();
    final after = _onScreen(tester);
    expect(after[1], first);
    expect(after[0], before[1]);
  });

  testWidgets('верная расстановка кнопками: autoCorrect', (tester) async {
    final results = await _pump(tester);
    await _solve(tester);
    await tester.tap(find.byKey(const Key('order-check')));
    await tester.pump();

    expect(results.single.outcome, AnswerOutcome.autoCorrect);
    expect(results.single.answer, {
      'order': ['s1', 's2', 's3', 's4'],
    });
    expect(find.text('Верно'), findsNWidgets(4));
    expect(find.byKey(const Key('order-check')), findsNothing);
    expect(find.byKey(const Key('order-up-s2')), findsNothing);
  });

  testWidgets('неверная расстановка: autoIncorrect и подсказка места', (
    tester,
  ) async {
    final results = await _pump(tester);
    await tester.tap(find.byKey(const Key('order-check')));
    await tester.pump();

    expect(results.single.outcome, isNot(AnswerOutcome.autoCorrect));
    expect(find.textContaining('Неверно, верное место:'), findsWidgets);
  });

  testWidgets('одна перестановка соседних: orderAdjacentSwap', (tester) async {
    final results = await _pump(tester);
    await _solve(tester);
    // Меняем местами s3 и s4.
    await tester.tap(find.byKey(const Key('order-down-s3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('order-check')));
    await tester.pump();
    expect(results.single.outcome, AnswerOutcome.orderAdjacentSwap);
  });

  testWidgets('перетаскивание за ручку меняет порядок', (tester) async {
    await _pump(tester);
    final before = _onScreen(tester);
    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 130));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_onScreen(tester), isNot(before));
  });

  testWidgets(
    'шаги переставляются вопреки перемешиванию: порядок зерна стабилен',
    (tester) async {
      await _pump(tester, seed: 5);
      final a = _onScreen(tester);
      await _pump(tester, seed: 5);
      expect(_onScreen(tester), a);
      expect(a, shuffledSteps(_steps, 5).map((s) => s.id).toList());
    },
  );

  testWidgets('масштаб текста 200% на 360 dp без переполнения', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, textScale: 2);
    await tester.ensureVisible(find.byKey(const Key('order-check')));
    await tester.tap(find.byKey(const Key('order-check')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
