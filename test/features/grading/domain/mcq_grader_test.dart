import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/grading/domain/mcq_grader.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

McqPayload _payload({required List<String> correct, bool? multiple}) =>
    QuestionPayload.mcq(
      options: const [
        McqOption(id: 'a', text: 'A'),
        McqOption(id: 'b', text: 'B'),
        McqOption(id: 'c', text: 'C'),
        McqOption(id: 'd', text: 'D'),
      ],
      correct: correct,
      multiple: multiple ?? correct.length > 1,
    ) as McqPayload;

void main() {
  group('один верный ответ', () {
    final payload = _payload(correct: ['b']);

    test('выбран верный: autoCorrect', () {
      final grade = gradeMcq(payload, ['b']);
      expect(grade.outcome, AnswerOutcome.autoCorrect);
      expect(grade.isCorrect, isTrue);
      expect(grade.correctSelected, {'b'});
      expect(grade.wrongSelected, isEmpty);
      expect(grade.missed, isEmpty);
    });

    test('выбран неверный: autoIncorrect, верный в пропущенных', () {
      final grade = gradeMcq(payload, ['c']);
      expect(grade.outcome, AnswerOutcome.autoIncorrect);
      expect(grade.isCorrect, isFalse);
      expect(grade.correctSelected, isEmpty);
      expect(grade.wrongSelected, {'c'});
      expect(grade.missed, {'b'});
    });

    test('пустой выбор неверен', () {
      final grade = gradeMcq(payload, const []);
      expect(grade.outcome, AnswerOutcome.autoIncorrect);
      expect(grade.missed, {'b'});
    });
  });

  group('несколько верных ответов (совпадение множеств)', () {
    final payload = _payload(correct: ['a', 'c']);

    test('ровно верные, порядок не важен: autoCorrect', () {
      expect(gradeMcq(payload, ['c', 'a']).outcome, AnswerOutcome.autoCorrect);
    });

    test('повторы в выборе не мешают', () {
      expect(
        gradeMcq(payload, ['a', 'a', 'c']).outcome,
        AnswerOutcome.autoCorrect,
      );
    });

    test('выбрана только часть верных: неверно, остальное в пропущенных', () {
      final grade = gradeMcq(payload, ['a']);
      expect(grade.outcome, AnswerOutcome.autoIncorrect);
      expect(grade.correctSelected, {'a'});
      expect(grade.missed, {'c'});
      expect(grade.wrongSelected, isEmpty);
    });

    test('верные плюс лишний: неверно', () {
      final grade = gradeMcq(payload, ['a', 'c', 'd']);
      expect(grade.outcome, AnswerOutcome.autoIncorrect);
      expect(grade.wrongSelected, {'d'});
      expect(grade.missed, isEmpty);
    });

    test('ни одного верного: неверно', () {
      final grade = gradeMcq(payload, ['b', 'd']);
      expect(grade.outcome, AnswerOutcome.autoIncorrect);
      expect(grade.correctSelected, isEmpty);
      expect(grade.wrongSelected, {'b', 'd'});
      expect(grade.missed, {'a', 'c'});
    });

    test('повторы в correct не меняют результат', () {
      final dup = _payload(correct: ['a', 'a', 'c'], multiple: true);
      expect(gradeMcq(dup, ['a', 'c']).outcome, AnswerOutcome.autoCorrect);
    });
  });

  test('неизвестный id считается неверным выбором', () {
    final grade = gradeMcq(_payload(correct: ['a']), ['a', 'zzz']);
    expect(grade.outcome, AnswerOutcome.autoIncorrect);
    expect(grade.wrongSelected, {'zzz'});
  });

  test('пустой выбор неверен, даже если верных нет (вырожденный вопрос)', () {
    final grade = gradeMcq(_payload(correct: [], multiple: true), const []);
    expect(grade.outcome, AnswerOutcome.autoIncorrect);
  });
}
