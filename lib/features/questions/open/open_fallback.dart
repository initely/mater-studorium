import '../../../core/errors/app_error.dart';
import '../../../core/l10n/app_localizations.dart';

/// Почему проверка моделью не состоялась и пользователь оценивает себя сам
/// (ТЗ §4.2 «при сомнении», §8.5, AC5.2).
enum OpenFallbackReason {
  /// Нет сети, таймаут, сервер не ответил или ответил не по контракту.
  unavailable,

  /// Дневной лимит проверок исчерпан.
  quota,

  /// Нет сессии пользователя (любой 401).
  signedOut,

  /// Модель не уверена в оценке (`unsure`).
  unsure,

  /// Пользователь отказался от проверки внешней моделью («без ИИ»).
  disabled,

  /// Пользователь нажал «Не помню».
  skipped,
}

/// Причина самооценки и что можно сделать дальше.
class OpenFallback {
  const OpenFallback(this.reason, {this.resetAt, this.retryable = false});

  final OpenFallbackReason reason;

  /// Когда обнулится лимит (UTC), для [OpenFallbackReason.quota].
  final DateTime? resetAt;

  /// Повтор «Проверить ещё раз» может помочь: сеть и сервер временные.
  /// Лимит, вход, отказ, `unsure` и ошибка ввода от повтора не изменятся.
  final bool retryable;
}

/// Ошибка репозитория оценки → самооценка. Любая ошибка, кроме перечисленных,
/// тоже ведёт на самооценку: сессию проверка не блокирует. Повтор предлагаем
/// только при сбое сети и сервера ([NetworkError]).
OpenFallback fallbackFor(AppError error) => switch (error) {
  AuthError() => const OpenFallback(OpenFallbackReason.signedOut),
  QuotaExceededError(:final resetAt) => OpenFallback(
    OpenFallbackReason.quota,
    resetAt: resetAt,
  ),
  NetworkError() => const OpenFallback(
    OpenFallbackReason.unavailable,
    retryable: true,
  ),
  // Ошибка ввода (400, 404, 413) и ответ не по контракту от повтора не
  // изменятся; пользователю достаточно «проверка недоступна».
  _ => const OpenFallback(OpenFallbackReason.unavailable),
};

/// Человеческое сообщение без технических подробностей.
String openFallbackText(AppLocalizations l10n, OpenFallback fallback) {
  switch (fallback.reason) {
    case OpenFallbackReason.unavailable:
      return l10n.openFallbackUnavailable;
    case OpenFallbackReason.quota:
      final reset = fallback.resetAt;
      return reset == null
          ? l10n.openFallbackQuota
          : l10n.openFallbackQuotaReset(_hhmm(reset.toLocal()));
    case OpenFallbackReason.signedOut:
      return l10n.openFallbackSignedOut;
    case OpenFallbackReason.unsure:
      return l10n.openFallbackUnsure;
    case OpenFallbackReason.disabled:
      return l10n.openFallbackDisabled;
    case OpenFallbackReason.skipped:
      return l10n.openFallbackSkipped;
  }
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
