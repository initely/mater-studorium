import 'dart:typed_data';

import '../../../core/errors/app_error.dart';
import '../domain/remote_deck.dart';

/// Сервер каталога: метаданные колод и файлы. Единственное место, которое
/// знает про Supabase; все сбои выходят как [AppError].
abstract interface class DeckRemoteSource {
  /// Колоды, видимые пользователю (RLS: public и свои).
  Future<List<RemoteDeck>> fetchDecks();

  /// Колода по id или null, если её нет или она не видна пользователю.
  Future<RemoteDeck?> fetchDeck(String deckId);

  /// Байты файла колоды из bucket `decks`.
  Future<Uint8List> downloadDeckFile(String storagePath);
}

/// Сервер не настроен (нет `SUPABASE_URL` и ключа): приложение работает без
/// бэкенда, каталог выглядит как «нет сети».
final class UnavailableDeckRemoteSource implements DeckRemoteSource {
  const UnavailableDeckRemoteSource();

  static const _error = NetworkError('Supabase не настроен');

  @override
  Future<List<RemoteDeck>> fetchDecks() => Future.error(_error);

  @override
  Future<RemoteDeck?> fetchDeck(String deckId) => Future.error(_error);

  @override
  Future<Uint8List> downloadDeckFile(String storagePath) =>
      Future.error(_error);
}
