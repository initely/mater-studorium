import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/grading/domain/order_grader.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

final _steps = [
  for (final id in ['s1', 's2', 's3', 's4']) OrderStep(id: id, text: 'Шаг $id'),
];
final _payload = QuestionPayload.order(steps: _steps) as OrderPayload;

AnswerOutcome _grade(List<String> ids) => gradeOrder(_payload, ids).outcome;

void main() {
  group('shuffledSteps', () {
    test('детерминирован по зерну и не меняет исходный список', () {
      final a = shuffledSteps(_steps, 7).map((s) => s.id).toList();
      final b = shuffledSteps(_steps, 7).map((s) => s.id).toList();
      expect(a, b);
      expect(_steps.map((s) => s.id), ['s1', 's2', 's3', 's4']);
    });
    test('никогда не равен эталону (500 зёрен, 3 и 4 шага)', () {
      for (final n in [3, 4]) {
        final steps = _steps.take(n).toList();
        for (var seed = 0; seed < 500; seed++) {
          final ids = shuffledSteps(steps, seed).map((s) => s.id).toList();
          expect(ids, isNot(steps.map((s) => s.id).toList()), reason: '$seed');
          expect(ids.toSet(), steps.map((s) => s.id).toSet());
        }
      }
    });
    test('один шаг возвращается как есть', () {
      expect(shuffledSteps(_steps.take(1).toList(), 1), hasLength(1));
    });
  });

  group('gradeOrder', () {
    test('полное совпадение: autoCorrect', () {
      final g = gradeOrder(_payload, ['s1', 's2', 's3', 's4']);
      expect(g.outcome, AnswerOutcome.autoCorrect);
      expect(g.isCorrect, isTrue);
      expect(g.steps.every((s) => s.isCorrect), isTrue);
    });
    test('одна перестановка соседних: orderAdjacentSwap в любом месте', () {
      expect(_grade(['s2', 's1', 's3', 's4']), AnswerOutcome.orderAdjacentSwap);
      expect(_grade(['s1', 's3', 's2', 's4']), AnswerOutcome.orderAdjacentSwap);
      expect(_grade(['s1', 's2', 's4', 's3']), AnswerOutcome.orderAdjacentSwap);
    });
    test('перестановка несоседних: autoIncorrect', () {
      expect(_grade(['s3', 's2', 's1', 's4']), AnswerOutcome.autoIncorrect);
    });
    test('две независимые перестановки: autoIncorrect', () {
      expect(_grade(['s2', 's1', 's4', 's3']), AnswerOutcome.autoIncorrect);
    });
    test('циклический сдвиг: autoIncorrect', () {
      expect(_grade(['s2', 's3', 's4', 's1']), AnswerOutcome.autoIncorrect);
      expect(_grade(['s4', 's1', 's2', 's3']), AnswerOutcome.autoIncorrect);
    });
    test('полностью обратный порядок: autoIncorrect', () {
      expect(_grade(['s4', 's3', 's2', 's1']), AnswerOutcome.autoIncorrect);
    });
    test('позиции для подсветки', () {
      final g = gradeOrder(_payload, ['s2', 's1', 's3', 's4']);
      expect(g.steps.map((s) => s.position), [1, 2, 3, 4]);
      expect(g.steps.map((s) => s.correctPosition), [2, 1, 3, 4]);
      expect(g.steps.map((s) => s.isCorrect), [false, false, true, true]);
    });
    test('набор id не совпадает со шагами: autoIncorrect', () {
      expect(_grade(['s1', 's2', 's3']), AnswerOutcome.autoIncorrect);
      expect(_grade(['s1', 's2', 's3', 'x']), AnswerOutcome.autoIncorrect);
      expect(_grade(['s1', 's1', 's3', 's4']), AnswerOutcome.autoIncorrect);
      expect(_grade([]), AnswerOutcome.autoIncorrect);
    });
  });
}
