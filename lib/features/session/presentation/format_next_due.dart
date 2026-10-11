import '../../../core/l10n/app_localizations.dart';

/// «Через 25 мин», «через 3 ч», «через 2 дн.» для времени до следующего
/// повторения (ТЗ §8.2, §8.5). Округление до ближайшей единицы; всё, что
/// меньше минуты, — «меньше чем через минуту».
String formatNextDue(AppLocalizations l10n, Duration until) {
  if (until < const Duration(minutes: 1)) return l10n.durationLessThanMinute;
  if (until < const Duration(minutes: 60)) {
    return l10n.durationMinutes(until.inMinutes);
  }
  if (until < const Duration(hours: 48)) {
    return l10n.durationHours((until.inMinutes / 60).round());
  }
  return l10n.durationDays((until.inHours / 24).round());
}
