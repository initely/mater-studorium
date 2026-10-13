import 'package:drift/drift.dart';

import '../../features/catalog/domain/local_item.dart';
import '../../features/deck/domain/deck_progress.dart';
import '../../features/session/domain/review_log.dart';
import '../../features/srs/domain/item_state.dart';
import '../../features/srs/domain/srs_state.dart';
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

  /// Ближайшее `due` строго после [after] среди показываемых знаний
  /// (retired и знания без доступных вопросов не считаются), `null`, если
  /// будущих повторений нет. Для пустого состояния «следующее — через …».
  Future<DateTime?> nextDue(
    String userId, {
    required DateTime after,
    Set<String>? deckIds,
  }) async {
    final minDue = userItemStates.due.min();
    final query = selectOnly(userItemStates)
      ..addColumns([minDue])
      ..join([innerJoin(items, items.id.equalsExp(userItemStates.itemId))])
      ..where(
        userItemStates.userId.equals(userId) &
            userItemStates.due.isBiggerThanValue(after.toUtc()) &
            _showable() &
            (deckIds == null
                ? const Constant(true)
                : items.deckId.isIn(deckIds)),
      );
    final due = await query.map((r) => r.read(minDue)).getSingle();
    return due?.toUtc();
  }

  /// Сколько знаний впервые показаны в `[from, to)`: самый ранний лог знания
  /// лежит в этом промежутке (раньше `from` логов нет). Так считается, сколько
  /// новых уже взято за локальные сутки пользователя (границы — UTC, их
  /// считает вызывающий по часовому поясу). Логи с других устройств до
  /// синхронизации не видны (синхронизируются только `review_logs`, ADR-24).
  Future<int> countNewItemsFirstShown(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM user_item_state s '
      'WHERE s.user_id = ?1 '
      'AND EXISTS (SELECT 1 FROM review_logs l WHERE l.user_id = ?1 '
      'AND l.item_id = s.item_id AND l.reviewed_at >= ?2 '
      'AND l.reviewed_at < ?3) '
      'AND NOT EXISTS (SELECT 1 FROM review_logs p WHERE p.user_id = ?1 '
      'AND p.item_id = s.item_id AND p.reviewed_at < ?2)',
      variables: [
        Variable<String>(userId),
        Variable<DateTime>(from.toUtc()),
        Variable<DateTime>(to.toUtc()),
      ],
      readsFrom: {userItemStates, reviewLogs},
    ).getSingle();
    return row.read<int>('c');
  }

  /// Когда в последний раз показывался каждый вопрос этих знаний:
  /// `question_id` -> `reviewed_at` (UTC). Вопроса нет в карте — не
  /// показывался. Вход `VariantPicker.pick` (`lastShownAt`).
  Future<Map<String, DateTime>> lastShownAt(
    String userId,
    Set<String> itemIds,
  ) async {
    final result = <String, DateTime>{};
    // Лимит переменных SQLite: порциями.
    for (final chunk in _chunks(itemIds.toList(), 500)) {
      final lastShown = reviewLogs.reviewedAt.max();
      final query = selectOnly(reviewLogs)
        ..addColumns([reviewLogs.questionId, lastShown])
        ..where(
          reviewLogs.userId.equals(userId) & reviewLogs.itemId.isIn(chunk),
        )
        ..groupBy([reviewLogs.questionId]);
      for (final row in await query.get()) {
        result[row.read(reviewLogs.questionId)!] = row.read(lastShown)!.toUtc();
      }
    }
    return result;
  }

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  /// Прогресс по колоде для экрана колоды: знания без `retired`, сгруппированные
  /// по стадии FSRS (знание без строки состояния — новое). Поток обновляется
  /// при записи ответа и при обновлении колоды (ADR-27).
  Stream<DeckProgress> watchDeckProgress(String userId, String deckId) {
    return customSelect(
      'SELECT s.state AS st, COUNT(*) AS c FROM items i '
      'LEFT JOIN user_item_state s ON s.item_id = i.id AND s.user_id = ?1 '
      'WHERE i.deck_id = ?2 AND i.retired = 0 GROUP BY s.state',
      variables: [Variable<String>(userId), Variable<String>(deckId)],
      readsFrom: {items, userItemStates},
    ).watch().map(
      (rows) => DeckProgress.fromStateCounts([
        for (final r in rows)
          (
            state: r.readNullable<int>('st') == null
                ? null
                : SrsState.fromCode(r.read<int>('st')),
            count: r.read<int>('c'),
          ),
      ]),
    );
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
        await enqueueOutbox(userId, entry);
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

  /// Запись outbox от имени [userId]: синхронизация отправит её только под
  /// сессией этого пользователя. Чтение и удаление — `SyncDao`.
  Future<int> enqueueOutbox(String userId, OutboxEntry entry) =>
      into(outbox).insert(
        OutboxCompanion.insert(
          userId: Value(userId),
          kind: entry.kind,
          payloadJson: entry.payloadJson,
          createdAt: entry.createdAt.toUtc(),
        ),
      );

  /// Записи outbox вида [kind] пользователя [userId] по возрастанию `id`
  /// (ответы дуэли, T23: что уже поставлено в очередь и ещё не отправлено).
  Future<List<OutboxEntry>> pendingOutboxOfKind(
    String userId,
    OutboxKind kind,
  ) async {
    final rows =
        await (select(outbox)
              ..where((o) => o.userId.equals(userId) & o.kind.equalsValue(kind))
              ..orderBy([(o) => OrderingTerm.asc(o.id)]))
            .get();
    return rows.map(outboxFromRow).toList();
  }
}
