import '../../../core/db/database.dart';
import '../../../core/errors/app_error.dart';
import '../domain/report.dart';
import '../domain/report_outbox.dart';
import '../domain/report_reason.dart';
import '../domain/reports_repository.dart';

/// [ReportsRepository] поверх drift: жалоба и скрытие вопроса — одна
/// транзакция. Ошибки drift превращаются в [LocalStorageError].
class DriftReportsRepository implements ReportsRepository {
  DriftReportsRepository({
    required this._db,
    required this._userId,
    required this._clock,
    required this._newId,
    this._onQueued,
  });

  final AppDatabase _db;

  /// Текущий пользователь; берётся при каждом вызове (вход мог завершиться
  /// после создания репозитория).
  final String Function() _userId;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Просьба к `SyncService` отправить очередь («Синхронизировать сейчас»).
  final void Function()? _onQueued;

  @override
  Future<void> reportQuestion({
    required String deckId,
    required int deckVersion,
    required String questionId,
    required String questionText,
    required ReportReason reason,
    String? comment,
  }) async {
    assert(ReportReason.choosable.contains(reason));
    final report = Report.question(
      id: _newId(),
      deckId: deckId,
      deckVersion: deckVersion,
      questionId: questionId,
      reason: reason,
      comment: comment,
      questionText: questionText,
    );
    try {
      final userId = _userId();
      final entry = reportOutboxEntry(report, _clock());
      await _db.transaction(() async {
        await _db.reviewDao.enqueueOutbox(userId, entry);
        await _db.decksDao.hideQuestion(questionId);
      });
    } on AppError {
      rethrow;
    } on Exception catch (e) {
      throw LocalStorageError('не удалось сохранить жалобу', cause: e);
    }
    // Запись уже в очереди: сбой просьбы о синхронизации жалобу не теряет.
    _onQueued?.call();
  }
}
