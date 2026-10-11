import 'session_item.dart';

/// Почему очередь пуста (ТЗ AC3.3, §8.5).
enum EmptyQueueReason {
  /// Нет ни скачанных знаний, ни расписания: колоды не скачаны (или в них
  /// всё `retired` / скрыто).
  noContent,

  /// Всё повторено, новых знаний нет совсем. Есть `nextDue`.
  allDone,

  /// Повторять нечего, новые есть, но дневной лимит исчерпан: кнопка
  /// «Взять новые».
  newLimitReached,
}

/// Результат построителя очереди. Пустая очередь — обычный результат, а не
/// исключение.
class SessionQueue {
  const SessionQueue({
    required this.items,
    required this.dueCount,
    required this.newCount,
    required this.nextDue,
    required this.moreNewAvailable,
  });

  /// В порядке показа: сначала просроченные по возрастанию `due`, затем новые.
  final List<SessionItem> items;

  /// Сколько из [items] — повторения.
  final int dueCount;

  /// Сколько из [items] — новые знания.
  final int newCount;

  /// Ближайшее повторение после «сейчас» (то, что в очередь не попало), либо
  /// `null`, если будущих повторений нет. Для «следующее — через 3 ч».
  final DateTime? nextDue;

  /// Остались новые знания, не попавшие в очередь (лимит дня или размер
  /// сессии). Для кнопки «Взять новые».
  final bool moreNewAvailable;

  bool get isEmpty => items.isEmpty;

  /// `null`, если очередь не пуста.
  EmptyQueueReason? get emptyReason {
    if (items.isNotEmpty) return null;
    if (moreNewAvailable) return EmptyQueueReason.newLimitReached;
    if (nextDue == null) return EmptyQueueReason.noContent;
    return EmptyQueueReason.allDone;
  }
}
