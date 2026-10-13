import 'dart:convert';

import '../../../core/db/database.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/sync/outbox_entry.dart';
import '../domain/duel_answer.dart';
import '../domain/duel_answer_queue.dart';

/// [DuelAnswerQueue] поверх outbox в drift. Проверка «уже в очереди» и вставка
/// идут одной транзакцией. Ошибки drift превращаются в [LocalStorageError].
class DriftDuelAnswerQueue implements DuelAnswerQueue {
  DriftDuelAnswerQueue({
    required this._db,
    required this._userId,
    required this._clock,
    this._onQueued,
  });

  final AppDatabase _db;

  /// Текущий пользователь; берётся при каждом вызове.
  final String Function() _userId;
  final DateTime Function() _clock;

  /// Просьба к `SyncService` отправить очередь.
  final void Function()? _onQueued;

  @override
  Future<bool> enqueue(DuelAnswerPayload answer) async {
    final bool queued;
    try {
      final userId = _userId();
      queued = await _db.transaction(() async {
        final pending = await _pending(userId);
        final exists = pending.any(
          (p) => p.duelId == answer.duelId && p.questionId == answer.questionId,
        );
        if (exists) return false;
        await _db.reviewDao.enqueueOutbox(
          userId,
          duelAnswerOutboxEntry(answer, _clock()),
        );
        return true;
      });
    } on AppError {
      rethrow;
    } on Exception catch (e) {
      throw LocalStorageError('не удалось сохранить ответ дуэли', cause: e);
    }
    // Запись уже в очереди: сбой просьбы о синхронизации ответ не теряет.
    if (queued) _onQueued?.call();
    return queued;
  }

  @override
  Future<Set<String>> pendingQuestionIds(String duelId) async {
    try {
      final pending = await _pending(_userId());
      return {
        for (final p in pending)
          if (p.duelId == duelId) p.questionId,
      };
    } on AppError {
      rethrow;
    } on Exception catch (e) {
      throw LocalStorageError('не удалось прочитать очередь дуэли', cause: e);
    }
  }

  Future<List<DuelAnswerPayload>> _pending(String userId) async {
    final entries = await _db.reviewDao.pendingOutboxOfKind(
      userId,
      OutboxKind.duelAnswer,
    );
    return [for (final e in entries) ?_parse(e.payloadJson)];
  }

  static DuelAnswerPayload? _parse(String json) {
    try {
      return DuelAnswerPayload.tryParse(jsonDecode(json));
    } on FormatException {
      return null;
    }
  }
}
