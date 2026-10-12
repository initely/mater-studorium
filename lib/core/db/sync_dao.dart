import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/auth/domain/auth_user.dart';
import '../../features/catalog/domain/question_type.dart';
import '../../features/session/domain/grade_source.dart';
import '../../features/session/domain/review_log.dart';
import '../../features/srs/domain/item_state.dart';
import '../../features/srs/domain/rating.dart';
import '../sync/domain/sync_store.dart';
import '../sync/outbox_entry.dart';
import 'database.dart';
import 'mappers.dart';
import 'tables.dart';

part 'sync_dao.g.dart';

/// Ключ `app_settings`: чьи данные лежат на устройстве (ADR-28).
const kLastOwnerSettingKey = 'sync.last_owner';

/// Локальная сторона синхронизации (T17, ТЗ §7.3). Все выборки и записи
/// ограничены `user_id`; слияние и сдвиг курсора — одной транзакцией.
@DriftAccessor(
  tables: [UserItemStates, ReviewLogs, Outbox, SyncCursors, AppSettings],
)
class SyncDao extends DatabaseAccessor<AppDatabase>
    with _$SyncDaoMixin
    implements SyncStore {
  SyncDao(super.attachedDatabase);

  @override
  Future<List<ReviewLog>> unsyncedLogs(
    String userId, {
    required int limit,
    ReviewLog? after,
  }) async {
    final query = select(reviewLogs)
      ..where((l) {
        var cond = l.userId.equals(userId) & l.syncedAt.isNull();
        if (after != null) {
          final at = after.reviewedAt.toUtc();
          cond =
              cond &
              (l.reviewedAt.isBiggerThanValue(at) |
                  (l.reviewedAt.equals(at) & l.id.isBiggerThanValue(after.id)));
        }
        return cond;
      })
      ..orderBy([
        (l) => OrderingTerm.asc(l.reviewedAt),
        (l) => OrderingTerm.asc(l.id),
      ])
      ..limit(limit);
    return (await query.get()).map(_logFromRow).toList();
  }

  @override
  Future<void> markLogsSynced(String userId, List<String> ids, DateTime at) =>
      transaction(() async {
        for (final chunk in _chunks(ids, 500)) {
          await (update(reviewLogs)
                ..where((l) => l.userId.equals(userId) & l.id.isIn(chunk)))
              .write(ReviewLogsCompanion(syncedAt: Value(at.toUtc())));
        }
      });

  @override
  Future<List<ItemState>> dirtyStates(
    String userId, {
    required int limit,
    String? afterItemId,
  }) async {
    final query = select(userItemStates)
      ..where(
        (s) =>
            s.userId.equals(userId) &
            s.dirty.equals(true) &
            (afterItemId == null
                ? const Constant(true)
                : s.itemId.isBiggerThanValue(afterItemId)),
      )
      ..orderBy([(s) => OrderingTerm.asc(s.itemId)])
      ..limit(limit);
    return (await query.get()).map(itemStateFromRow).toList();
  }

  @override
  Future<void> applyPushedStates(
    String userId, {
    required List<ItemState> sent,
    required List<ItemState> server,
  }) => transaction(() async {
    final byItem = {for (final s in server) s.itemId: s};
    for (final mine in sent) {
      final theirs = byItem[mine.itemId];
      if (theirs == null) continue;
      final row = await _row(userId, mine.itemId);
      final local = row == null ? null : itemStateFromRow(row);
      // Строка не менялась с отправки: сервер решил её судьбу (принял,
      // возможно с зажатым updatedAt, или у него строка не старее) —
      // берём его итог. Иначе во время отправки был новый ответ: обычное
      // слияние, локальная новее сервера остаётся dirty.
      final action = local == null || local == mine
          ? MergeAction.takeServer
          : decideMerge(local: local, localDirty: row!.dirty, server: theirs);
      await _apply(userId, action, theirs);
    }
  });

  @override
  Future<int> cursor(String userId, SyncStream stream) async {
    final row =
        await (select(syncCursors)..where(
              (c) => c.userId.equals(userId) & c.stream.equals(stream.wire),
            ))
            .getSingleOrNull();
    return row?.cursor ?? 0;
  }

  Future<void> _setCursor(String userId, SyncStream stream, int value) async {
    // Курсор не уменьшается.
    final current = await cursor(userId, stream);
    if (value <= current) return;
    await into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(
        userId: userId,
        stream: stream.wire,
        cursor: value,
      ),
    );
  }

  @override
  Future<void> mergePulledStates(
    String userId,
    List<ItemState> states, {
    required int cursor,
  }) => transaction(() async {
    for (final theirs in states) {
      final row = await _row(userId, theirs.itemId);
      final action = decideMerge(
        local: row == null ? null : itemStateFromRow(row),
        localDirty: row?.dirty ?? false,
        server: theirs,
      );
      await _apply(userId, action, theirs);
    }
    await _setCursor(userId, SyncStream.itemStates, cursor);
  });

  @override
  Future<void> insertPulledLogs(
    String userId,
    List<ReviewLog> logs, {
    required int cursor,
    required DateTime syncedAt,
  }) => transaction(() async {
    final at = syncedAt.toUtc();
    for (final log in logs) {
      await into(reviewLogs).insert(
        _logCompanion(userId, log, syncedAt: at),
        mode: InsertMode.insertOrIgnore,
      );
    }
    // Лог уже есть локально, но не помечен (ответ на push потерялся): раз
    // он пришёл с сервера, он там есть.
    for (final chunk in _chunks([for (final l in logs) l.id], 500)) {
      await (update(reviewLogs)..where(
            (l) =>
                l.userId.equals(userId) &
                l.id.isIn(chunk) &
                l.syncedAt.isNull(),
          ))
          .write(ReviewLogsCompanion(syncedAt: Value(at)));
    }
    await _setCursor(userId, SyncStream.reviewLogs, cursor);
  });

  @override
  Future<List<OutboxEntry>> pendingOutbox(
    String userId, {
    required int limit,
    int? afterId,
  }) async {
    final query = select(outbox)
      ..where(
        (o) =>
            o.userId.equals(userId) &
            (afterId == null
                ? const Constant(true)
                : o.id.isBiggerThanValue(afterId)),
      )
      ..orderBy([(o) => OrderingTerm.asc(o.id)])
      ..limit(limit);
    return (await query.get()).map(outboxFromRow).toList();
  }

  @override
  Future<void> deleteOutbox(int id) =>
      (delete(outbox)..where((o) => o.id.equals(id))).go();

  @override
  Future<void> markOutboxAttempt(int id) => customUpdate(
    'UPDATE outbox SET attempts = attempts + 1 WHERE id = ?',
    variables: [Variable<int>(id)],
    updates: {outbox},
  );

  @override
  Future<AuthUser?> lastOwner() async {
    final row = await (select(
      appSettings,
    )..where((s) => s.key.equals(kLastOwnerSettingKey))).getSingleOrNull();
    if (row == null) return null;
    try {
      final json = jsonDecode(row.value) as Map<String, dynamic>;
      return AuthUser(
        id: json['id'] as String,
        isAnonymous: json['anonymous'] as bool,
      );
    } on Object {
      // Битое значение: считаем, что прежний владелец неизвестен (данные
      // тогда не переносятся — безопасная сторона).
      return null;
    }
  }

  @override
  Future<void> saveOwner(AuthUser user) => into(appSettings).insert(
    AppSettingsCompanion.insert(
      key: kLastOwnerSettingKey,
      value: jsonEncode({'id': user.id, 'anonymous': user.isAnonymous}),
    ),
    mode: InsertMode.insertOrReplace,
  );

  @override
  Future<void> adoptLocalData({required String from, required String to}) =>
      transaction(() async {
        if (from == to) return;
        final vars = [Variable<String>(from), Variable<String>(to)];
        // Знание есть у обоих: остаётся более позднее (при равенстве —
        // строка нового пользователя).
        await customUpdate(
          'DELETE FROM user_item_state WHERE user_id = ?2 AND EXISTS ('
          'SELECT 1 FROM user_item_state f WHERE f.user_id = ?1 '
          'AND f.item_id = user_item_state.item_id '
          'AND f.updated_at > user_item_state.updated_at)',
          variables: vars,
          updates: {userItemStates},
          updateKind: UpdateKind.delete,
        );
        await customUpdate(
          'DELETE FROM user_item_state WHERE user_id = ?1 AND EXISTS ('
          'SELECT 1 FROM user_item_state t WHERE t.user_id = ?2 '
          'AND t.item_id = user_item_state.item_id)',
          variables: vars,
          updates: {userItemStates},
          updateKind: UpdateKind.delete,
        );
        // На сервере нового пользователя этих состояний нет: отправить.
        await customUpdate(
          'UPDATE user_item_state SET user_id = ?2, dirty = 1 '
          'WHERE user_id = ?1',
          variables: vars,
          updates: {userItemStates},
        );
        // Отправленные логи остаются отправленными: на сервере они записаны
        // за прежним пользователем, и повтор ничего бы не дал (id занят).
        await customUpdate(
          'UPDATE review_logs SET user_id = ?2 WHERE user_id = ?1',
          variables: vars,
          updates: {reviewLogs},
        );
        await customUpdate(
          'UPDATE outbox SET user_id = ?2 WHERE user_id = ?1',
          variables: vars,
          updates: {outbox},
        );
        await (delete(syncCursors)..where((c) => c.userId.equals(from))).go();
      });

  Future<UserItemStateRow?> _row(String userId, String itemId) =>
      (select(userItemStates)
            ..where((s) => s.userId.equals(userId) & s.itemId.equals(itemId)))
          .getSingleOrNull();

  Future<void> _apply(String userId, MergeAction action, ItemState theirs) {
    switch (action) {
      case MergeAction.takeServer:
        return into(
          userItemStates,
        ).insertOnConflictUpdate(_stateCompanion(userId, theirs, dirty: false));
      case MergeAction.keepLocal:
        return Future.value();
      case MergeAction.keepLocalMarkDirty:
        return (update(userItemStates)..where(
              (s) => s.userId.equals(userId) & s.itemId.equals(theirs.itemId),
            ))
            .write(const UserItemStatesCompanion(dirty: Value(true)));
    }
  }

  static UserItemStatesCompanion _stateCompanion(
    String userId,
    ItemState s, {
    required bool dirty,
  }) => UserItemStatesCompanion.insert(
    userId: userId,
    itemId: s.itemId,
    deckId: s.deckId,
    due: s.due.toUtc(),
    stability: s.stability,
    difficulty: s.difficulty,
    elapsedDays: s.elapsedDays,
    scheduledDays: s.scheduledDays,
    reps: s.reps,
    lapses: s.lapses,
    state: s.state.code,
    lastReview: Value(s.lastReview?.toUtc()),
    lastQuestionId: Value(s.lastQuestionId),
    updatedAt: s.updatedAt.toUtc(),
    dirty: Value(dirty),
  );

  static ReviewLogsCompanion _logCompanion(
    String userId,
    ReviewLog log, {
    DateTime? syncedAt,
  }) => ReviewLogsCompanion.insert(
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
    syncedAt: Value(syncedAt),
  );

  static ReviewLog _logFromRow(ReviewLogRow r) => ReviewLog(
    id: r.id,
    deckId: r.deckId,
    deckVersion: r.deckVersion,
    itemId: r.itemId,
    questionId: r.questionId,
    questionType: QuestionType.fromWire(r.questionType),
    rating: Rating.fromCode(r.rating),
    gradeSource: GradeSource.fromWire(r.gradeSource),
    llmScore: r.llmScore,
    answerText: r.answerText,
    durationMs: r.durationMs,
    reviewedAt: r.reviewedAt.toUtc(),
  );

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
