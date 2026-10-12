// Когда ставить напоминание (T19, ADR-29): сегодня или уже завтра, 7 дней,
// смена суток в поясе, переходы на летнее время. Часы и пояса фиксированные.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/reminders/domain/reminder_planner.dart';

import '../../../helpers/time_zones.dart';

const _evening = 20 * 60;

List<DateTime> plan(
  DateTime now,
  int minuteOfDay,
  Duration Function(DateTime) offsetAt, {
  int days = 7,
}) => ReminderPlanner.candidates(
  now: now,
  minuteOfDay: minuteOfDay,
  offsetAt: offsetAt,
  days: days,
);

void main() {
  group('сегодня или завтра', () {
    test('время ещё не прошло: первое напоминание сегодня', () {
      final at = plan(
        DateTime.utc(2026, 10, 12, 10), // 13:00 в +03:00
        _evening,
        fixedOffset(hm(3)),
      );
      expect(at.first, DateTime.utc(2026, 10, 12, 17));
      expect(at, hasLength(7));
      expect(at.last, DateTime.utc(2026, 10, 18, 17));
    });

    test('время уже прошло: с завтрашнего дня, всё равно 7 штук', () {
      final at = plan(
        DateTime.utc(2026, 10, 12, 18), // 21:00 в +03:00
        _evening,
        fixedOffset(hm(3)),
      );
      expect(at.first, DateTime.utc(2026, 10, 13, 17));
      expect(at, hasLength(7));
    });

    test('ровно в момент напоминания: сегодняшнее не ставится', () {
      final at = plan(
        DateTime.utc(2026, 10, 12, 17),
        _evening,
        fixedOffset(hm(3)),
      );
      expect(at.first, DateTime.utc(2026, 10, 13, 17));
    });

    test('за секунду до момента: сегодняшнее ещё ставится', () {
      final at = plan(
        DateTime.utc(2026, 10, 12, 16, 59, 59),
        _evening,
        fixedOffset(hm(3)),
      );
      expect(at.first, DateTime.utc(2026, 10, 12, 17));
    });

    test('смена времени двигает все моменты', () {
      final now = DateTime.utc(2026, 10, 12, 10);
      final a = plan(now, _evening, fixedOffset(hm(3)));
      final b = plan(now, 9 * 60 + 30, fixedOffset(hm(3)));
      // 09:30 сегодня уже прошло (13:00 местного): с завтра.
      expect(b.first, DateTime.utc(2026, 10, 13, 6, 30));
      expect(b, isNot(a));
      expect(b, hasLength(7));
    });

    test('результат по возрастанию и строго после now', () {
      final now = DateTime.utc(2026, 3, 6, 15);
      final at = plan(now, 2 * 60 + 30, newYork);
      expect(at.every((t) => t.isAfter(now)), isTrue);
      for (var i = 1; i < at.length; i++) {
        expect(at[i].isAfter(at[i - 1]), isTrue);
      }
    });
  });

  group('дата определяется по поясу пользователя, не по UTC', () {
    test('в UTC ещё 12-е, у пользователя уже 13-е', () {
      // 23:30Z 12 октября = 04:30 13 октября в +05:00.
      final at = plan(
        DateTime.utc(2026, 10, 12, 23, 30),
        _evening,
        fixedOffset(hm(5)),
      );
      expect(at.first, DateTime.utc(2026, 10, 13, 15)); // 20:00 13-го
    });

    test('в UTC уже 13-е, у пользователя ещё 12-е', () {
      // 03:00Z 13 октября = 19:00 12 октября в -08:00.
      final at = plan(
        DateTime.utc(2026, 10, 13, 3),
        _evening,
        fixedOffset(hm(-8)),
      );
      expect(at.first, DateTime.utc(2026, 10, 13, 4)); // 20:00 12-го
    });

    test('другой пояс: те же часы стены, другие моменты UTC', () {
      final now = DateTime.utc(2026, 10, 12, 10);
      final moscow = plan(now, _evening, fixedOffset(hm(3)));
      final tokyo = plan(now, _evening, fixedOffset(hm(9)));
      expect(moscow.first, DateTime.utc(2026, 10, 12, 17));
      expect(tokyo.first, DateTime.utc(2026, 10, 12, 11));
    });
  });

  group('переход на летнее время (Нью-Йорк, 8 марта 2026)', () {
    test('20:00 всю неделю по местным часам: смещение меняется на лету', () {
      final at = plan(DateTime.utc(2026, 3, 6, 15), _evening, newYork);
      expect(at.take(4).toList(), [
        DateTime.utc(2026, 3, 7, 1), // 6 марта 20:00 EST
        DateTime.utc(2026, 3, 8, 1), // 7 марта 20:00 EST
        DateTime.utc(2026, 3, 9, 0), // 8 марта 20:00 EDT
        DateTime.utc(2026, 3, 10, 0), // 9 марта 20:00 EDT
      ]);
    });

    test('02:30 в день перевода вперёд: время пропущено, будет 03:30', () {
      final at = plan(DateTime.utc(2026, 3, 6, 15), 2 * 60 + 30, newYork);
      expect(at.take(3).toList(), [
        DateTime.utc(2026, 3, 7, 7, 30), // 02:30 EST
        DateTime.utc(2026, 3, 8, 7, 30), // 02:30 не было -> 03:30 EDT
        DateTime.utc(2026, 3, 9, 6, 30), // 02:30 EDT
      ]);
    });

    test('01:30 при переводе назад: берётся первое вхождение', () {
      final at = plan(DateTime.utc(2026, 10, 30, 12), 90, newYork);
      expect(at.take(3).toList(), [
        DateTime.utc(2026, 10, 31, 5, 30), // 01:30 EDT
        DateTime.utc(2026, 11, 1, 5, 30), // 01:30 EDT (первое)
        DateTime.utc(2026, 11, 2, 6, 30), // 01:30 EST
      ]);
    });

    test('Лондон: 25 октября 20:00 уже по зимнему времени', () {
      final at = plan(DateTime.utc(2026, 10, 24, 12), _evening, london);
      expect(at.take(2).toList(), [
        DateTime.utc(2026, 10, 24, 19), // BST
        DateTime.utc(2026, 10, 25, 20), // GMT
      ]);
    });
  });

  group('необычные пояса', () {
    test('Лорд-Хау: пропущенные 30 минут сдвигают время на 02:45', () {
      final at = plan(DateTime.utc(2026, 10, 2), 2 * 60 + 15, lordHowe);
      expect(at.take(3).toList(), [
        DateTime.utc(2026, 10, 2, 15, 45), // 3 окт. 02:15 (+10:30)
        DateTime.utc(2026, 10, 3, 15, 45), // 4 окт. 02:15 нет -> 02:45 (+11)
        DateTime.utc(2026, 10, 4, 15, 15), // 5 окт. 02:15 (+11)
      ]);
    });

    test('Сан-Паулу 2018: полуночи 4 ноября не было, будет 01:00', () {
      final at = plan(
        DateTime.utc(2018, 11, 3, 12),
        0,
        saoPauloSkippedMidnight,
      );
      expect(at.take(2).toList(), [
        DateTime.utc(2018, 11, 4, 3), // 00:00 4 ноября нет -> 01:00 (-02:00)
        DateTime.utc(2018, 11, 5, 2), // 00:00 5 ноября (-02:00)
      ]);
    });
  });

  test('days ограничивает число напоминаний', () {
    expect(
      plan(
        DateTime.utc(2026, 10, 12),
        _evening,
        fixedOffset(Duration.zero),
        days: 3,
      ),
      hasLength(3),
    );
  });
}
