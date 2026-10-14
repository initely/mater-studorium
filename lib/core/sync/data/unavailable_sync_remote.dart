import '../../../features/duel/domain/duel_answer.dart';
import '../../../features/reports/domain/report.dart';
import '../../../features/session/domain/review_log.dart';
import '../../../features/srs/domain/item_state.dart';
import '../../errors/app_error.dart';
import '../domain/sync_remote.dart';

/// Сервер синхронизации, когда Supabase не инициализирован: каждый вызов —
/// `NetworkError`, `SyncService` оставляет данные в очереди и повторит позже.
final class UnavailableSyncRemote implements SyncRemote {
  const UnavailableSyncRemote();

  static const _error = NetworkError('Supabase недоступен');

  @override
  Future<int> insertReviewLogs(String userId, List<ReviewLog> logs) =>
      Future.error(_error);

  @override
  Future<List<ItemState>> upsertItemStates(
    String userId,
    List<ItemState> states,
  ) => Future.error(_error);

  @override
  Future<PulledPage<ItemState>> pullItemStates(
    String userId, {
    required int afterSeq,
    required int limit,
  }) => Future.error(_error);

  @override
  Future<PulledPage<ReviewLog>> pullReviewLogs(
    String userId, {
    required int afterSeq,
    required int limit,
  }) => Future.error(_error);

  @override
  Future<bool> submitReport(String userId, Report report) =>
      Future.error(_error);

  @override
  Future<bool> submitDuelAnswer(String userId, DuelAnswerPayload answer) =>
      Future.error(_error);

  @override
  Future<Set<String>> pullHiddenQuestions(String userId) =>
      Future.error(_error);
}
