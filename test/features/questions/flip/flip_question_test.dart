import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/questions/flip/flip_question.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

import '../../../helpers/pump_app.dart';

Future<List<QuestionResult>> _pump(WidgetTester tester) async {
  final results = <QuestionResult>[];
  await tester.pumpApp(
    Scaffold(
      body: FlipQuestion(
        prompt: 'Что такое HSTS?',
        back: 'Заголовок, требующий HTTPS',
        onAnswered: results.add,
      ),
    ),
  );
  return results;
}

void main() {
  testWidgets('сначала только лицевая сторона и кнопка «Показать ответ»', (
    tester,
  ) async {
    final results = await _pump(tester);
    expect(find.text('Что такое HSTS?'), findsOneWidget);
    expect(find.text('Показать ответ'), findsOneWidget);
    expect(find.text('Заголовок, требующий HTTPS'), findsNothing);
    expect(results, isEmpty);
  });

  testWidgets('«Показать ответ» открывает оборот и отдаёт результат flip', (
    tester,
  ) async {
    final results = await _pump(tester);
    await tester.tap(find.byKey(const Key('flip-show')));
    await tester.pump();

    expect(find.text('Заголовок, требующий HTTPS'), findsOneWidget);
    expect(find.text('Ответ'), findsOneWidget);
    expect(find.byKey(const Key('flip-show')), findsNothing);
    expect(results, hasLength(1));
    // flip: самооценка без подсказки и без вердикта.
    expect(results.single.outcome, AnswerOutcome.flip);
    expect(results.single.answerText, isNull);
    expect(results.single.llmScore, isNull);
  });

  testWidgets('оборот и сообщение об ответе не дублируются при перестройке', (
    tester,
  ) async {
    final results = await _pump(tester);
    await tester.tap(find.byKey(const Key('flip-show')));
    await tester.pump();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 400);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    expect(find.text('Заголовок, требующий HTTPS'), findsOneWidget);
    expect(results, hasLength(1));
  });

  testWidgets('доступность: кнопка не меньше 48 dp, подписана', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      tester.getSize(find.byKey(const Key('flip-show'))).height,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
  });
}
