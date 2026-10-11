/// Новых знаний в день по умолчанию (ТЗ M3).
const int kDefaultNewPerDay = 10;

/// Сколько знаний максимум попадает в очередь одной сессии. Сессия идёт
/// 5 минут (ТЗ M3, §8.2: «повторено 14»), поэтому 30 — запас с головой, а не
/// цель: заканчивает сессию таймер (ADR-24).
const int kDefaultSessionSize = 30;

/// Настройки построителя очереди.
class SessionSettings {
  const SessionSettings({
    this.sessionSize = kDefaultSessionSize,
    this.newPerDay = kDefaultNewPerDay,
    this.deckIds,
  }) : assert(sessionSize > 0, 'sessionSize должен быть положительным'),
       assert(newPerDay >= 0, 'newPerDay не может быть отрицательным');

  /// Максимальная длина очереди (due + новые).
  final int sessionSize;

  /// Дневной лимит новых знаний.
  final int newPerDay;

  /// Колоды, из которых берём знания; `null` — все скачанные.
  final Set<String>? deckIds;
}
