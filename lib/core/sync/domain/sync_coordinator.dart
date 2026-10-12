import 'dart:async';

import 'sync_report.dart';
import 'sync_service.dart';

/// Создаёт одноразовый таймер; в тестах подменяется.
typedef SyncTimerFactory = Timer Function(Duration, void Function());

/// Когда запускать синхронизацию (ТЗ §7.3, ADR-20, ADR-30): по запросу
/// (старт, вход, конец сессии, возврат в приложение), периодически раз в
/// [period] и с нарастающей паузой после неудачи ([syncBackoff]). Отдельного
/// пакета для отслеживания сети нет (ADR-20): появление сети ловит ближайший
/// повтор. Ошибки наружу не выходят: офлайн — штатное состояние.
class SyncCoordinator {
  SyncCoordinator({
    required this._sync,
    SyncTimerFactory? timer,
    this.period = const Duration(minutes: 5),
    this._onReport,
  }) : _timer = timer ?? Timer.new;

  final Future<SyncReport> Function() _sync;
  final SyncTimerFactory _timer;
  final void Function(SyncReport report)? _onReport;
  final Duration period;

  Timer? _next;
  var _failures = 0;
  var _started = false;
  var _disposed = false;

  /// Неудачных прогонов подряд (для тестов и диагностики).
  int get failures => _failures;

  /// Первый прогон и дальше по расписанию.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(requestSync());
  }

  /// Запустить прогон сейчас (повторные вызовы во время прогона сливаются
  /// в один следующий, см. [SyncService.sync]). Возвращает итог или `null`,
  /// если координатор уже закрыт.
  Future<SyncReport?> requestSync() async {
    if (_disposed) return null;
    _next?.cancel();
    final report = await _sync();
    if (_disposed) return report;
    _onReport?.call(report);
    final Duration delay;
    switch (report.outcome) {
      case SyncOutcome.success || SyncOutcome.noSession:
        _failures = 0;
        delay = period;
      case SyncOutcome.offline || SyncOutcome.authFailed || SyncOutcome.failed:
        _failures++;
        delay = syncBackoff(_failures);
    }
    if (_started) {
      _next?.cancel();
      _next = _timer(delay, () => unawaited(requestSync()));
    }
    return report;
  }

  void dispose() {
    _disposed = true;
    _next?.cancel();
  }
}
