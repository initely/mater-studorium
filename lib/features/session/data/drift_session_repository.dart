import '../../../core/db/decks_dao.dart';
import '../../../core/db/review_dao.dart';
import '../../../core/errors/app_error.dart';
import '../../catalog/domain/local_item.dart';
import '../../reports/domain/report.dart';
import '../../reports/domain/report_outbox.dart';
import '../../srs/domain/item_state.dart';
import '../domain/item_content.dart';
import '../domain/review_log.dart';
import '../domain/session_repository.dart';

/// [SessionRepository] поверх [ReviewDao] и [DecksDao]. Ошибки drift
/// превращаются в [LocalStorageError].
class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository({
    required this._review,
    required this._decks,
    required this._userId,
  });

  final ReviewDao _review;
  final DecksDao _decks;

  /// Текущий пользователь; берётся при каждом вызове (вход мог завершиться
  /// после создания репозитория).
  final String Function() _userId;

  @override
  Future<List<ItemState>> dueStates({
    required DateTime now,
    Set<String>? deckIds,
  }) => _guard(() => _review.dueStates(_userId(), now: now, deckIds: deckIds));

  @override
  Future<List<LocalItem>> newItems({
    Set<String>? deckIds,
    required int limit,
  }) =>
      _guard(() => _review.newItems(_userId(), deckIds: deckIds, limit: limit));

  @override
  Future<int> countNewItemsFirstShown({
    required DateTime from,
    required DateTime to,
  }) => _guard(
    () => _review.countNewItemsFirstShown(_userId(), from: from, to: to),
  );

  @override
  Future<DateTime?> nextDue({required DateTime after, Set<String>? deckIds}) =>
      _guard(() => _review.nextDue(_userId(), after: after, deckIds: deckIds));

  @override
  Future<Map<String, ItemContent>> contentFor(Set<String> itemIds) => _guard(
    () async {
      final questions = await _decks.visibleQuestionsFor(itemIds);
      final result = <String, ItemContent>{};
      final versions = <String, int>{};
      for (final MapEntry(key: id, value: itemQuestions) in questions.entries) {
        // Вопрос без знания и знание без колоды запрещены внешними ключами.
        final item = (await _decks.getItem(id))!;
        final version = versions[item.deckId] ??= (await _decks.getDeck(
          item.deckId,
        ))!.version;
        result[id] = ItemContent(
          item: item,
          deckVersion: version,
          questions: itemQuestions,
        );
      }
      return result;
    },
  );

  @override
  Future<Map<String, DateTime>> lastShownAt(Set<String> itemIds) =>
      _guard(() => _review.lastShownAt(_userId(), itemIds));

  @override
  Future<void> recordReview({
    required ReviewLog log,
    required ItemState state,
    Report? report,
  }) => _guard(
    () => _review.recordReview(
      userId: _userId(),
      log: log,
      state: state,
      outbox: [if (report != null) reportOutboxEntry(report, log.reviewedAt)],
    ),
  );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppError {
      // Например, `AuthError` из `userId()`: типизированную ошибку не прячем.
      rethrow;
    } on Exception catch (e) {
      throw LocalStorageError('ошибка локальной БД', cause: e);
    }
  }
}
