import 'package:flutter/foundation.dart';

import '../../../core/db/decks_dao.dart';
import '../../../core/errors/app_error.dart';
import '../domain/catalog_repository.dart';
import '../domain/deck.dart';
import '../domain/deck_parser.dart';
import '../domain/local_deck.dart';
import '../domain/remote_deck.dart';
import 'deck_remote_source.dart';

/// Разбор файла колоды; по умолчанию в изоляте (`compute`), чтобы колода на
/// сотни знаний не подвешивала интерфейс (ТЗ M2, AC2.1).
typedef DeckParser = Future<DeckParseResult> Function(Uint8List bytes);

Future<DeckParseResult> parseDeckInIsolate(Uint8List bytes) =>
    compute(parseDeckBytes, bytes);

/// [CatalogRepository]: список и файлы с сервера ([DeckRemoteSource]), запись
/// в локальную БД через [DecksDao.replaceDeck] (одна транзакция, `retired`
/// для исчезнувших знаний, проверка коллизий `item_id`).
class DriftCatalogRepository implements CatalogRepository {
  DriftCatalogRepository({
    required this._remote,
    required this._decks,
    required this._clock,
    DeckParser parser = parseDeckInIsolate,
  }) : _parse = parser;

  final DeckRemoteSource _remote;
  final DecksDao _decks;
  final DateTime Function() _clock;
  final DeckParser _parse;

  @override
  Future<List<RemoteDeck>> list() => _remote.fetchDecks();

  @override
  Stream<List<LocalDeck>> watchDownloaded() => _decks.watchDecks();

  @override
  Future<LocalDeck> download(String deckId) async {
    final remote = await _remote.fetchDeck(deckId);
    if (remote == null) throw DeckNotFoundError(deckId);

    final local = await _readLocal(deckId);
    if (local != null && local.version >= remote.version) return local;

    final bytes = await _remote.downloadDeckFile(remote.storagePath);
    final deck = _checked(await _parse(bytes), remote);

    // Запись одной транзакцией: при ошибке (в том числе коллизии item_id)
    // локальная БД остаётся как была, то есть со старой версией.
    try {
      await _decks.replaceDeck(deck, downloadedAt: _clock());
    } on AppError {
      rethrow;
    } catch (e) {
      throw UnexpectedError('Не удалось записать колоду $deckId', cause: e);
    }
    return (await _readLocal(deckId))!;
  }

  Future<LocalDeck?> _readLocal(String deckId) async {
    try {
      return await _decks.getDeck(deckId);
    } catch (e) {
      throw UnexpectedError('Не удалось прочитать колоду $deckId', cause: e);
    }
  }

  /// Результат разбора → колода или типизированная ошибка. Файл обязан
  /// совпадать со строкой каталога: иначе сервер отдал не тот файл.
  Deck _checked(DeckParseResult result, RemoteDeck remote) {
    switch (result) {
      case DeckParseCorrupt(:final message):
        throw DeckFormatError('Колода ${remote.id}: $message');
      case DeckParseSchemaTooNew(:final schemaVersion):
        throw DeckSchemaTooNewError(schemaVersion, kDeckSchemaVersion);
      case DeckParsed(:final deck):
        if (deck.id != remote.id || deck.version != remote.version) {
          throw DeckFormatError(
            'Файл ${remote.storagePath}: внутри колода ${deck.id} '
            'версии ${deck.version}, в каталоге ${remote.id} '
            'версии ${remote.version}',
          );
        }
        return deck;
    }
  }
}
