import '../../catalog/domain/local_item.dart';
import '../../catalog/domain/question.dart';
import '../../srs/domain/item_state.dart';
import '../../srs/domain/srs_state.dart';

/// Одно знание в очереди сессии: знание, выбранный вариант вопроса и
/// состояние FSRS (для нового знания — `SrsState.newCard`).
class SessionItem {
  const SessionItem({
    required this.item,
    required this.deckVersion,
    required this.question,
    required this.state,
  });

  final LocalItem item;

  /// Версия колоды на момент построения очереди (идёт в `review_logs`).
  final int deckVersion;

  /// Вариант, выбранный `VariantPicker`.
  final Question question;

  final ItemState state;

  bool get isNew => state.state == SrsState.newCard;
}
