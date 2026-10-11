import 'package:freezed_annotation/freezed_annotation.dart';

part 'item_ref.freezed.dart';
part 'item_ref.g.dart';

/// Ссылка знания на источник вместе с данными источника.
///
/// В колоде `refs[]` хранят только `source_id` (ТЗ §5.3, ADR-18), а таблицы
/// `sources` в локальной БД нет. Поэтому при записи колоды название, URL и
/// лицензия источника копируются в `items.refs_json`: разбору (T14) для показа
/// ссылок больше ничего не нужно.
@freezed
abstract class ItemRef with _$ItemRef {
  const factory ItemRef({
    required String sourceId,
    required String quote,
    @Default(false) bool quoteUnverifiable,
    required String sourceTitle,
    required String url,
    required String license,
  }) = _ItemRef;

  factory ItemRef.fromJson(Map<String, dynamic> json) =>
      _$ItemRefFromJson(json);
}
