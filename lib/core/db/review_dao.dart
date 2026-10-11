import 'package:drift/drift.dart';

import '../../features/catalog/domain/local_item.dart';
import '../../features/session/domain/review_log.dart';
import '../../features/srs/domain/item_state.dart';
import '../sync/outbox_entry.dart';
import 'database.dart';
import 'mappers.dart';
import 'tables.dart';

part 'review_dao.g.dart';

/// Прогресс: состояние знаний, журнал ответов, outbox и выборки для очереди
/// сессии. Расписание считает SRS-модуль (T11), здесь только хранение.
@DriftAccessor(
  tables: [
    Items,
    Questions,
    HiddenQuestions,
    UserItemStates,
    ReviewLogs,
    Outbox,
  ],
)
class ReviewDao extends DatabaseAccessor<AppDatabase> with _$ReviewDaoMixin {
  ReviewDao(super.attachedDatabase);

  /// У знания не retired и есть хотя бы один не скрытый вопрос.
  Expression<bool> _showable() =>
      items.retired.equals(false) &
      existsQuery(
        select(questions)..where(
          (q) =>
              q.itemId.equalsExp(items.id) &
              q.id.isNotInQuery(
                selectOnly(hiddenQuestions)
                  ..addColumns([hiddenQuestions.questionId]),
              ),
        ),
      );

  /// Состояния знаний, которые пора повторить (`due <= now`), по возрастанию
  /// `due`. Retired и знания без доступных вопросов не возвращаются.
  /// [deckIds] ограничивает колоды, [limit] — число знаний.
  Future<List<ItemState>> dueStates(
    String userId, {
    required DateTime now,
    Set<String>? deckIds,
    int? limit,
  }) async {
    final query =
        select(userItemStates)
            .join([innerJoin(items, items.id.equalsExp(userItemStates.itemId))])
          ..where(
            userItemStates.userId.equals(userId) &
                userItemStates.due.isSmallerOrEqualValue(now.toUtc()) &
                _showable() &
                (deckIds == null
                    ? const Constant(true)
                    : items.deckId.isIn(deckIds)),
          )
          ..orderBy([
            OrderingTerm.asc(userItemStates.due),
            OrderingTerm.asc(userItemStates.itemId),
          ]);
    if (limit != null) query.limit(limit);
    final rows = await query.map((r) => r.readTable(userItemStates)).get();
    return rows.map(itemStateFromRow).toList();
  }

  /// Знания, которых у пользователя ещё нет в `user_item_state`, в порядке
  /// записи в БД (то есть в порядке колоды). Retired и знания без доступных
  /// вопросов не возвращаются.
  Future<List<LocalItem>> newItems(
    String userId, {
    Set<String>? deckIds,
    int? limit,
  }) async {
    final query = select(items)
      ..where(
        (i) =>
            _showable() &
            notExistsQuery(
              select(userItemStates)..where(
                (s) => s.itemId.equalsExp(i.id) & s.userId.equals(userId),
              ),
            ) &
            (deckIds == null ? const Constant(true) : i.deckId.isIn(deckIds)),
      )
      ..orderBy([
        (i) => OrderingTerm.asc(const CustomExpression<int>('items.rowid')),
      ]);
    if (limit != null) query.limit(limit);
    return (await query.get()).map(itemFromRow).toList();
  }

  Future<ItemState?> getState(String userId, String itemId) async {
    final row =
        await (select(userItemStates)
              ..where((s) => s.userId.equals(userId) & s.itemId.equals(itemId)))
            .getSingleOrNull();
    return row == null ? null : itemStateFromRow(row);
  }

  /// Записывает ответ: лог, новое состояние знания (`dirty = true`) и,
  /// если нужно, записи outbox — одной транзакцией. Любая ошибка откатывает
  /// всё. Повторный `log.id` — ошибка (уникальность), а не молчаливый пропуск.
  Future<void> recordReview({
    required String userId,
    required ReviewLog log,
    required ItemState state,
    List<OutboxEntry> outbox = const [],
  }) {
    return transaction(() async {
      await into(userItemStates).insertOnConflictUpdate(
        UserItemStatesCompanion.insert(
          userId: userId,
          itemId: state.itemId,
          deckId: state.deckId,
          due: state.due.toUtc(),
          stability: state.stability,
          difficulty: state.difficulty,
          elapsedDays: state.elapsedDays,
          scheduledDays: state.scheduledDays,
          reps: state.reps,
          lapses: state.lapses,
          state: state.state.code,
          lastReview: Value(state.lastReview?.toUtc()),
          lastQuestionId: Value(state.lastQuestionId),
          updatedAt: state.updatedAt.toUtc(),
          dirty: const Value(true),
        ),
      );
      for (final entry in outbox) {
        await enqueueOutbox(entry);
      }
      await into(reviewLogs).insert(
        ReviewLogsCompanion.insert(
          id: log.id,
          userId: userId,
          deckId: log.deckId,
          deckVersion: log.deckVersion,
          itemId: log.itemId,
          questionId: log.questionId,
          questionType: log.questionType.wire,
          rating: log.rating.code,
          gradeSource: log.gradeSource.wire,
          llmScore: Value(log.llmScore),
          answerText: Value(log.answerText),
          durationMs: log.durationMs,
          reviewedAt: log.reviewedAt.toUtc(),
        ),
      );
    });
  }

  Future<int> enqueueOutbox(OutboxEntry entry) => into(outbox).insert(
    OutboxCompanion.insert(
      kind: entry.kind,
      payloadJson: entry.payloadJson,
      createdAt: entry.createdAt.toUtc(),
    ),
  );

  /// Записи outbox от старых к новым.
  Future<List<OutboxEntry>> pendingOutbox({int? limit}) async {
    final query = select(outbox)..orderBy([(o) => OrderingTerm.asc(o.id)]);
    if (limit != null) query.limit(limit);
    return (await query.get()).map(outboxFromRow).toList();
  }

  Future<void> deleteOutbox(int id) =>
      (delete(outbox)..where((o) => o.id.equals(id))).go();

  Future<void> incrementOutboxAttempts(int id) => customUpdate(
    'UPDATE outbox SET attempts = attempts + 1 WHERE id = ?',
    variables: [Variable<int>(id)],
    updates: {outbox},
  );
}
