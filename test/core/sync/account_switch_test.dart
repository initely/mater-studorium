// Смена пользователя на устройстве (ADR-30): перенос данных потерянного
// анонимного аккаунта и отказ переносить в остальных случаях.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/sync/domain/account_switch_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_store.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';

void main() {
  const anonA = AuthUser(id: userA, isAnonymous: true);
  const anonB = AuthUser(id: userB, isAnonymous: true);
  const googleA = AuthUser(id: userA, isAnonymous: false);
  const googleB = AuthUser(id: userB, isAnonymous: false);

  test('правило переноса', () {
    expect(shouldAdoptLocalData(previous: anonA, current: anonB), isTrue);
    expect(shouldAdoptLocalData(previous: anonA, current: anonA), isFalse);
    expect(shouldAdoptLocalData(previous: googleA, current: anonB), isFalse);
    expect(shouldAdoptLocalData(previous: anonA, current: googleB), isFalse);
    expect(shouldAdoptLocalData(previous: googleA, current: googleB), isFalse);
  });

  late FakeSyncServer server;
  setUp(
    () => server = FakeSyncServer(
      now: () => s0.add(const Duration(hours: 1)),
      sessionUserId: userA,
    ),
  );

  test('потерянный анонимный аккаунт: данные переносятся на новый и '
      'уходят на сервер под ним', () async {
    final d = Device(server);
    final switcher = AccountSwitchHandler(
      store: d.db.syncDao,
      sync: d.service,
      intents: d.db.syncDao,
      clock: () => s0.add(const Duration(hours: 1)),
    );
    await switcher.onSignedIn(anonA);
    final sent = await answer(d.db, userA, 'i1', s0);
    await d.service.sync(); // i1 и его лог уже на сервере под A
    final unsent = await answer(d.db, userA, 'i2', s0);
    await d.db.reviewDao.enqueueOutbox(
      userA,
      OutboxEntry(kind: OutboxKind.report, payloadJson: '{}', createdAt: s0),
    );

    // Refresh token отозван: новый анонимный вход B.
    d.user = userB;
    server.sessionUserId = userB;
    await switcher.onSignedIn(anonB);

    expect(await d.db.syncDao.lastOwner(), anonB);
    final states = await d.db.select(d.db.userItemStates).get();
    expect(states.map((s) => (s.userId, s.itemId, s.dirty)).toSet(), {
      (userB, 'i1', true),
      (userB, 'i2', true),
    });
    final logs = {for (final l in await d.logs()) l.id: l};
    expect(logs[sent.id]!.userId, userB);
    expect(logs[sent.id]!.syncedAt, isNotNull, reason: 'уже на сервере');
    expect(logs[unsent.id]!.syncedAt, isNull);
    expect((await d.db.select(d.db.outbox).getSingle()).userId, userB);
    expect(await d.db.syncDao.cursor(userA, SyncStream.itemStates), 0);

    final report = await d.service.sync();
    expect(report.isSuccess, isTrue);
    expect(server.stateOf(userB, 'i1'), isNotNull);
    expect(server.stateOf(userB, 'i2'), isNotNull);
    expect(server.logsOf(userB).map((l) => l.id), [unsent.id]);
  });

  test('при совпадении знания остаётся более позднее состояние', () async {
    final d = Device(server);
    await answer(d.db, userA, 'i1', s0, reps: 5);
    await answer(d.db, userA, 'i2', s0.add(const Duration(hours: 2)), reps: 6);
    await answer(d.db, userB, 'i1', s0.add(const Duration(hours: 1)), reps: 1);
    await answer(d.db, userB, 'i2', s0.add(const Duration(hours: 1)), reps: 2);

    await d.service.adoptLocalData(from: userA, to: userB);

    final rows = await d.db.select(d.db.userItemStates).get();
    expect(
      {for (final r in rows) (r.userId, r.itemId): r.reps},
      {(userB, 'i1'): 1, (userB, 'i2'): 6},
    );
  });

  test('прежний аккаунт не анонимный: данные не переносятся и не уходят '
      'под чужой сессией', () async {
    final d = Device(server);
    final switcher = AccountSwitchHandler(
      store: d.db.syncDao,
      sync: d.service,
      intents: d.db.syncDao,
      clock: () => s0.add(const Duration(hours: 1)),
    );
    await switcher.onSignedIn(googleA);
    await answer(d.db, userA, 'i1', s0);

    d.user = userB;
    server.sessionUserId = userB;
    await switcher.onSignedIn(anonB);

    expect((await d.state('i1', user: userA))!.dirty, isTrue);
    expect(await d.state('i1', user: userB), isNull);
    final report = await d.service.sync();
    expect((report.logsPushed, report.statesPushed), (0, 0));
    expect(server.states, isEmpty);
    expect(await d.db.syncDao.lastOwner(), anonB);
  });

  test('первый вход на устройстве и повтор того же пользователя: ничего не '
      'переносится', () async {
    final d = Device(server);
    final switcher = AccountSwitchHandler(
      store: d.db.syncDao,
      sync: d.service,
      intents: d.db.syncDao,
      clock: () => s0.add(const Duration(hours: 1)),
    );
    await answer(d.db, userB, 'i1', s0);
    await switcher.onSignedIn(anonA);
    await switcher.onSignedIn(anonA);
    expect(await d.state('i1', user: userB), isNotNull);
    expect(await d.state('i1', user: userA), isNull);
  });
}
