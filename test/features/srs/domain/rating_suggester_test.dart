import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/rating_suggester.dart';

void main() {
  test('таблица ТЗ §4.1: источник → оценка и grade_source', () {
    const table = <AnswerOutcome, (Rating?, GradeSource)>{
      AnswerOutcome.autoCorrect: (Rating.good, GradeSource.auto),
      AnswerOutcome.autoIncorrect: (Rating.again, GradeSource.auto),
      AnswerOutcome.orderAdjacentSwap: (Rating.hard, GradeSource.auto),
      AnswerOutcome.clozeTypo: (Rating.hard, GradeSource.auto),
      AnswerOutcome.llmCorrect: (Rating.good, GradeSource.llm),
      AnswerOutcome.llmPartial: (Rating.hard, GradeSource.llm),
      AnswerOutcome.llmIncorrect: (Rating.again, GradeSource.llm),
      AnswerOutcome.llmUnavailable: (null, GradeSource.self),
      AnswerOutcome.flip: (null, GradeSource.self),
    };
    expect(table.keys, unorderedEquals(AnswerOutcome.values));
    for (final MapEntry(key: outcome, value: (rating, source))
        in table.entries) {
      final s = suggestRating(outcome);
      expect(s.rating, rating, reason: '$outcome');
      expect(s.source, source, reason: '$outcome');
    }
  });

  group('sourceFor: grade_source по выбранной кнопке', () {
    test('принял подсказку — источник подсказки', () {
      expect(
        suggestRating(AnswerOutcome.autoCorrect).sourceFor(Rating.good),
        GradeSource.auto,
      );
      expect(
        suggestRating(AnswerOutcome.llmPartial).sourceFor(Rating.hard),
        GradeSource.llm,
      );
    });

    test('выбрал другую кнопку — override (M11)', () {
      expect(
        suggestRating(AnswerOutcome.llmIncorrect).sourceFor(Rating.good),
        GradeSource.override,
      );
      expect(
        suggestRating(AnswerOutcome.autoCorrect).sourceFor(Rating.again),
        GradeSource.override,
      );
    });

    test('подсказки не было — self при любой кнопке', () {
      for (final outcome in [
        AnswerOutcome.flip,
        AnswerOutcome.llmUnavailable,
      ]) {
        for (final r in Rating.values) {
          expect(suggestRating(outcome).sourceFor(r), GradeSource.self);
        }
      }
    });
  });
}
