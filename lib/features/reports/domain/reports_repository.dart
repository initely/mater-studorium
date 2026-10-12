import 'report_reason.dart';

/// Жалобы пользователя (ТЗ M11). Офлайн-первый: жалоба пишется локально
/// сразу, на сервер уходит через `SyncService` (outbox, шаг 3 §7.3).
///
/// «Не согласен с оценкой» сюда не входит: его report пишется в одной
/// транзакции с логом ответа (`SessionRepository.recordReview`).
abstract interface class ReportsRepository {
  /// Жалоба на вопрос: ставит запись в очередь отправки и **в той же
  /// транзакции** скрывает вопрос у автора жалобы (`hidden_questions`, ТЗ M11,
  /// §8.5), поэтому «скрыто, но не отправлено» и «отправлено, но показывается»
  /// невозможны. Ошибка локальной БД — `LocalStorageError`, ничего не
  /// записано.
  ///
  /// [questionText] — текст вопроса для куратора (обрезается до 600 знаков),
  /// [comment] — необязательный (до 500).
  Future<void> reportQuestion({
    required String deckId,
    required int deckVersion,
    required String questionId,
    required String questionText,
    required ReportReason reason,
    String? comment,
  });
}
