import 'deck_details.dart';

/// Экран колоды: описание, прогресс и удаление скачанной колоды. Реализация
/// в `data/`. Ошибки хранилища — `LocalStorageError`.
abstract interface class DeckRepository {
  /// Колода с прогрессом; `null`, если колоды нет на устройстве (в том числе
  /// после удаления). Поток обновляется при каждом ответе в сессии и при
  /// обновлении колоды.
  Stream<DeckDetails?> watch(String deckId);

  /// Удаляет колоду с устройства. Прогресс по знаниям остаётся (ADR-26).
  Future<void> delete(String deckId);
}
