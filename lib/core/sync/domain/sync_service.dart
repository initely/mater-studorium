import 'dart:async';
import 'dart:math' as math;

import '../../../features/session/domain/review_log.dart';
import '../../../features/srs/domain/item_state.dart';
import '../../errors/app_error.dart';
import 'outbox_handler.dart';
import 'sync_remote.dart';
import 'sync_report.dart';
import 'sync_store.dart';
import 'sync_validator.dart';

/// Синхронизация прогресса (ТЗ §7.3, ADR-14, ADR-30). Шаги одного прогона:
/// 1. push неотправленных `review_logs` (идемпотентно по id);
/// 2. push dirty `user_item_state` (LWW на сервере);
/// 3. push outbox (реестр обработчиков по `kind`);
/// 4. pull состояний после курсора и LWW-слияние;
/// 5. pull логов после курсора (`hidden_questions` добавит T20).
///
/// Гарантии:
/// - локальная пометка «отправлено» (`synced_at`, снятие `dirty`) ставится
///   только после ответа сервера, поэтому сбой на середине ничего не теряет,
///   а повтор того же пакета безопасен (сервер идемпотентен);
/// - одновременно идёт не больше одного прогона; вызов во время прогона
///   ставит в очередь ровно один следующий прогон (всё записанное до вызова
///   будет отправлено);
/// - данные пользователя уходят только под его сессией: пользователь берётся
///   в начале прогона, сменился — прогон прерывается (`authFailed`);
/// - [sync] не бросает: всё заканчивается [SyncReport].
class SyncService {
  SyncService({
    required this._remote,
    required this._store,
    required this._currentUserId,
    required this._clock,
    this._outboxHandlers = const {},
    this.pushBatchSize = 200,
    this.pullPageSize = 500,
  }) : assert(pushBatchSize > 0 && pushBatchSize <= kMaxSyncBatch),
       assert(pullPageSize > 0);

  final SyncRemote _remote;
  final SyncStore _store;
  final String? Function() _currentUserId;
  final DateTime Function() _clock;
  final OutboxHandlers _outboxHandlers;
  final int pushBatchSize;
  final int pullPageSize;

  final _lock = _Lock();
  Future<SyncReport>? _queued;

  /// Запускает прогон. Если прогон уже идёт, возвращает следующий прогон
  /// из очереди (он начнётся после текущего); несколько вызовов во время
  /// одного прогона дают один следующий.
  Future<SyncReport> sync() {
    final queued = _queued;
    if (queued != null) return queued;
    final run = _lock.protect(() {
      // Прогон стартовал: следующие вызовы ставят в очередь новый.
      _queued = null;
      return _runOnce();
    });
    _queued = run;
    return run;
  }

  /// Перенос локальных данных между пользователями (ADR-30) — под тем же
  /// замком, что и прогоны: не смешивается с отправкой данных [from].
  Future<void> adoptLocalData({required String from, required String to}) =>
      _lock.protect(() => _store.adoptLocalData(from: from, to: to));

  Future<SyncReport> _runOnce() async {
    final userId = _currentUserId();
    if (userId == null) return const SyncReport(outcome: SyncOutcome.noSession);
    final r = _Counters();
    try {
      await _pushLogs(userId, r);
      await _pushStates(userId, r);
      await _pushOutbox(userId, r);
      await _pullStates(userId, r);
      await _pullLogs(userId, r);
      return r.report(SyncOutcome.success);
    } on NetworkError catch (e) {
      return r.report(SyncOutcome.offline, e);
    } on AuthError catch (e) {
      return r.report(SyncOutcome.authFailed, e);
    } on AppError catch (e) {
      return r.report(SyncOutcome.failed, e);
    } catch (e) {
      return r.report(
        SyncOutcome.failed,
        UnexpectedError('синхронизация: неожиданная ошибка', cause: e),
      );
    }
  }

  /// Перед каждым сетевым шагом: сессия всё ещё того же пользователя.
  void _ensureUser(String userId) {
    if (_currentUserId() != userId) {
      throw const AuthError('пользователь сменился во время синхронизации');
    }
  }

