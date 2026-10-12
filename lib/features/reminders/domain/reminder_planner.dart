import '../../session/domain/local_day.dart';
import 'notification_scheduler.dart';

/// Когда ставить ежедневное напоминание: чистая функция времени (ADR-29).
///
/// Все моменты в UTC; пояс приходит как [UtcOffsetAt] (пояс устройства,
/// DST учтён: смещение берётся для каждого будущего момента отдельно),
/// поэтому результат одинаков на любом устройстве при тех же входах.
class ReminderPlanner {
  const ReminderPlanner._();

  /// До [days] ближайших моментов «[minuteOfDay] по местному времени»,
  /// строго после [now], по возрастанию. Сегодняшний включается, только
  /// если время ещё не прошло.
  static List<DateTime> candidates({
    required DateTime now,
    required int minuteOfDay,
    required UtcOffsetAt offsetAt,
    int days = kReminderDays,
  }) {
    assert(
      minuteOfDay >= 0 && minuteOfDay < 24 * 60,
      'minuteOfDay вне суток: $minuteOfDay',
    );
    final utcNow = now.toUtc();
    final local = utcNow.add(offsetAt(utcNow));
    final result = <DateTime>[];
    // Запас в два дня: сегодняшнее время могло пройти.
    for (var i = 0; result.length < days && i < days + 2; i++) {
      final wall = DateTime.utc(
        local.year,
        local.month,
        local.day + i,
        minuteOfDay ~/ 60,
        minuteOfDay % 60,
      );
      final instant = localToUtc(wall, offsetAt);
      if (instant.isAfter(utcNow)) result.add(instant);
    }
    return result;
  }

  /// Момент UTC, когда на часах пользователя [wall] (местное время, записанное
  /// как UTC-дата). Переход на летнее время:
  /// - время пропущено (например 02:30 при переводе вперёд) — берётся
  ///   момент со сдвигом вперёд (03:30), как делает Android;
  /// - время повторяется (при переводе назад) — первое вхождение.
  static DateTime localToUtc(DateTime wall, UtcOffsetAt offsetAt) {
    const day = Duration(days: 1);
    final offsets = {
      offsetAt(wall.subtract(day)),
      offsetAt(wall),
      offsetAt(wall.add(day)),
    };
    final instants = [for (final o in offsets) wall.subtract(o)];
    final valid = [
      for (final u in instants)
        if (u.add(offsetAt(u)) == wall) u,
    ]..sort();
    if (valid.isNotEmpty) return valid.first;
    // Пропущенное время: самый поздний кандидат (смещение до перехода).
    return (instants..sort()).last;
  }
}
