import 'dart:convert';

import '../../../core/sync/outbox_entry.dart';
import 'duel_answer.dart';

/// Очередь отправки ответов дуэли (локальная часть, CLAUDE.md, правило 4).
/// Реализация в `data/` пишет в outbox (`kind = duel_answer`); отправку ведёт
/// `SyncService`. Ответы дуэли в `review_logs`, `user_item_state` и FSRS не
/// попадают (ADR-16).
abstract interface class DuelAnswerQueue {
  /// Ставит ответ в очередь. `false`, если ответ на этот вопрос этой дуэли
  /// уже стоит в очереди (повторный ответ не принимается и локально). Ошибка
  /// хранилища — `LocalStorageError`, ответ, не проходящий ограничения сервера
  /// (`isValidDuelAnswerPayload`), — `InvalidDuelAnswerError`; ничего не записано.
  Future<bool> enqueue(DuelAnswerPayload answer);

  /// Вопросы дуэли [duelId], ответы на которые стоят в очереди и ещё не ушли
  /// на сервер.
  Future<Set<String>> pendingQuestionIds(String duelId);
}

/// Запись outbox для [answer]: `payload_json` — тело RPC `submit_duel_answer`.
OutboxEntry duelAnswerOutboxEntry(DuelAnswerPayload answer, DateTime now) =>
    OutboxEntry(
      kind: OutboxKind.duelAnswer,
      payloadJson: jsonEncode(answer.toJson()),
      createdAt: now,
    );
