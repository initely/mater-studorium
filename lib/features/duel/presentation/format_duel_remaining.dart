import '../../../core/l10n/app_localizations.dart';

/// «осталось 2 д», «осталось 5 ч», «осталось 12 мин» (ТЗ §8.4: «осталось
/// 2 д»). Округление вниз до крупной единицы: два дня и 20 часов — «2 д».
String formatDuelRemaining(AppLocalizations l10n, Duration left) {
  final String text;
  if (left >= const Duration(days: 1)) {
    text = l10n.duelLeftDays(left.inDays);
  } else if (left >= const Duration(hours: 1)) {
    text = l10n.duelLeftHours(left.inHours);
  } else if (left >= const Duration(minutes: 1)) {
    text = l10n.duelLeftMinutes(left.inMinutes);
  } else {
    text = l10n.duelLeftLessThanMinute;
  }
  return l10n.duelRemaining(text);
}
