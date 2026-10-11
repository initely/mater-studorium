import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_deck.freezed.dart';

/// Колода в каталоге сервера (строка `decks`, ТЗ §7.2). Содержимого (знаний и
/// вопросов) здесь нет: оно в файле `storagePath`, который качает `download`.
@freezed
abstract class RemoteDeck with _$RemoteDeck {
  const factory RemoteDeck({
    required String id,
    required String title,
    required String topic,
    required String lang,
    required int version,
    required int itemCount,

    /// Путь файла внутри bucket `decks`: `<id>/v<version>.json`.
    required String storagePath,
  }) = _RemoteDeck;
}
