import 'package:freezed_annotation/freezed_annotation.dart';

import 'deck_item.dart';
import 'deck_source.dart';

part 'deck.freezed.dart';
part 'deck.g.dart';

/// Версия формата колоды, которую понимает этот код.
///
/// Меняется вместе с `content/schema/deck.schema.json`, моделями и
/// валидатором в одном PR (ТЗ §14, ADR-18).
const kDeckSchemaVersion = 1;

/// Колода — источник истины контента (ТЗ §7.1).
///
/// Контракт: `content/schema/deck.schema.json`. Семантические правила —
/// `validateDeck` в `deck_validator.dart`.
@freezed
abstract class Deck with _$Deck {
  const factory Deck({
    required int schemaVersion,
    required String id,
    required int version,
    required String lang,
    required String topic,
    required String title,
    required String description,
    required List<DeckSource> sources,
    required List<DeckItem> items,
  }) = _Deck;

  factory Deck.fromJson(Map<String, dynamic> json) => _$DeckFromJson(json);
}
