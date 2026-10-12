import '../../errors/app_error.dart';

/// Чем закончился прогон синхронизации.
enum SyncOutcome {
  /// Все шаги §7.3 выполнены.
  success,

  /// Нет сессии: синхронизировать нечего и не от чьего имени. Запустится
  /// после входа.
  noSession,

  /// Нет сети или сервер недоступен. Пользователю не показывается (AC1.1),
  /// повтор с паузой.
  offline,

  /// Сервер не принял сессию (просрочена, сменился пользователь). Повтор с
  /// паузой: gotrue обновит токен или вход выполнится заново.
  authFailed,

  /// Остальное (сервер отклонил пакет, локальная БД, неожиданное). Повтор с
  /// паузой; в логах есть причина.
  failed,
}

/// Итог прогона. Данные, отправленные до сбоя, уже подтверждены и помечены;
/// остальное ждёт следующего прогона.
class SyncReport {
  const SyncReport({
    required this.outcome,
    this.logsPushed = 0,
    this.statesPushed = 0,
    this.outboxSent = 0,
    this.statesPulled = 0,
    this.logsPulled = 0,
    this.skippedInvalid = 0,
    this.error,
  });

  final SyncOutcome outcome;

  /// Логи, приём которых подтвердил сервер (в том числе уже бывшие там).
  final int logsPushed;

  /// Состояния, по которым сервер ответил итоговой строкой.
  final int statesPushed;
  final int outboxSent;
  final int statesPulled;
  final int logsPulled;

  /// Локальные строки, которые сервер заведомо не примет: не отправлены,
  /// остались локально (см. `sync_validator.dart`).
  final int skippedInvalid;
  final AppError? error;

  bool get isSuccess => outcome == SyncOutcome.success;

  @override
  String toString() =>
      'SyncReport(${outcome.name}, logs↑$logsPushed states↑$statesPushed '
      'outbox↑$outboxSent states↓$statesPulled logs↓$logsPulled '
      'skipped $skippedInvalid${error == null ? '' : ', $error'})';
}
