/// Смещение часового пояса пользователя от UTC в заданный момент (с учётом
/// перехода на летнее время). Чистая функция времени: именно она задаёт
/// границы «сегодня» (ADR-24).
typedef UtcOffsetAt = Duration Function(DateTime utc);

/// Локальные сутки пользователя как промежуток `[start, end)` в UTC.
/// На переходе на летнее время сутки длятся 23 или 25 часов (бывают и
/// другие длины: сдвиг на 30 минут, пропущенная или повторяющаяся полночь).
/// Даты, которых в поясе не было вовсе (Самоа, 30.12.2011), не поддерживаются.
class LocalDay {
  const LocalDay({required this.start, required this.end});

  /// Локальные сутки, в которые попадает момент [instant].
  factory LocalDay.containing(DateTime instant, UtcOffsetAt offsetAt) {
    final utc = instant.toUtc();
    final local = utc.add(offsetAt(utc));
    // «Настенная» дата как полночь в UTC: сравнивать удобнее, чем компоненты.
    final date = DateTime.utc(local.year, local.month, local.day);
    return LocalDay(
      start: _startOf(date, offsetAt),
      end: _startOf(
        DateTime.utc(date.year, date.month, date.day + 1),
        offsetAt,
      ),
    );
  }

  final DateTime start;
  final DateTime end;

  /// Первый момент (UTC), когда локальная дата становится [date] (полночь
  /// даты, записанная в UTC). Кандидаты — полночь минус каждое из смещений,
  /// действующих вокруг даты; подходит тот, в котором дата уже [date], а за
  /// микросекунду до него ещё нет. Это верно и когда полночь пропущена
  /// (начало суток — момент перехода), и когда повторяется (начало суток —
  /// первое попадание в дату).
  static DateTime _startOf(DateTime date, UtcOffsetAt offsetAt) {
    const day = Duration(days: 1);
    const tick = Duration(microseconds: 1);
    final next = DateTime.utc(date.year, date.month, date.day + 1);
    bool isIn(DateTime utc) {
      final local = utc.add(offsetAt(utc));
      return !local.isBefore(date) && local.isBefore(next);
    }

    final offsets = {
      offsetAt(date.subtract(day)),
      offsetAt(date),
      offsetAt(date.add(day)),
    };
    final starts = [
      for (final offset in offsets)
        if (isIn(date.subtract(offset)) &&
            !isIn(date.subtract(offset).subtract(tick)))
          date.subtract(offset),
    ];
    return (starts..sort()).first;
  }
}
