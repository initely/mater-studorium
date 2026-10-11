import 'local_deck.dart';
import 'remote_deck.dart';

/// Каталог колод: список с сервера, скачивание и обновление (ТЗ M2).
/// Реализация в `data/`; о сервере и локальной БД `domain/` ничего не знает.
///
/// Методы бросают только типизированные ошибки из `core/errors/`:
/// `NetworkError` (нет сети, можно повторить), `AuthError`, `DeckNotFoundError`,
/// `DeckFormatError` и `DeckSchemaTooNewError` (файл колоды отклонён, прежняя
/// версия не тронута), `ItemIdCollisionError` (ADR-21), `UnexpectedError`.
abstract interface class CatalogRepository {
  /// Колоды, доступные пользователю на сервере (public и свои).
  Future<List<RemoteDeck>> list();

  /// Скачанные колоды; поток обновляется после каждой записи в локальную БД.
  Stream<List<LocalDeck>> watchDownloaded();

  /// Скачивает колоду, проверяет файл и записывает в локальную БД одной
  /// транзакцией (новая колода или обновление версии: знания, исчезнувшие из
  /// новой версии, получают `retired`, прогресс не трогается). Если локальная
  /// версия не ниже серверной, ничего не делает. Возвращает локальную колоду.
  Future<LocalDeck> download(String deckId);
}
