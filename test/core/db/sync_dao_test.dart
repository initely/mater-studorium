// SyncDao: записи синхронизации не выходят за пределы своего user_id, курсор
// pull не уменьшается.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/core/sync/domain/sync_store.dart';

import '../../helpers/db_fixtures.dart';
import '../../helpers/sync_fixtures.dart';

void main() {
  test('markLogsSynced трогает только логи своего пользователя', () async {
    final db = memoryDb();
    final a = await answer(db, userA, 'i1', s0);

    await db.syncDao.markLogsSynced(userB, [a.id], s0);

    expect((await db.select(db.reviewLogs).getSingle()).syncedAt, isNull);
    await db.syncDao.markLogsSynced(userA, [a.id], s0);
    expect((await db.select(db.reviewLogs).getSingle()).syncedAt, isNotNull);
  });

  test('insertPulledLogs не помечает и не перезаписывает чужой лог с тем же '
      'id', () async {
    final db = memoryDb();
    final a = await answer(db, userA, 'i1', s0);

    await db.syncDao.insertPulledLogs(
      userB,
      [a.copyWith(itemId: 'other')],
      cursor: 5,
      syncedAt: s0,
    );

    final row = await db.select(db.reviewLogs).getSingle();
    expect((row.userId, row.itemId, row.syncedAt), (userA, 'i1', null));
    expect(await db.syncDao.cursor(userB, SyncStream.reviewLogs), 5);
    expect(await db.syncDao.cursor(userA, SyncStream.reviewLogs), 0);
  });

  test('курсор pull не уменьшается (состояния и логи)', () async {
    final db = memoryDb();
    await db.syncDao.mergePulledStates(userA, const [], cursor: 10);
    await db.syncDao.mergePulledStates(userA, const [], cursor: 3);
    expect(await db.syncDao.cursor(userA, SyncStream.itemStates), 10);

    await db.syncDao.insertPulledLogs(userA, const [], cursor: 8, syncedAt: s0);
    await db.syncDao.insertPulledLogs(userA, const [], cursor: 2, syncedAt: s0);
    expect(await db.syncDao.cursor(userA, SyncStream.reviewLogs), 8);
  });

  test('adoptLocalData не переносит ответы дуэли на нового пользователя, '
      'остальной outbox переносит', () async {
    final db = memoryDb();
    await db.reviewDao.enqueueOutbox(
      userA,
      OutboxEntry(
        kind: OutboxKind.duelAnswer,
        payloadJson: '{}',
        createdAt: s0,
      ),
    );
    await db.reviewDao.enqueueOutbox(
      userA,
      OutboxEntry(kind: OutboxKind.report, payloadJson: '{}', createdAt: s0),
    );

    await db.syncDao.adoptLocalData(from: userA, to: userB);

    final rows = await db.select(db.outbox).get();
    expect(rows.map((r) => (r.userId, r.kind)).toList(), [
      (userB, OutboxKind.report),
    ]);
    expect(
      await db.reviewDao.pendingOutboxOfKind(userA, OutboxKind.duelAnswer),
      isEmpty,
    );
    expect(
      await db.reviewDao.pendingOutboxOfKind(userB, OutboxKind.duelAnswer),
      isEmpty,
    );
  });
}
