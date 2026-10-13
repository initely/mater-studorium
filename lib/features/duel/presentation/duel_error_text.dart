import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';

/// Понятный текст для ошибки действия с дуэлью (без технических деталей).
/// «Неверный или просроченный код» — формулировка ТЗ §8.5.
String duelErrorText(AppLocalizations l10n, AppError error) => switch (error) {
  DuelCodeNotFoundError() => l10n.duelErrorNotFound,
  DuelFullError() => l10n.duelErrorFull,
  DuelLimitError(:final kind) => switch (kind) {
    DuelLimitKind.activeDuels => l10n.duelErrorLimitActive,
    DuelLimitKind.dailyCreate => l10n.duelErrorLimitDaily,
    DuelLimitKind.joinAttempts => l10n.duelErrorLimitJoin,
  },
  DuelNotEnoughQuestionsError(:final available) => l10n.duelCreateNotEnough(
    available,
  ),
  NetworkError() => l10n.duelErrorNetwork,
  AuthError() => l10n.duelErrorAuth,
  DeckNotFoundError() => l10n.duelErrorDeck,
  _ => l10n.duelErrorGeneric,
};
