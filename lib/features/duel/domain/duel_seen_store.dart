/// Какие результаты дуэлей пользователь уже открывал на этом устройстве:
/// карточка «посмотри результат» на главном висит, пока результат не открыт.
abstract interface class DuelSeenStore {
  /// Id дуэлей, результат которых уже открыт.
  Future<Set<String>> seenResults();

  /// Помечает результат дуэли [duelId] открытым.
  Future<void> markResultSeen(String duelId);
}
