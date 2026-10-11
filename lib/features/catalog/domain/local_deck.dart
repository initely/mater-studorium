import 'package:freezed_annotation/freezed_annotation.dart';

part 'local_deck.freezed.dart';

/// Колода, скачанная на устройство (строка `decks`, ТЗ §7.3).
@freezed
abstract class LocalDeck with _$LocalDeck {
  const factory LocalDeck({
    required String id,
    required int version,
    required String title,
    required String topic,
    required String lang,

    /// UTC.
    required DateTime downloadedAt,
  }) = _LocalDeck;
}
