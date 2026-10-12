import 'dart:convert';

import '../../../features/reports/domain/report.dart';
import '../../../features/reports/domain/report_validator.dart';
import '../../errors/app_error.dart';
import 'outbox_handler.dart';
import 'sync_remote.dart';

/// Сколько раз сервер может отвергнуть жалобу как неверную, прежде чем её
/// отбросят: единичный отказ может быть сбоем (расхождение версий, колода
/// ещё не опубликована), повторяющийся — нет.
const kMaxRejectedReportAttempts = 3;

/// Обработчик outbox для `OutboxKind.report` (шаг 3 §7.3, T20, ADR-33).
///
/// Идемпотентен: сервер повторно ту же жалобу (тот же uuid) не создаёт,
/// ответ `false` — не ошибка. «Ядовитая» запись не блокирует очередь:
/// - не разбирается или не пройдёт серверные ограничения (`isValidReport`)
///   — отбрасывается (обработчик возвращается без ошибки, запись удаляется);
/// - сервер её отверг ([SyncRejectedError]: 22xxx, 23xxx и т. п.) — повтор
///   до [kMaxRejectedReportAttempts], затем отбрасывается;
/// - дневной лимит ([QuotaExceededError]) — запись остаётся, `attempts + 1`
///   (сервис), следующий прогон попробует снова;
/// - сеть и доступ ([NetworkError], [AuthError]) пробрасываются: прогон
///   прерывается, запись остаётся.
OutboxHandler reportOutboxHandler(SyncRemote remote) => (userId, entry) async {
  final Report report;
  try {
    report = Report.fromJson(jsonDecode(entry.payloadJson));
  } on Object {
    return;
  }
  if (!isValidReport(report)) return;
  try {
    await remote.submitReport(userId, report);
  } on SyncRejectedError {
    if (entry.attempts + 1 >= kMaxRejectedReportAttempts) return;
    rethrow;
  }
};
