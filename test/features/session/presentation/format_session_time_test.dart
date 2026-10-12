import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/l10n/app_localizations_ru.dart';
import 'package:mater_studorium/features/session/presentation/format_session_time.dart';

void main() {
  final l10n = AppLocalizationsRu();
  String fmt(Duration d) => formatSessionTime(l10n, d);

  test('секунды', () {
    expect(fmt(Duration.zero), '0 с');
    expect(fmt(const Duration(seconds: 45)), '45 с');
    expect(fmt(const Duration(milliseconds: 59999)), '59 с');
  });

  test('целые минуты', () {
    expect(fmt(const Duration(minutes: 1)), '1 мин');
    expect(fmt(const Duration(minutes: 5)), '5 мин');
  });

  test('минуты и секунды', () {
    expect(fmt(const Duration(minutes: 3, seconds: 20)), '3 мин 20 с');
    expect(fmt(const Duration(minutes: 4, milliseconds: 59900)), '4 мин 59 с');
  });

  test('отрицательное значение — ноль', () {
    expect(fmt(const Duration(seconds: -4)), '0 с');
  });
}
