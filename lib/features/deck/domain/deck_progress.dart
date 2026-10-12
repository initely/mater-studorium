import '../../srs/domain/srs_state.dart';

/// Прогресс по колоде: сколько знаний новых, изучаемых и выученных
/// (ADR-27). Считаются только знания без `retired`.
///
/// Соответствие стадии FSRS (`user_item_state.state`):
/// - новые: строки состояния нет или стадия `new`;
/// - изучаемые: `learning` и `relearning` (шаги или возврат после ошибки);
/// - выученные: `review`.
class DeckProgress {
  const DeckProgress({
    this.newCount = 0,
    this.learningCount = 0,
    this.masteredCount = 0,
  });

  /// [counts]: число знаний по стадии; `state == null` — знания без строки
  /// состояния (ни разу не показывали).
  factory DeckProgress.fromStateCounts(
    Iterable<({SrsState? state, int count})> counts,
  ) {
    var fresh = 0;
    var learning = 0;
    var mastered = 0;
    for (final (:state, :count) in counts) {
      switch (state) {
        case null || SrsState.newCard:
          fresh += count;
        case SrsState.learning || SrsState.relearning:
          learning += count;
        case SrsState.review:
          mastered += count;
      }
    }
    return DeckProgress(
      newCount: fresh,
      learningCount: learning,
      masteredCount: mastered,
    );
  }

  final int newCount;
  final int learningCount;
  final int masteredCount;

  /// Число знаний в колоде.
  int get total => newCount + learningCount + masteredCount;
}
