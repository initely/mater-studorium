import '../../../core/l10n/app_localizations.dart';

/// Длительность сессии на итогах: «45 с», «3 мин», «3 мин 20 с». Секунды
/// отбрасываются вниз (3 мин 59,9 с — это «3 мин 59 с»); отрицательное
/// значение — «0 с».
String formatSessionTime(AppLocalizations l10n, Duration elapsed) {
  final total = elapsed.isNegative ? 0 : elapsed.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  if (minutes == 0) return l10n.durationSeconds(seconds);
  if (seconds == 0) return l10n.durationMinutesOnly(minutes);
  return l10n.durationMinutesSeconds(minutes, seconds);
}
