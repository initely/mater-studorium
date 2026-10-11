import '../srs/domain/answer_outcome.dart';

/// Результат ответа на вопрос: то, что виджет формата отдаёт сессии через
/// `QuestionRequest.onAnswered`. Сессия по [outcome] берёт предложенную
/// оценку (`suggestRating`), остальное пишет в `review_logs`.
class QuestionResult {
  const QuestionResult({required this.outcome, this.answerText, this.llmScore});

  /// Строка таблицы «источник → предлагаемая оценка» (ТЗ §4.1).
  final AnswerOutcome outcome;

  /// `review_logs.answer_text`: текст открытого ответа; у остальных форматов
  /// `null`.
  final String? answerText;

  /// `review_logs.llm_score` (только `open`).
  final double? llmScore;
}
