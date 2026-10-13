import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/grading/domain/find_error_grader.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';

FindErrorPayload _payload(List<int> errors) => QuestionPayload.findError(
  mode: FindErrorMode.code,
  lines: const ['a', 'b', 'c', 'd'],
  errorLines: errors,
  lineExplanations: {for (final e in errors) e: 'почему $e'},
) as FindErrorPayload;

void main() {
  test('одна ошибочная строка выбрана: autoCorrect', () {
    final g = gradeFindError(_payload([3]), [3]);
    expect(g.outcome, AnswerOutcome.autoCorrect);
    expect(g.isCorrect, isTrue);
    expect(g.found, {3});
    expect(g.wrong, isEmpty);
    expect(g.missed, isEmpty);
  });

  test('две ошибочные строки, порядок и повторы не важны', () {
    expect(
      gradeFindError(_payload([1, 4]), [4, 1, 4]).outcome,
      AnswerOutcome.autoCorrect,
    );
  });

  test('выбрана не та строка: autoIncorrect, ошибка в пропущенных', () {
    final g = gradeFindError(_payload([3]), [2]);
    expect(g.outcome, AnswerOutcome.autoIncorrect);
    expect(g.wrong, {2});
    expect(g.missed, {3});
    expect(g.found, isEmpty);
  });

  test('верная плюс лишняя: неверно', () {
    final g = gradeFindError(_payload([3]), [3, 1]);
    expect(g.outcome, AnswerOutcome.autoIncorrect);
    expect(g.found, {3});
    expect(g.wrong, {1});
  });

  test('найдена одна из двух: неверно, вторая в пропущенных', () {
    final g = gradeFindError(_payload([1, 4]), [1]);
    expect(g.outcome, AnswerOutcome.autoIncorrect);
    expect(g.found, {1});
    expect(g.missed, {4});
  });

  test('пустой выбор всегда неверен', () {
    expect(
      gradeFindError(_payload([2]), []).outcome,
      AnswerOutcome.autoIncorrect,
    );
  });

  test('номер за пределами строк считается неверным выбором', () {
    final g = gradeFindError(_payload([2]), [2, 99]);
    expect(g.outcome, AnswerOutcome.autoIncorrect);
    expect(g.wrong, {99});
  });
}
