import 'package:freezed_annotation/freezed_annotation.dart';

import 'item_ref.dart';

part 'local_item.freezed.dart';

/// Знание из локальной БД (строка `items`, без вопросов).
///
/// Теги и вычитка (`review`) не хранятся: клиенту они не нужны.
@freezed
abstract class LocalItem with _$LocalItem {
  const factory LocalItem({
    required String id,
    required String deckId,
    required String title,
    required String fact,
    required String explanationShort,
    required String explanationLong,
    required List<ItemRef> refs,

    /// Знания нет в последней скачанной версии колоды; прогресс сохранён,
    /// в очередь не попадает.
    required bool retired,
  }) = _LocalItem;
}
