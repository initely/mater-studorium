import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/l10n/app_localizations_ru.dart';
import 'package:mater_studorium/features/session/presentation/format_next_due.dart';

void main() {
  final l10n = AppLocalizationsRu();
  String fmt(Duration d) => formatNextDue(l10n, d);

  test('меньше минуты', () {
    expect(fmt(Duration.zero), 'меньше чем через минуту');
    expect(fmt(const Duration(seconds: 59)), 'меньше чем через минуту');
    expect(fmt(const Duration(seconds: -5)), 'меньше чем через минуту');
  });

  test('минуты до часа', () {
    expect(fmt(const Duration(minutes: 1)), 'через 1 мин');
    expect(fmt(const Duration(minutes: 25, seconds: 40)), 'через 25 мин');
    expect(fmt(const Duration(minutes: 59, seconds: 59)), 'через 59 мин');
  });

  test('часы до двух суток, округление до ближайшего', () {
    expect(fmt(const Duration(minutes: 60)), 'через 1 ч');
    expect(fmt(const Duration(hours: 3)), 'через 3 ч');
    expect(fmt(const Duration(hours: 2, minutes: 40)), 'через 3 ч');
    expect(fmt(const Duration(hours: 47, minutes: 20)), 'через 47 ч');
  });

  test('дни, от двух суток', () {
    expect(fmt(const Duration(hours: 48)), 'через 2 дн.');
    expect(fmt(const Duration(days: 9, hours: 5)), 'через 9 дн.');
  });
}
