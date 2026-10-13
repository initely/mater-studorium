import 'dart:convert';

import '../../../features/duel/domain/duel_answer.dart';
import '../../../features/duel/domain/duel_answer_validator.dart';
import '../../errors/app_error.dart';
import 'outbox_handler.dart';
import 'sync_remote.dart';

/// Сколько раз ответ дуэли может не пройти (отказ сервера по значению или
/// неожиданный ответ), прежде чем его отбросят: единичный отказ может быть
/// сбоем, повторяющийся — нет.
const kMaxFailedDuelAnswerAttempts = 3;

/// Обработчик outbox для `OutboxKind.duelAnswer` (шаг 3 §7.3, T23, ADR-36).
///
/// Идемпотентен: сервер повтор того же ответа (дуэль, пользователь, вопрос)
/// не записывает и отвечает `duplicate`, это не ошибка. «Ядовитая» запись не
/// блокирует очередь (урок T17):
/// - не разбирается или не пройдёт серверные ограничения
///   (`isValidDuelAnswerPayload`) — отбрасывается;
/// - дуэль закрыта: срок вышел, она завершена или недоступна
///   ([DuelClosedError]) — отбрасывается сразу, повтор не поможет;
/// - сервер отверг значение ([SyncRejectedError]) или ответил непонятно
///   ([UnexpectedError]) — повтор до [kMaxFailedDuelAnswerAttempts], затем
///   отбрасывается;
/// - сеть и доступ ([NetworkError], [AuthError]) пробрасываются: прогон
///   прерывается, запись остаётся.
OutboxHandler duelAnswerOutboxHandler(SyncRemote remote) =>
    (userId, entry) async {
      final DuelAnswerPayload? answer;
      try {
        answer = DuelAnswerPayload.tryParse(jsonDecode(entry.payloadJson));
      } on FormatException {
        return;
      }
      if (answer == null || !isValidDuelAnswerPayload(answer)) return;
      try {
        await remote.submitDuelAnswer(userId, answer);
      } on DuelClosedError {
        return;
      } on SyncRejectedError {
        if (entry.attempts + 1 >= kMaxFailedDuelAnswerAttempts) return;
        rethrow;
      } on UnexpectedError {
        if (entry.attempts + 1 >= kMaxFailedDuelAnswerAttempts) return;
        rethrow;
      }
    };
