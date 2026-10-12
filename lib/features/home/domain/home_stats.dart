import '../../session/domain/session_queue.dart';
import '../../session/domain/session_queue_builder.dart';
import '../../session/domain/session_repository.dart';
import '../../session/domain/session_settings.dart';

/// Что показывает главный экран (ТЗ §8.2, п. 1): «12 к повторению, 5 новых».
/// Серия дней (streak) не считается: её нет в ТЗ.
class HomeStats {
  const HomeStats({
    required this.dueCount,
    required this.newCount,
    required this.queueLength,
    required this.moreNewAvailable,
    required this.nextDue,
  });

  /// Знаний с `due <= now`: все, а не только вошедшие в одну сессию.
  final int dueCount;

  /// Новых знаний в ближайшей сессии: остаток дневного лимита (`newPerDay`
  /// минус знания, впервые показанные за локальные сутки), не больше числа
  /// непоказанных знаний с поддерживаемым форматом вопроса и не больше места
  /// в сессии после повторений.
  final int newCount;

  /// Сколько вопросов в очереди, если начать сессию сейчас.
  final int queueLength;

  /// Повторять нечего, новые знания остались, но дневной лимит исчерпан:
  /// «Взять новые» (ТЗ §8.5).
  final bool moreNewAvailable;

  /// Ближайшее повторение после «сейчас» либо `null`, если будущих нет.
  final DateTime? nextDue;

  /// Сессия сейчас не пуста.
  bool get hasWork => queueLength > 0;
}

/// Считает [HomeStats] той же очередью, что и сессия ([SessionQueueBuilder],
/// ADR-24), поэтому счётчики совпадают с тем, что покажет сессия (форматы без
/// модуля, скрытые вопросы и `retired` учтены). Единственное отличие:
/// [HomeStats.dueCount] — число всех наступивших повторений, без потолка
/// размера сессии.
class HomeStatsCalculator {
  const HomeStatsCalculator({required this.repository, required this.builder});

  final SessionRepository repository;
  final SessionQueueBuilder builder;

  Future<HomeStats> compute({
    required DateTime now,
    required SessionSettings settings,
  }) async {
    final utcNow = now.toUtc();
    final queue = await builder.build(now: utcNow, settings: settings);
    final due = await repository.dueStates(
      now: utcNow,
      deckIds: settings.deckIds,
    );
    return HomeStats(
      dueCount: due.length,
      newCount: queue.newCount,
      queueLength: queue.items.length,
      moreNewAvailable: queue.emptyReason == EmptyQueueReason.newLimitReached,
      nextDue: queue.nextDue,
    );
  }
}
