import '../../session/domain/local_day.dart';
import '../../session/domain/session_repository.dart';
import 'notification_scheduler.dart';
import 'reminder_planner.dart';
import 'reminder_texts.dart';

/// Чем закончилось перепланирование.
enum ReminderStatus {
  /// Ещё не считали.
  idle,

  /// Платформа не умеет напоминания (web, не Android).
  unsupported,

  /// Пользователь выключил напоминания; всё отменено.
  disabled,

  /// Включено, но система не разрешает уведомления; всё отменено, тихо.
  permissionDenied,

  /// Расписание поставлено (возможно, пустое: ничего не пора повторять).
  scheduled,

  /// Платформа отказала; пользователю не показываем, напоминаний нет до
  /// следующей попытки (старт, возврат в приложение, конец сессии).
  failed,
}

/// Итог [ReminderService.reschedule].
class ReminderResult {
  const ReminderResult(this.status, {this.scheduled = const []});

  final ReminderStatus status;

  /// Моменты (UTC), на которые поставлены напоминания.
  final List<DateTime> scheduled;
}

/// Перепланирует напоминания (ТЗ M9, T19, ADR-29): на каждый из ближайших 7
/// дней ставит уведомление в выбранное время, если к этому моменту есть
/// знание с `due <= момент` по текущему `user_item_state`. Если повторять
/// нечего, день пропускается; сессия двигает `due`, поэтому после неё
/// сегодняшнее напоминание исчезает само.
///
/// Чистый Dart: время, пояс и хранилище приходят снаружи.
class ReminderService {
  ReminderService({
    required this.scheduler,
    required this.repository,
    required this.offsetAt,
  });

  final NotificationScheduler scheduler;
  final SessionRepository repository;
  final UtcOffsetAt offsetAt;

  Future<ReminderResult> reschedule({
    required bool enabled,
    required int minuteOfDay,
    required DateTime now,
    required ReminderTexts texts,
  }) async {
    if (!scheduler.isSupported) {
      return const ReminderResult(ReminderStatus.unsupported);
    }
    await scheduler.initialize();
    if (!enabled) {
      await scheduler.replaceReminders(const [], texts);
      return const ReminderResult(ReminderStatus.disabled);
    }
    if (await scheduler.permission() != NotificationPermission.granted) {
      await scheduler.replaceReminders(const [], texts);
      return const ReminderResult(ReminderStatus.permissionDenied);
    }

    final candidates = ReminderPlanner.candidates(
      now: now,
      minuteOfDay: minuteOfDay,
      offsetAt: offsetAt,
    );
    var chosen = const <DateTime>[];
    if (candidates.isNotEmpty) {
      // Состояния отсортированы по `due`: первое — самое раннее. День
      // подходит, если самое раннее `due` не позже момента напоминания.
      final due = await repository.dueStates(now: candidates.last);
      if (due.isNotEmpty) {
        final earliest = due.first.due;
        chosen = [
          for (final at in candidates)
            if (!earliest.isAfter(at)) at,
        ];
      }
    }
    await scheduler.replaceReminders(chosen, texts);
    return ReminderResult(ReminderStatus.scheduled, scheduled: chosen);
  }
}
