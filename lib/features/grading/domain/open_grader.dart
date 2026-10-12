import '../../srs/domain/answer_outcome.dart';
import 'open_grade.dart';

/// Итог проверки `open` для сессии: строка таблицы «источник → предлагаемая
/// оценка» (ТЗ §4.1) и балл для `review_logs.llm_score`.
class OpenGradeResult {
  const OpenGradeResult({required this.outcome, this.llmScore});

  final AnswerOutcome outcome;

  /// Балл модели 0…1; `null`, если оценивала не модель (`unsure`, правило).
  final double? llmScore;
}

/// Переводит ответ сервера в [AnswerOutcome] (ТЗ §4.2, M5).
///
/// Клиент доверяет вердикту сервера и не пересчитывает пороги по `score`
/// (0.70 / 0.35 — серверная калибровка, ADR-28): `score` только пишется в лог.
///
/// - `unsure` — самооценка с эталоном (`llmUnavailable`, `grade_source = self`);
/// - ответ короче 3 символов (`source: rule`, `incorrect`) — детерминированное
///   правило, не мнение модели: `autoIncorrect` (`grade_source = auto`), без
///   `llm_score`;
/// - остальное — вердикт модели (`llm*`, `grade_source = llm`).
OpenGradeResult gradeOpenAnswer(OpenGrade grade) {
  if (grade.verdict == GradeVerdict.unsure) {
    return const OpenGradeResult(outcome: AnswerOutcome.llmUnavailable);
  }
  if (grade.origin == GradeOrigin.rule &&
      grade.verdict == GradeVerdict.incorrect) {
    return const OpenGradeResult(outcome: AnswerOutcome.autoIncorrect);
  }
  return OpenGradeResult(
    outcome: switch (grade.verdict) {
      GradeVerdict.correct => AnswerOutcome.llmCorrect,
      GradeVerdict.partial => AnswerOutcome.llmPartial,
      GradeVerdict.incorrect => AnswerOutcome.llmIncorrect,
      GradeVerdict.unsure => AnswerOutcome.llmUnavailable,
    },
    llmScore: grade.origin == GradeOrigin.llm ? grade.score : null,
  );
}

/// Итог для ответа, который клиент отсёк сам (пустой или короче 3 символов,
/// ТЗ §4.2, п. 1): как правило сервера, без запроса.
const OpenGradeResult kTooShortOpenResult = OpenGradeResult(
  outcome: AnswerOutcome.autoIncorrect,
);

/// Итог самооценки с эталоном (проверка недоступна или отключена):
/// `grade_source = self`, подсказки нет.
const OpenGradeResult kSelfAssessedOpenResult = OpenGradeResult(
  outcome: AnswerOutcome.llmUnavailable,
);
