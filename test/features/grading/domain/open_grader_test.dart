import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/grading/domain/open_answer_limits.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/grading/domain/open_grader.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/rating_suggester.dart';

import '../../../helpers/fake_open_services.dart';

void main() {
  group('gradeOpenAnswer: вердикт сервера → AnswerOutcome', () {
    test('correct, partial, incorrect от модели', () {
      final correct = gradeOpenAnswer(
        fakeGrade(verdict: GradeVerdict.correct, score: 0.9),
      );
      expect(correct.outcome, AnswerOutcome.llmCorrect);
      expect(correct.llmScore, 0.9);

      final partial = gradeOpenAnswer(
        fakeGrade(verdict: GradeVerdict.partial, score: 0.5),
      );
      expect(partial.outcome, AnswerOutcome.llmPartial);
      expect(partial.llmScore, 0.5);

      final incorrect = gradeOpenAnswer(
        fakeGrade(verdict: GradeVerdict.incorrect, score: 0.1),
      );
      expect(incorrect.outcome, AnswerOutcome.llmIncorrect);
      expect(incorrect.llmScore, 0.1);
    });

    test('unsure — самооценка без балла', () {
      final r = gradeOpenAnswer(
        fakeGrade(verdict: GradeVerdict.unsure, score: 0),
      );
      expect(r.outcome, AnswerOutcome.llmUnavailable);
      expect(r.llmScore, isNull);
    });

    test('правило «короче 3 символов»: auto, без llm_score', () {
      final r = gradeOpenAnswer(
        fakeGrade(
          verdict: GradeVerdict.incorrect,
          score: 0,
          origin: GradeOrigin.rule,
          points: const [],
          missed: const [],
          feedback: '',
        ),
      );
      expect(r.outcome, AnswerOutcome.autoIncorrect);
      expect(r.llmScore, isNull);
    });

    test('клиент не пересчитывает пороги: вердикт важнее балла', () {
      // score 0.95 при вердикте incorrect остаётся incorrect, и наоборот
      // (пороги 0.70 / 0.35 — серверная калибровка, ADR-28).
      expect(
        gradeOpenAnswer(fakeGrade(verdict: GradeVerdict.incorrect, score: 0.95))
            .outcome,
        AnswerOutcome.llmIncorrect,
      );
      expect(
        gradeOpenAnswer(fakeGrade(verdict: GradeVerdict.correct, score: 0.05))
            .outcome,
        AnswerOutcome.llmCorrect,
      );
      expect(
        gradeOpenAnswer(fakeGrade(verdict: GradeVerdict.partial, score: 0.69))
            .outcome,
        AnswerOutcome.llmPartial,
      );
    });

    test('из кэша — как обычная оценка модели', () {
      final r = gradeOpenAnswer(
        fakeGrade(verdict: GradeVerdict.correct, score: 0.8, cached: true),
      );
      expect(r.outcome, AnswerOutcome.llmCorrect);
      expect(r.llmScore, 0.8);
    });
  });

  group('предложенная оценка и grade_source (RatingSuggester)', () {
    ({Rating? suggested, GradeSource accepted, GradeSource other}) of(
      OpenGrade g,
    ) {
      final s = suggestRating(gradeOpenAnswer(g).outcome);
      return (
        suggested: s.rating,
        accepted: s.sourceFor(s.rating ?? Rating.good),
        other: s.sourceFor(Rating.easy),
      );
    }

    test('correct → Good, llm; другая кнопка — override', () {
      final r = of(fakeGrade(verdict: GradeVerdict.correct));
      expect(r.suggested, Rating.good);
      expect(r.accepted, GradeSource.llm);
      expect(r.other, GradeSource.override);
    });

    test('partial → Hard, llm', () {
      final r = of(fakeGrade(verdict: GradeVerdict.partial));
      expect(r.suggested, Rating.hard);
      expect(r.accepted, GradeSource.llm);
    });

    test('incorrect → Again, llm', () {
      final r = of(fakeGrade(verdict: GradeVerdict.incorrect));
      expect(r.suggested, Rating.again);
      expect(r.accepted, GradeSource.llm);
    });

    test('unsure и самооценка: без подсказки, любая кнопка — self', () {
      for (final outcome in [
        gradeOpenAnswer(fakeGrade(verdict: GradeVerdict.unsure)).outcome,
        kSelfAssessedOpenResult.outcome,
      ]) {
        final s = suggestRating(outcome);
        expect(s.rating, isNull);
        for (final rating in Rating.values) {
          expect(s.sourceFor(rating), GradeSource.self);
        }
      }
    });

    test('короткий ответ (клиент или правило сервера) → Again, auto', () {
      final s = suggestRating(kTooShortOpenResult.outcome);
      expect(s.rating, Rating.again);
      expect(s.sourceFor(Rating.again), GradeSource.auto);
    });
  });

  group('границы ответа', () {
    test('короткий ответ: пусто, пробелы, 1–2 символа; 3 — уже нет', () {
      expect(isTooShortOpenAnswer(''), isTrue);
      expect(isTooShortOpenAnswer('   \n '), isTrue);
      expect(isTooShortOpenAnswer('ок'), isTrue);
      expect(isTooShortOpenAnswer('  ок  '), isTrue);
      expect(isTooShortOpenAnswer('abc'), isFalse);
      expect(isTooShortOpenAnswer(' abc '), isFalse);
      // Эмодзи — один символ (руна), а не две единицы UTF-16.
      expect(isTooShortOpenAnswer('😀😀'), isTrue);
      expect(isTooShortOpenAnswer('😀😀😀'), isFalse);
    });

    test('лимит: 2000 единиц UTF-16 проходят, лишнее обрезается', () {
      final ok = 'a' * kMaxOpenAnswerChars;
      expect(clampOpenAnswer(ok), ok);
      expect(clampOpenAnswer('${ok}b'), ok);
      expect(clampOpenAnswer('a' * 5000).length, kMaxOpenAnswerChars);
    });

    test('обрезка не разрывает суррогатную пару', () {
      final text = '${'a' * (kMaxOpenAnswerChars - 1)}😀хвост';
      final clamped = clampOpenAnswer(text);
      expect(clamped.length, kMaxOpenAnswerChars - 1);
      expect(clamped.endsWith('a'), isTrue);
      // Пара целиком помещается — остаётся.
      final fits = '${'a' * (kMaxOpenAnswerChars - 2)}😀хвост';
      expect(clampOpenAnswer(fits).length, kMaxOpenAnswerChars);
      expect(clampOpenAnswer(fits).endsWith('😀'), isTrue);
    });
  });
}
