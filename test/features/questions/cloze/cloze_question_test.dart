import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/questions/cloze/cloze_question.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

import '../../../helpers/pump_app.dart';

final _payload = const QuestionPayload.cloze(
  blanks: [
    ClozeBlank(id: 'a', accepted: ['TCP']),
    ClozeBlank(id: 'b', accepted: ['handshake']),
  ],
) as ClozePayload;

const _prompt = 'Соединение начинается с {{a}} и трёхстороннего {{b}}.';

Future<List<QuestionResult>> _pump(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  final results = <QuestionResult>[];
  await tester.pumpApp(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: ClozeQuestion(
            prompt: _prompt,
            payload: _payload,
            onAnswered: results.add,
          ),
        ),
      ),
    ),
  );
  return results;
}

void main() {
  testWidgets('рисует поля вместо плейсхолдеров', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('cloze-field-a')), findsOneWidget);
    expect(find.byKey(const Key('cloze-field-b')), findsOneWidget);
    expect(find.textContaining('{{'), findsNothing);
  });

  testWidgets('верные ответы: autoCorrect, поля заблокированы', (tester) async {
    final results = await _pump(tester);
    await tester.enterText(find.byKey(const Key('cloze-field-a')), 'tcp');
    await tester.enterText(find.byKey(const Key('cloze-field-b')), 'Handshake');
    await tester.tap(find.byKey(const Key('cloze-answer')));
    await tester.pump();

    expect(results.single.outcome, AnswerOutcome.autoCorrect);
    expect(results.single.answer, {
      'answers': {'a': 'tcp', 'b': 'Handshake'},
    });
    expect(find.byKey(const Key('cloze-caption-a')), findsOneWidget);
    expect(find.byKey(const Key('cloze-answer')), findsNothing);
    final field = tester.widget<TextField>(
      find.byKey(const Key('cloze-field-a')),
    );
    expect(field.readOnly, isTrue);
  });

  testWidgets('неверный пропуск: autoIncorrect и показан верный ответ', (
    tester,
  ) async {
    final results = await _pump(tester);
    await tester.enterText(find.byKey(const Key('cloze-field-a')), 'udp');
    await tester.enterText(find.byKey(const Key('cloze-field-b')), 'handshake');
    await tester.tap(find.byKey(const Key('cloze-answer')));
    await tester.pump();

    expect(results.single.outcome, AnswerOutcome.autoIncorrect);
    expect(find.textContaining('Верно: TCP'), findsOneWidget);
  });

  testWidgets('опечатка: clozeTypo', (tester) async {
    final results = await _pump(tester);
    await tester.enterText(find.byKey(const Key('cloze-field-a')), 'tcp');
    await tester.enterText(find.byKey(const Key('cloze-field-b')), 'handshke');
    await tester.tap(find.byKey(const Key('cloze-answer')));
    await tester.pump();

    expect(results.single.outcome, AnswerOutcome.clozeTypo);
  });

  testWidgets('Enter: из первого поля фокус во второе, из последнего ответ', (
    tester,
  ) async {
    final results = await _pump(tester);
    await tester.tap(find.byKey(const Key('cloze-field-a')));
    await tester.enterText(find.byKey(const Key('cloze-field-a')), 'tcp');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(results, isEmpty);

    await tester.enterText(find.byKey(const Key('cloze-field-b')), 'handshake');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(results.single.outcome, AnswerOutcome.autoCorrect);
  });

  testWidgets('ответ отправляется один раз', (tester) async {
    final results = await _pump(tester);
    await tester.tap(find.byKey(const Key('cloze-answer')));
    await tester.pump();
    expect(results, hasLength(1));
    expect(results.single.outcome, AnswerOutcome.autoIncorrect);
  });

  testWidgets('масштаб текста 200% без переполнения', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, textScale: 2);
    await tester.enterText(find.byKey(const Key('cloze-field-a')), 'udp');
    await tester.tap(find.byKey(const Key('cloze-answer')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
