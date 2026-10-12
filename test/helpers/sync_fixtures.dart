import 'dart:math';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/sync/domain/outbox_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_remote.dart';
import 'package:mater_studorium/core/sync/domain/sync_service.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

import 'db_fixtures.dart';

const userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

/// Время с точностью до секунды: так его хранит drift (unix-секунды).
final s0 = DateTime.utc(2026, 10, 12, 10);

final _random = Random(17);
String newUuid() => generateUuidV4(_random);

ItemState syncState(String item, DateTime at, {int reps = 1}) => ItemState(
  itemId: item,
  deckId: 'infosec',
  due: at.add(const Duration(days: 1)),
  stability: 2.3,
  difficulty: 5.1,
  elapsedDays: 0,
  scheduledDays: 1,
  reps: reps,
  lapses: 0,
  state: SrsState.review,
  lastReview: at,
  lastQuestionId: '$item.q1',
  updatedAt: at,
);

ReviewLog syncLog(String item, DateTime at, {String? id}) => ReviewLog(
  id: id ?? newUuid(),
  deckId: 'infosec',
  deckVersion: 1,
  itemId: item,
  questionId: '$item.q1',
  questionType: QuestionType.mcq,
  rating: Rating.good,
  gradeSource: GradeSource.auto,
  durationMs: 1200,
  reviewedAt: at,
);

/// Ответ, записанный как в сессии: лог и состояние (dirty) одной
/// транзакцией. Возвращает лог.
Future<ReviewLog> answer(
  AppDatabase db,
  String user,
  String item,
  DateTime at, {
  int reps = 1,
}) async {
  final log = syncLog(item, at);
  await db.reviewDao.recordReview(
    userId: user,
    log: log,
    state: syncState(item, at, reps: reps),
  );
  return log;
}

/// Устройство: своя локальная БД и SyncService поверх неё и [remote].
class Device {
  Device(
    SyncRemote remote, {
    this.user = userA,
    DateTime Function()? clock,
    int pushBatchSize = 200,
    int pullPageSize = 500,
    OutboxHandlers outboxHandlers = const {},
  }) : db = memoryDb() {
    service = SyncService(
      remote: remote,
      store: db.syncDao,
      currentUserId: () => user,
      clock: clock ?? () => s0.add(const Duration(hours: 1)),
      outboxHandlers: outboxHandlers,
      pushBatchSize: pushBatchSize,
      pullPageSize: pullPageSize,
    );
  }

  final AppDatabase db;
  late final SyncService service;

  /// Текущий пользователь сессии; `null` — сессии нет.
  String? user;

  Future<List<ReviewLogRow>> logs() => db.select(db.reviewLogs).get();

  Future<UserItemStateRow?> state(String item, {String? user}) =>
      (db.select(db.userItemStates)..where(
            (s) => s.userId.equals(user ?? this.user!) & s.itemId.equals(item),
          ))
          .getSingleOrNull();
}
