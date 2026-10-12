import 'session_repository.dart';

/// Окно «ближайших» повторений на экране итогов.
const Duration kUpcomingHorizon = Duration(hours: 24);

/// Сколько знаний перечислять поимённо.
const int kUpcomingListSize = 3;

/// Знание, которое скоро пора повторить.
class UpcomingItem {
  const UpcomingItem({required this.title, required this.due});

  final String title;
  final DateTime due;
}

/// Что повторить скоро (ТЗ §8.2, п. 5): ближайшие по `due` знания и общее
/// их число в окне [kUpcomingHorizon]. Только то, что уже в локальной БД.
class UpcomingReviews {
  const UpcomingReviews({
    required this.items,
    required this.total,
    required this.nextDue,
  });

  const UpcomingReviews.none() : items = const [], total = 0, nextDue = null;

  /// Первые [kUpcomingListSize] знаний по возрастанию `due`.
  final List<UpcomingItem> items;

  /// Сколько знаний с `due` в пределах окна (включая уже просроченные).
  final int total;

  /// Ближайшее повторение, если в окне пусто, а дальше что-то запланировано.
  final DateTime? nextDue;

  bool get isEmpty => items.isEmpty && nextDue == null;

  /// Сколько знаний не поместилось в [items].
  int get more => total - items.length;

  /// Читает ближайшие повторения [repository] на момент [now]. Просроченные,
  /// не попавшие в сессию, идут первыми: их `due` уже наступил.
  static Future<UpcomingReviews> load(
    SessionRepository repository, {
    required DateTime now,
    Set<String>? deckIds,
  }) async {
    final states = await repository.dueStates(
      now: now.add(kUpcomingHorizon),
      deckIds: deckIds,
    );
    if (states.isEmpty) {
      final next = await repository.nextDue(
        after: now.add(kUpcomingHorizon),
        deckIds: deckIds,
      );
      return UpcomingReviews(items: const [], total: 0, nextDue: next);
    }
    final head = states.take(kUpcomingListSize).toList();
    final content = await repository.contentFor({
      for (final s in head) s.itemId,
    });
    return UpcomingReviews(
      items: [
        for (final s in head)
          // Знание без видимых вопросов `contentFor` не отдаёт: в списке его
          // нет, но в общем числе оно учтено `dueStates`.
          if (content[s.itemId] case final c?)
            UpcomingItem(title: c.item.title, due: s.due),
      ],
      total: states.length,
      nextDue: null,
    );
  }
}