  Future<void> _pushLogs(String userId, _Counters r) async {
    ReviewLog? after;
    while (true) {
      final batch = await _store.unsyncedLogs(
        userId,
        limit: pushBatchSize,
        after: after,
      );
      if (batch.isEmpty) return;
      after = batch.last;
      final valid = <ReviewLog>[];
      for (final log in batch) {
        final normalized = normalizeLogForPush(log);
        if (normalized == null) {
          r.skippedInvalid++;
        } else {
          valid.add(normalized);
        }
      }
      if (valid.isNotEmpty) {
        _ensureUser(userId);
        await _remote.insertReviewLogs(userId, valid);
        await _store.markLogsSynced(userId, [
          for (final l in valid) l.id,
        ], _clock());
        r.logsPushed += valid.length;
      }
      if (batch.length < pushBatchSize) return;
    }
  }

  Future<void> _pushStates(String userId, _Counters r) async {
    String? after;
    while (true) {
      final batch = await _store.dirtyStates(
        userId,
        limit: pushBatchSize,
        afterItemId: after,
      );
      if (batch.isEmpty) return;
      after = batch.last.itemId;
      final valid = <ItemState>[];
      for (final s in batch) {
        if (isValidStateForPush(s)) {
          valid.add(s);
        } else {
          r.skippedInvalid++;
        }
      }
      if (valid.isNotEmpty) {
        _ensureUser(userId);
        final server = await _remote.upsertItemStates(userId, valid);
        await _store.applyPushedStates(userId, sent: valid, server: server);
        r.statesPushed += server.length;
      }
      if (batch.length < pushBatchSize) return;
    }
  }

  Future<void> _pushOutbox(String userId, _Counters r) async {
    int? after;
    while (true) {
      final batch = await _store.pendingOutbox(
        userId,
        limit: pushBatchSize,
        afterId: after,
      );
      if (batch.isEmpty) return;
      after = batch.last.id;
      for (final entry in batch) {
        final handler = _outboxHandlers[entry.kind];
        if (handler == null) continue;
        _ensureUser(userId);
        try {
          await handler(userId, entry);
        } on NetworkError {
          rethrow;
        } on AuthError {
          rethrow;
        } on AppError {
          await _store.markOutboxAttempt(entry.id!);
          continue;
        }
        await _store.deleteOutbox(entry.id!);
        r.outboxSent++;
      }
      if (batch.length < pushBatchSize) return;
    }
  }

  Future<void> _pullStates(String userId, _Counters r) async {
    var cursor = await _store.cursor(userId, SyncStream.itemStates);
    while (true) {
      _ensureUser(userId);
      final page = await _remote.pullItemStates(
        userId,
        afterSeq: cursor,
        limit: pullPageSize,
      );
      final next = page.lastSeq;
      // Курсор только растёт: иначе неверный ответ сервера зациклил бы pull.
      if (next == null || next <= cursor) return;
      await _store.mergePulledStates(userId, page.rows, cursor: next);
      r.statesPulled += page.rows.length;
      cursor = next;
      if (page.fetched < pullPageSize) return;
    }
  }

  Future<void> _pullLogs(String userId, _Counters r) async {
    var cursor = await _store.cursor(userId, SyncStream.reviewLogs);
    while (true) {
      _ensureUser(userId);
      final page = await _remote.pullReviewLogs(
        userId,
        afterSeq: cursor,
        limit: pullPageSize,
      );
      final next = page.lastSeq;
      if (next == null || next <= cursor) return;
      await _store.insertPulledLogs(
        userId,
        page.rows,
        cursor: next,
        syncedAt: _clock(),
      );
      r.logsPulled += page.rows.length;
      cursor = next;
      if (page.fetched < pullPageSize) return;
    }
  }
}

class _Counters {
  var logsPushed = 0;
  var statesPushed = 0;
  var outboxSent = 0;
  var statesPulled = 0;
  var logsPulled = 0;
  var skippedInvalid = 0;

  SyncReport report(SyncOutcome outcome, [AppError? error]) => SyncReport(
    outcome: outcome,
    logsPushed: logsPushed,
    statesPushed: statesPushed,
    outboxSent: outboxSent,
    statesPulled: statesPulled,
    logsPulled: logsPulled,
    skippedInvalid: skippedInvalid,
    error: error,
  );
}

/// Асинхронный замок: задачи выполняются строго по одной, в порядке вызова.
class _Lock {
  Future<void> _tail = Future.value();

  Future<T> protect<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    // Ошибка задачи не ломает очередь следующих.
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}

/// Пауза перед повтором после [failures] неудачных прогонов подряд:
/// 5 с, 10 с, 20 с, … не больше 5 минут.
Duration syncBackoff(int failures) {
  final exponent = math.min(math.max(0, failures - 1), 10);
  final seconds = 5 * math.pow(2, exponent).toInt();
  return Duration(seconds: math.min(seconds, 300));
}
