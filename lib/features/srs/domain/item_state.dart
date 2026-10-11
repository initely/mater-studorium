import 'package:freezed_annotation/freezed_annotation.dart';

import 'srs_state.dart';

part 'item_state.freezed.dart';

/// Состояние знания в FSRS у пользователя (ТЗ §4.1, §7.2 `user_item_state`).
///
/// Без `user_id` и `dirty`: это забота хранилища и синхронизации.
/// Все даты — UTC.
@freezed
abstract class ItemState with _$ItemState {
  const factory ItemState({
    required String itemId,
    required String deckId,
    required DateTime due,
    required double stability,
    required double difficulty,
    required int elapsedDays,
    required int scheduledDays,
    required int reps,
    required int lapses,
    required SrsState state,
    DateTime? lastReview,
    String? lastQuestionId,

    /// Для LWW-слияния при синхронизации.
    required DateTime updatedAt,
  }) = _ItemState;
}
