import '../../../core/l10n/app_localizations.dart';
import '../domain/rating.dart';

/// Подпись оценки на кнопках панели оценки и в «не согласен».
String ratingLabel(AppLocalizations l10n, Rating rating) => switch (rating) {
  Rating.again => l10n.ratingAgain,
  Rating.hard => l10n.ratingHard,
  Rating.good => l10n.ratingGood,
  Rating.easy => l10n.ratingEasy,
};
