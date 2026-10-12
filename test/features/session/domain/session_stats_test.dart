import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/session/domain/session_stats.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

final _t0 = DateTime.utc(2026, 10, 11, 12);

ReviewLog _log(Rating rating, GradeSource source, {int seconds = 10}) =>
    ReviewLog(
      id: 'l$seconds-${rating.name}-${source.name}',
      deckId: 'd1',
      deckVersion: 1,
      itemId: 'i',
      questionId: 'q',
      questionType: QuestionType.mcq,
      rating: rating,
      gradeSource: source,
      durationMs: 1000,
      reviewedAt: _t0.add(Duration(seconds: seconds)),
    );

void main() {
  test('без ответов: нули', () {
    final s = SessionStats.from(const [], _t0);
    expect(s.reviewed, 0);
    expect(s.correct, 0);
    expect(s.incorrect, 0);
    expect(s.selfRated, 0);
    expect(s.elapsed, Duration.zero);
  });

  test('верно, неверно и по самооценке считаются отдельно', () {
    final s = SessionStats.from([
      _log(Rating.good, GradeSource.auto, seconds: 10),
      _log(Rating.again, GradeSource.auto, seconds: 20),
      _log(Rating.hard, GradeSource.auto, seconds: 30),
      _log(Rating.easy, GradeSource.llm, seconds: 40),
      _log(Rating.again, GradeSource.llm, seconds: 50),
      _log(Rating.again, GradeSource.self, seconds: 60),
      _log(Rating.good, GradeSource.self, seconds: 70),
    ], _t0);
    expect(s.reviewed, 7);
    expect(s.correct, 3);
    expect(s.incorrect, 2);
    expect(s.selfRated, 2);
    expect(s.correct + s.incorrect + s.selfRated, s.reviewed);
  });

  test('переопределение оценки считается по итоговой оценке', () {
    final s = SessionStats.from([
      // Автопроверка сказала «верно», пользователь поставил «Снова».
      _log(Rating.again, GradeSource.override, seconds: 10),
      // Автопроверка сказала «неверно», пользователь поставил «Хорошо».
      _log(Rating.good, GradeSource.override, seconds: 20),
    ], _t0);
    expect(s.incorrect, 1);
    expect(s.correct, 1);
  });

  test('время — от старта до последнего ответа', () {
    final s = SessionStats.from([
      _log(Rating.good, GradeSource.auto, seconds: 15),
      _log(Rating.good, GradeSource.auto, seconds: 200),
    ], _t0);
    expect(s.elapsed, const Duration(seconds: 200));
  });

  test('часы ушли назад: время не отрицательное', () {
    final s = SessionStats.from([
      _log(Rating.good, GradeSource.auto, seconds: -30),
    ], _t0);
    expect(s.elapsed, Duration.zero);
  });
}
