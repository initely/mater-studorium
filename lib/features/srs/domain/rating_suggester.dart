import '../../session/domain/grade_source.dart';
import 'answer_outcome.dart';
import 'rating.dart';

/// Предложенная оценка для панели из 4 кнопок (ТЗ §4.1).
class RatingSuggestion {
  const RatingSuggestion(this.rating, this.source);

  /// Подсвеченная кнопка; `null` — без подсказки, оценивает пользователь.
  final Rating? rating;

  /// Кто дал оценку, если пользователь её примет.
  final GradeSource source;

  /// `grade_source` для лога, если пользователь выбрал [chosen] (ТЗ §7.2):
  /// приняв подсказку — [source]; выбрав другую кнопку — `override`;
  /// без подсказки — `self`.
  GradeSource sourceFor(Rating chosen) {
    if (rating == null) return GradeSource.self;
    return chosen == rating ? source : GradeSource.override;
  }
}

/// Таблица «источник → предлагаемая оценка» из ТЗ §4.1.
RatingSuggestion suggestRating(AnswerOutcome outcome) => switch (outcome) {
  AnswerOutcome.autoCorrect => const RatingSuggestion(
    Rating.good,
    GradeSource.auto,
  ),
  AnswerOutcome.autoIncorrect => const RatingSuggestion(
    Rating.again,
    GradeSource.auto,
  ),
  AnswerOutcome.orderAdjacentSwap || AnswerOutcome.clozeTypo =>
    const RatingSuggestion(Rating.hard, GradeSource.auto),
  AnswerOutcome.llmCorrect => const RatingSuggestion(
    Rating.good,
    GradeSource.llm,
  ),
  AnswerOutcome.llmPartial => const RatingSuggestion(
    Rating.hard,
    GradeSource.llm,
  ),
  AnswerOutcome.llmIncorrect => const RatingSuggestion(
    Rating.again,
    GradeSource.llm,
  ),
  AnswerOutcome.llmUnavailable ||
  AnswerOutcome.flip => const RatingSuggestion(null, GradeSource.self),
};
