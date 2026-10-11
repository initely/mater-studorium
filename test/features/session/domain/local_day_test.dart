import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/session/domain/local_day.dart';

import '../../../helpers/time_zones.dart';

DateTime utc(int m, int d, [int h = 0, int min = 0, int s = 0]) =>
    DateTime.utc(2026, m, d, h, min, s);

void expectDay(LocalDay day, DateTime start, DateTime end) {
  expect(day.start, start, reason: 'начало суток');
  expect(day.end, end, reason: 'конец суток');
}

void main() {
  group('фиксированные пояса', () {
    test('UTC: сутки совпадают с календарными', () {
      expectDay(
        LocalDay.containing(utc(10, 11, 12), fixedOffset(Duration.zero)),
        utc(10, 11),
        utc(10, 12),
      );
    });

    test('UTC+14: локальная дата уже следующая', () {
      expectDay(
        LocalDay.containing(utc(10, 11, 12), fixedOffset(hm(14))),
        utc(10, 11, 10),
        utc(10, 12, 10),
      );
    });

    test('UTC-12: локальная дата ещё предыдущая', () {
      expectDay(
        LocalDay.containing(utc(10, 11, 5), fixedOffset(hm(-12))),
        utc(10, 10, 12),
        utc(10, 11, 12),
      );
    });

    test('UTC+5:30: момент ровно на границе — уже новые сутки', () {
      final zone = fixedOffset(hm(5, 30));
      expectDay(
        LocalDay.containing(utc(10, 11, 18, 30), zone),
        utc(10, 11, 18, 30),
        utc(10, 12, 18, 30),
      );
      expectDay(
        LocalDay.containing(
          utc(10, 11, 18, 30).subtract(const Duration(microseconds: 1)),
          zone,
        ),
        utc(10, 10, 18, 30),
        utc(10, 11, 18, 30),
      );
    });

    test('момент в локальной зоне платформы приводится к UTC', () {
      final instant = DateTime.fromMillisecondsSinceEpoch(
        utc(10, 11, 12).millisecondsSinceEpoch,
      );
      expectDay(
        LocalDay.containing(instant, fixedOffset(hm(3))),
        utc(10, 10, 21),
        utc(10, 11, 21),
      );
    });
  });

  group('переход на летнее время', () {
    test('Нью-Йорк, 8 марта: сутки 23 часа, утром и вечером одни и те же', () {
      final start = utc(3, 8, 5); // 00:00 EST
      final end = utc(3, 9, 4); // 00:00 EDT
      for (final instant in [
        utc(3, 8, 5), // 00:00 EST
        utc(3, 8, 6, 59, 59), // 01:59:59 EST, за секунду до перевода
        utc(3, 8, 7), // 03:00 EDT, сразу после перевода
        utc(3, 8, 12),
        utc(3, 9, 3, 59, 59), // 23:59:59 EDT
      ]) {
        expectDay(LocalDay.containing(instant, newYork), start, end);
      }
      expect(end.difference(start), const Duration(hours: 23));
    });

    test('Нью-Йорк, 1 ноября: сутки 25 часов', () {
      final start = utc(11, 1, 4); // 00:00 EDT
      final end = utc(11, 2, 5); // 00:00 EST
      for (final instant in [
        utc(11, 1, 4),
        utc(11, 1, 5, 30), // 01:30 EDT
        utc(11, 1, 6, 30), // повторное 01:30, уже EST
        utc(11, 2, 4, 59, 59), // 23:59:59 EST
      ]) {
        expectDay(LocalDay.containing(instant, newYork), start, end);
      }
      expect(end.difference(start), const Duration(hours: 25));
    });

    test('Нью-Йорк: соседние сутки не пересекаются с переходными', () {
      // 31 октября и 2 ноября заканчиваются/начинаются на тех же границах.
      expectDay(
        LocalDay.containing(utc(11, 1, 3, 59, 59), newYork),
        utc(10, 31, 4),
        utc(11, 1, 4),
      );
      expectDay(
        LocalDay.containing(utc(11, 2, 5), newYork),
        utc(11, 2, 5),
        utc(11, 3, 5),
      );
    });

    test('Лондон: 29 марта 23 часа, 25 октября 25 часов', () {
      expectDay(
        LocalDay.containing(utc(3, 29, 12), london),
        utc(3, 29),
        utc(3, 29, 23),
      );
      expectDay(
        LocalDay.containing(utc(10, 25, 12), london),
        utc(10, 24, 23),
        utc(10, 26),
      );
    });

    test('сдвиг на 30 минут (Лорд-Хау): сутки 23,5 часа', () {
      expectDay(
        LocalDay.containing(utc(10, 4), lordHowe),
        utc(10, 3, 13, 30),
        utc(10, 4, 13),
      );
    });

    test('пропущенная полночь (Сан-Паулу, 2018): сутки начинает переход', () {
      expectDay(
        LocalDay.containing(
          DateTime.utc(2018, 11, 4, 12),
          saoPauloSkippedMidnight,
        ),
        DateTime.utc(2018, 11, 4, 3),
        DateTime.utc(2018, 11, 5, 2),
      );
      // За секунду до перевода ещё 3 ноября.
      expectDay(
        LocalDay.containing(
          DateTime.utc(2018, 11, 4, 2, 59, 59),
          saoPauloSkippedMidnight,
        ),
        DateTime.utc(2018, 11, 3, 3),
        DateTime.utc(2018, 11, 4, 3),
      );
    });

    test('повторяющаяся полночь: сутки начинает первый проход', () {
      final start = utc(11, 1, 4); // 00:00 при -4
      final end = utc(11, 2, 5); // 00:00 при -5
      for (final instant in [
        utc(11, 1, 4, 30), // 00:30, первый проход
        utc(11, 1, 5, 30), // 00:30, второй проход той же даты
        utc(11, 1, 12),
      ]) {
        expectDay(LocalDay.containing(instant, repeatedMidnight), start, end);
      }
      // День до: заканчивается на первом проходе полуночи.
      expectDay(
        LocalDay.containing(utc(10, 31, 12), repeatedMidnight),
        utc(10, 31, 4),
        utc(11, 1, 4),
      );
    });
  });

  test('сутки покрывают время без дыр и пересечений (весь 2026 год)', () {
    final zones = {
      'UTC': fixedOffset(Duration.zero),
      'Нью-Йорк': newYork,
      'Лондон': london,
      'Лорд-Хау': lordHowe,
      'повторяющаяся полночь': repeatedMidnight,
    };
    const tick = Duration(microseconds: 1);
    for (final MapEntry(key: name, value: zone) in zones.entries) {
      var instant = utc(1, 1);
      while (instant.isBefore(utc(12, 31))) {
        final day = LocalDay.containing(instant, zone);
        final reason = '$name, $instant';
        expect(instant.isBefore(day.start), isFalse, reason: reason);
        expect(instant.isBefore(day.end), isTrue, reason: reason);
        final next = LocalDay.containing(day.end, zone);
        expect(next.start, day.end, reason: reason);
        final previous = LocalDay.containing(day.start.subtract(tick), zone);
        expect(previous.end, day.start, reason: reason);
        instant = instant.add(const Duration(minutes: 90));
      }
    }
  });
}
