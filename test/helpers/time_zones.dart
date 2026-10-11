import 'package:mater_studorium/features/session/domain/local_day.dart';

/// Пояс с фиксированным смещением.
UtcOffsetAt fixedOffset(Duration offset) =>
    (utc) => offset;

/// Пояс с историей: смещение [initial] до первого перехода, дальше — смещение
/// последнего перехода, который уже наступил. [transitions] — моменты в UTC по
/// возрастанию и смещения, которые действуют с них.
UtcOffsetAt zoneWithTransitions(
  Duration initial,
  List<(DateTime, Duration)> transitions,
) => (utc) {
  var offset = initial;
  for (final (at, newOffset) in transitions) {
    if (!utc.isBefore(at)) offset = newOffset;
  }
  return offset;
};

Duration hm(int hours, [int minutes = 0]) =>
    Duration(hours: hours, minutes: hours < 0 ? -minutes : minutes);

/// America/New_York 2026: DST с 8 марта 02:00 (07:00Z), конец 1 ноября 02:00
/// (06:00Z). Сутки 8 марта — 23 часа, 1 ноября — 25.
final newYork = zoneWithTransitions(hm(-5), [
  (DateTime.utc(2026, 3, 8, 7), hm(-4)),
  (DateTime.utc(2026, 11, 1, 6), hm(-5)),
]);

/// Europe/London 2026: BST с 29 марта 01:00Z до 25 октября 01:00Z.
final london = zoneWithTransitions(hm(0), [
  (DateTime.utc(2026, 3, 29, 1), hm(1)),
  (DateTime.utc(2026, 10, 25, 1), hm(0)),
]);

/// America/Sao_Paulo 4 ноября 2018: в полночь часы переведены на час вперёд
/// (00:00 -> 01:00, 03:00Z), локальной полуночи в этот день не было.
final saoPauloSkippedMidnight = zoneWithTransitions(hm(-3), [
  (DateTime.utc(2018, 11, 4, 3), hm(-2)),
]);

/// Пояс, где полночь повторяется: 1 ноября 2026 в 01:00 (05:00Z) часы
/// переводятся на 00:00 (как на Кубе).
final repeatedMidnight = zoneWithTransitions(hm(-4), [
  (DateTime.utc(2026, 11, 1, 5), hm(-5)),
]);

/// Australia/Lord_Howe 2026: сдвиг на 30 минут, +10:30 -> +11:00
/// 4 октября в 02:00 (15:30Z 3 октября).
final lordHowe = zoneWithTransitions(hm(10, 30), [
  (DateTime.utc(2026, 10, 3, 15, 30), hm(11)),
]);
