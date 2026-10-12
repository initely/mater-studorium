// SyncDao: записи синхронизации не выходят за пределы своего user_id, курсор
// pull не уменьшается.
import 'package:flutter_test/flutter_test.dart';
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
}
