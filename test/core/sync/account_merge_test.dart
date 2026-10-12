// Привязка Google и вход в существующий аккаунт: что происходит с локальным
// прогрессом (T21, ADR-34). Ничего не теряется и ничего не уходит под чужой
// user_id.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/db/sync_dao.dart';
import 'package:mater_studorium/core/sync/domain/account_switch_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_store.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/features/auth/domain/account_intent.dart';
import 'package:mater_studorium/features/auth/domain/auth_user.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';

void main() {
  // A: анонимный аккаунт этого устройства, B: существующий аккаунт Google.
  const anonA = AuthUser(id: userA, isAnonymous: true);
  const googleA = AuthUser(
    id: userA,
    isAnonymous: false,
    email: 'a@example.com',
  );
  const googleB = AuthUser(
    id: userB,
    isAnonymous: false,
    email: 'b@example.com',
  );
  const anonC = AuthUser(
    id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    isAnonymous: true,
  );
  final now = s0.add(const Duration(hours: 1));

  late FakeSyncServer server;
  late Device d;
  late AccountSwitchHandler switcher;

  setUp(() {
    server = FakeSyncServer(now: () => now, sessionUserId: userA);
    d = Device(server);
    switcher = AccountSwitchHandler(
      store: d.db.syncDao,
      sync: d.service,
      intents: d.db.syncDao,
      clock: () => now,
    );
  });

  AccountIntent intent(
    AccountIntentKind kind, {
    String from = userA,
    Duration age = const Duration(minutes: 1),
  }) =>
      AccountIntent(kind: kind, fromUserId: from, createdAt: now.subtract(age));

  Future<void> signInAs(AuthUser user) async {
    d.user = user.id;
    server.sessionUserId = user.id;
    await switcher.onSignedIn(user);
  }

  /// Анонимный A отвечал на устройстве: i1 уже на сервере (под A), i2 ещё нет.
  Future<({String sentLogId, String unsentLogId})> anonymousProgress() async {
    await switcher.onSignedIn(anonA);
    final sent = await answer(d.db, userA, 'i1', s0);
    await d.service.sync();
    final unsent = await answer(d.db, userA, 'i2', s0);
    await d.db.reviewDao.enqueueOutbox(
      userA,
      OutboxEntry(kind: OutboxKind.report, payloadJson: '{}', createdAt: s0),
    );
    return (sentLogId: sent.id, unsentLogId: unsent.id);
  }

  group('вход в существующий аккаунт с подтверждённым объединением', () {
    test('локальный прогресс переходит на B и уходит на сервер под B; '
        'более поздняя запись сервера не затирается', () async {
      final ids = await anonymousProgress();
      // В аккаунте B на сервере: i1 новее нашего (reps 9) и i3, которого у нас нет.
      server.putState(
        userB,
        syncState('i1', s0.add(const Duration(minutes: 30)), reps: 9),
      );
      server.putState(userB, syncState('i3', s0));
      final serverA = server.stateOf(userA, 'i1')!;
      await d.db.syncDao.writeIntent(intent(AccountIntentKind.merge));

      await signInAs(googleB);

      // Локально: всё принадлежит B, у A ничего нет, намерение израсходовано.
      final rows = await d.db.select(d.db.userItemStates).get();
      expect(rows.map((r) => (r.userId, r.itemId, r.dirty)).toSet(), {
        (userB, 'i1', true),
        (userB, 'i2', true),
      });
      expect(await d.db.syncDao.readIntent(), isNull);
      expect(await d.db.syncDao.lastOwner(), googleB);
      expect((await d.db.select(d.db.outbox).getSingle()).userId, userB);
      final logs = {for (final l in await d.logs()) l.id: l};
      expect(logs[ids.sentLogId]!.userId, userB);
      expect(logs[ids.unsentLogId]!.userId, userB);

      final report = await d.service.sync();
      expect(report.isSuccess, isTrue);

      // На сервере у B: i2 дошёл, i1 остался более поздним серверным, i3 пришёл
      // на устройство.
      expect(server.stateOf(userB, 'i2'), isNotNull);
      expect(server.stateOf(userB, 'i1')!.reps, 9);
      expect((await d.state('i3', user: userB)), isNotNull);
      expect((await d.state('i1', user: userB))!.reps, 9);
      // Неотправленный лог ушёл под B; отправленный остался у A (id занят).
      expect(server.logsOf(userB).map((l) => l.id), [ids.unsentLogId]);
      expect(server.logsOf(userA).map((l) => l.id), [ids.sentLogId]);
      // Серверные данные A не тронуты и ничего нового под A не появилось.
      expect(server.stateOf(userA, 'i1'), serverA);
      expect(server.stateOf(userA, 'i2'), isNull);
    });

    test('локальное состояние новее серверного: побеждает локальное', () async {
      await switcher.onSignedIn(anonA);
      await answer(
        d.db,
        userA,
        'i1',
        s0.add(const Duration(minutes: 45)),
        reps: 7,
      );
      server.putState(userB, syncState('i1', s0, reps: 2));
      await d.db.syncDao.writeIntent(intent(AccountIntentKind.merge));

      await signInAs(googleB);
      await d.service.sync();

      expect(server.stateOf(userB, 'i1')!.reps, 7);
    });

    test('намерение расходуется: следующий вход без подтверждения не '
        'переносит ничего', () async {
      await anonymousProgress();
      await d.db.syncDao.writeIntent(intent(AccountIntentKind.merge));
      await signInAs(googleB);
      expect(await d.db.syncDao.readIntent(), isNull);

      // На устройство приходит анонимный C: B не анонимный, данные остаются
      // у B и не переходят на C.
      await signInAs(anonC);

      expect((await d.state('i2', user: userB)), isNotNull);
      expect((await d.state('i2', user: anonC.id)), isNull);
      expect((await d.service.sync()).statesPushed, 0);
    });
  });

  group(
    'без подтверждения данные не переходят и не уходят под чужой user_id',
    () {
      final cases = <String, AccountIntent?>{
        'намерения нет': null,
        'намерение только link (диалог не подтверждён)': intent(
          AccountIntentKind.link,
        ),
        'намерение merge просрочено': intent(
          AccountIntentKind.merge,
          age: AccountIntent.ttl + const Duration(seconds: 1),
        ),
        'намерение merge из будущего': intent(
          AccountIntentKind.merge,
          age: const Duration(minutes: -5),
        ),
        'намерение merge про другого пользователя': intent(
          AccountIntentKind.merge,
          from: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        ),
      };
      for (final entry in cases.entries) {
        test(entry.key, () async {
          await anonymousProgress();
          final stored = entry.value;
          if (stored != null) await d.db.syncDao.writeIntent(stored);
          final serverBefore = Map.of(server.states);

          await signInAs(googleB);

          // Прогресс остался под A, не отправлен, не показан B.
          expect((await d.state('i2', user: userA))!.dirty, isTrue);
          expect(await d.state('i2', user: userB), isNull);
          final report = await d.service.sync();
          expect((report.logsPushed, report.statesPushed), (0, 0));
          expect(server.states, serverBefore);
          expect(server.stateOf(userB, 'i2'), isNull);
          expect(server.logsOf(userB), isEmpty);
          // Входящий пользователь запомнен, незавершённое намерение закрыто.
          expect(await d.db.syncDao.lastOwner(), googleB);
          expect(await d.db.syncDao.readIntent(), isNull);
        });
      }

      test('прежний пользователь не анонимный: перенос запрещён даже с '
          'намерением', () async {
        await switcher.onSignedIn(googleA);
        await answer(d.db, userA, 'i1', s0);
        await d.db.syncDao.writeIntent(intent(AccountIntentKind.merge));

        await signInAs(googleB);

        expect(await d.state('i1', user: userA), isNotNull);
        expect(await d.state('i1', user: userB), isNull);
        expect((await d.service.sync()).statesPushed, 0);
      });

      test('вход анонимного C вместо merge в Google: действует прежнее правило '
          'ADR-30, намерение закрыто', () async {
        await anonymousProgress();
        await d.db.syncDao.writeIntent(intent(AccountIntentKind.merge));

        await signInAs(anonC);

        expect(await d.state('i2', user: anonC.id), isNotNull);
        expect(await d.db.syncDao.readIntent(), isNull);
      });
    },
  );

  group('привязка без конфликта (тот же id, аноним -> Google)', () {
    test('данные остаются под тем же user_id и синк продолжается', () async {
      await anonymousProgress();
      await d.db.syncDao.writeIntent(intent(AccountIntentKind.link));

      await signInAs(googleA);

      expect(await d.db.syncDao.readIntent(), isNull);
      expect(await d.db.syncDao.lastOwner(), googleA);
      final rows = await d.db.select(d.db.userItemStates).get();
      expect(rows.map((r) => r.userId).toSet(), {userA});

      final report = await d.service.sync();
      expect(report.isSuccess, isTrue);
      expect(server.stateOf(userA, 'i2'), isNotNull);
      expect(server.logsOf(userA), hasLength(2));
    });

    test('повтор прежнего пользователя (восстановление сессии на web до '
        'обмена кода) не трогает ожидающее намерение', () async {
      await switcher.onSignedIn(anonA);
      await d.db.syncDao.writeIntent(intent(AccountIntentKind.merge));

      await switcher.onSignedIn(anonA);

      expect(await d.db.syncDao.readIntent(), intent(AccountIntentKind.merge));
    });
  });

  group('правило shouldAdoptConfirmedMerge', () {
    bool rule({
      AuthUser previous = anonA,
      AuthUser current = googleB,
      AccountIntent? stored,
    }) => shouldAdoptConfirmedMerge(
      previous: previous,
      current: current,
      intent: stored ?? intent(AccountIntentKind.merge),
      now: now,
    );

    test('разрешает только свежий merge от прежнего анонимного пользователя '
        'к другому не анонимному', () {
      expect(rule(), isTrue);
    });

    test('все остальные сочетания запрещены', () {
      expect(rule(current: anonC), isFalse, reason: 'новый анонимный');
      expect(rule(previous: googleA), isFalse, reason: 'прежний не анонимный');
      expect(rule(current: googleA), isFalse, reason: 'тот же id');
      expect(rule(stored: intent(AccountIntentKind.link)), isFalse);
      expect(
        rule(stored: intent(AccountIntentKind.merge, from: userB)),
        isFalse,
      );
      expect(
        rule(
          stored: intent(
            AccountIntentKind.merge,
            age: AccountIntent.ttl + const Duration(milliseconds: 1),
          ),
        ),
        isFalse,
      );
      expect(
        shouldAdoptConfirmedMerge(
          previous: anonA,
          current: googleB,
          intent: null,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('хранилище намерения в drift', () {
    test('запись, чтение, замена, сброс', () async {
      final store = d.db.syncDao;
      expect(await store.readIntent(), isNull);

      await store.writeIntent(intent(AccountIntentKind.link));
      expect(await store.readIntent(), intent(AccountIntentKind.link));

      await store.writeIntent(intent(AccountIntentKind.merge));
      expect(await store.readIntent(), intent(AccountIntentKind.merge));

      await store.clearIntent();
      expect(await store.readIntent(), isNull);
    });

    for (final bad in [
      'не json',
      '{}',
      '{"kind":"hack","from":"x","at":"2026-10-12T10:00:00Z"}',
    ]) {
      test('битое значение «$bad» читается как отсутствие намерения', () async {
        await d.db
            .into(d.db.appSettings)
            .insert(
              AppSettingsCompanion(
                key: const Value(kAccountIntentSettingKey),
                value: Value(bad),
              ),
            );

        expect(await d.db.syncDao.readIntent(), isNull);
      });
    }
  });
}
