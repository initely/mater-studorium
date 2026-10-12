import '../../srs/domain/rating.dart';
import 'grade_source.dart';
import 'review_log.dart';

/// Числа для экрана итогов (ТЗ §8.2, п. 5: «повторено 14, верно 11»).
///
/// Считаются только из того, что реально записано в `review_logs`: вердикт
/// формата там не хранится, поэтому «верно» и «неверно» — это итоговая
/// оценка пользователя при проверке системой (`auto`, `llm`) или после её
/// исправления (`override`): «Снова» — неверно, остальные оценки — верно.
/// Ответы, где пользователь оценил себя сам (`flip`, `open` без вердикта),
/// считаются отдельно: системе судить о них нечем.
class SessionStats {
  const SessionStats({
    required this.reviewed,
    required this.correct,
    required this.incorrect,
    required this.selfRated,
    required this.elapsed,
  });

  /// Считает итоги по [answers] (в порядке ответа) сессии, начатой в
  /// [startedAt]. Время сессии — от старта до последнего ответа; без ответов
  /// и при часах, ушедших назад, — ноль.
  factory SessionStats.from(List<ReviewLog> answers, DateTime startedAt) {
    var correct = 0;
    var incorrect = 0;
    var selfRated = 0;
    for (final answer in answers) {
      if (answer.gradeSource == GradeSource.self) {
        selfRated++;
      } else if (answer.rating == Rating.again) {
        incorrect++;
      } else {
        correct++;
      }
    }
    var elapsed = Duration.zero;
    if (answers.isNotEmpty) {
      final spent = answers.last.reviewedAt.difference(startedAt);
      if (!spent.isNegative) elapsed = spent;
    }
    return SessionStats(
      reviewed: answers.length,
      correct: correct,
      incorrect: incorrect,
      selfRated: selfRated,
      elapsed: elapsed,
    );
  }

  /// Сколько вопросов отвечено; `correct + incorrect + selfRated`.
  final int reviewed;

  /// Проверено системой и оценено выше «Снова».
  final int correct;

  /// Проверено системой и оценено «Снова».
  final int incorrect;

  /// Пользователь оценил себя сам.
  final int selfRated;

  /// Сколько длилась сессия до последнего ответа.
  final Duration elapsed;
}
