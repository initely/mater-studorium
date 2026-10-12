// SyncService на drift в памяти и фейковом сервере с семантикой
// 0003_sync.sql (test/helpers/fake_sync_server.dart). Время — секундной
// точности, как его хранит drift.
import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/domain/sync_report.dart';
import 'package:mater_studorium/core/sync/domain/sync_store.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';

void main() {
  late FakeSyncServer server;

  // Два «устройства» = две разные БД в памяти; предупреждение drift о
  // нескольких экземплярах AppDatabase здесь ложное.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

  setUp(() {
    server = FakeSyncServer(
      now: () => s0.add(const Duration(hours: 1)),
      sessionUserId: userA,
    );
  });

  test('успех: логи и состояния на сервере, локально помечены', () async {
    final d = Device(server);
    for (final item in ['i1', 'i2', 'i3']) {
      await answer(d.db, userA, item, s0);
    }

    final report = await d.service.sync();

    expect(report.outcome, SyncOutcome.success);
    expect((report.logsPushed, report.statesPushed), (3, 3));
    expect(server.logsOf(userA), hasLength(3));
    expect(server.stateOf(userA, 'i2'), syncState('i2', s0));
    expect((await d.logs()).every((l) => l.syncedAt != null), isTrue);
    for (final item in ['i1', 'i2', 'i3']) {
      expect((await d.state(item))!.dirty, isFalse);
    }

    // Второй прогон ничего не отправляет.
    server.callLog.clear();
    final again = await d.service.sync();
    expect((again.logsPushed, again.statesPushed), (0, 0));
    expect(server.callLog, ['pullItemStates', 'pullReviewLogs']);
  });

  test('AC8.1: 20 ответов без сети, затем сеть — все логи на сервере, '
      'дублей нет', () async {
    final d = Device(server, pushBatchSize: 7);
    server.offline = true;
    for (var i = 0; i < 20; i++) {
      await answer(d.db, userA, 'i$i', s0.add(Duration(seconds: i)));
      // Прогоны во время «авиарежима» (триггеры по таймеру) — тихо.
      final r = await d.service.sync();
      expect(r.outcome, SyncOutcome.offline);
      expect(r.error, isA<NetworkError>());
    }
    expect((await d.logs()).where((l) => l.syncedAt != null), isEmpty);

    server.offline = false;
    final report = await d.service.sync();

    expect(report.outcome, SyncOutcome.success);
    expect(report.logsPushed, 20);
    final onServer = server.logsOf(userA);
    expect(onServer, hasLength(20));
    expect(onServer.map((l) => l.id).toSet(), hasLength(20));
    expect(
      onServer.map((l) => l.id).toSet(),
      (await d.logs()).map((l) => l.id).toSet(),
    );
    expect((await d.logs()).every((l) => l.syncedAt != null), isTrue);
  });

  test('сбой сети на середине: отправленное помечено, остальное ждёт; '
      'повтор досылает без дублей', () async {
    final d = Device(server, pushBatchSize: 5);
    for (var i = 0; i < 12; i++) {
      await answer(d.db, userA, 'i$i', s0.add(Duration(seconds: i)));
    }
    server.failBefore.add(2); // второй пакет логов

    final first = await d.service.sync();

    expect(first.outcome, SyncOutcome.offline);
    expect(first.logsPushed, 5);
    expect(server.logsOf(userA), hasLength(5));
    expect((await d.logs()).where((l) => l.syncedAt != null), hasLength(5));
    // Состояния ещё не отправлялись: dirty.
    expect((await d.state('i0'))!.dirty, isTrue);

    final second = await d.service.sync();
    expect(second.outcome, SyncOutcome.success);
    expect(second.logsPushed, 7);
    expect(server.logsOf(userA), hasLength(12));
    expect((await d.logs()).every((l) => l.syncedAt != null), isTrue);
  });

  test('частичный успех: сервер записал, ответ потерян — локально не '
      'помечено; повтор того же пакета безопасен', () async {
    final d = Device(server);
    for (final item in ['i1', 'i2']) {
      await answer(d.db, userA, item, s0);
    }
    server.failAfter.addAll({1, 2}); // логи и состояния записаны, ответ потерян

    final first = await d.service.sync();
    expect(first.outcome, SyncOutcome.offline);
    expect(server.logsOf(userA), hasLength(2));
    expect((await d.logs()).where((l) => l.syncedAt != null), isEmpty);

    // Второй прогон: те же логи снова (сервер ничего нового не вставил),
    // затем состояния.
    server.failAfter.clear();
    final second = await d.service.sync();
    expect(second.outcome, SyncOutcome.success);
    expect(server.logsOf(userA), hasLength(2));
    expect((await d.logs()).every((l) => l.syncedAt != null), isTrue);
  });

  test('состояние записано, ответ потерян: повтор (равный updatedAt) '
      'снимает dirty', () async {
    final d = Device(server);
    await answer(d.db, userA, 'i1', s0);
    // 1 — логи, 2 — состояния (ответ потерян).
    server.failAfter.add(2);

    expect((await d.service.sync()).outcome, SyncOutcome.offline);
    expect(server.stateOf(userA, 'i1'), syncState('i1', s0));
    expect((await d.state('i1'))!.dirty, isTrue);

    expect((await d.service.sync()).outcome, SyncOutcome.success);
    expect((await d.state('i1'))!.dirty, isFalse);
  });

  group('LWW (AC8.2)', () {
    test('два устройства, разные ответы по одному знанию: остаётся более '
        'позднее, оба устройства сходятся к нему', () async {
      final d1 = Device(server);
      final d2 = Device(server);
      final t1 = s0;
      final t2 = s0.add(const Duration(minutes: 3));
      await answer(d1.db, userA, 'i1', t1, reps: 5);
      await answer(d2.db, userA, 'i1', t2, reps: 7);

      // Более позднее приходит первым, более раннее — вторым.
      expect((await d2.service.sync()).outcome, SyncOutcome.success);
      expect((await d1.service.sync()).outcome, SyncOutcome.success);

      expect(server.stateOf(userA, 'i1')!.updatedAt, t2);
      expect(server.stateOf(userA, 'i1')!.reps, 7);
      // Устройство 1: его состояние отклонено, взято серверное, dirty снят.
      final local1 = (await d1.state('i1'))!;
      expect(
        (local1.updatedAt.toUtc(), local1.reps, local1.dirty),
        (t2, 7, false),
      );
      // Логи обоих устройств на сервере (журнал не LWW).
      expect(server.logsOf(userA), hasLength(2));
      // Устройство 1 получило лог устройства 2 (pull), отмеченным.
      expect(await d1.logs(), hasLength(2));
    });

    test('обратный порядок: раннее первым, позднее перезаписывает; первое '
        'устройство получает его при pull', () async {
      final d1 = Device(server);
      final d2 = Device(server);
      final t2 = s0.add(const Duration(minutes: 3));
      await answer(d1.db, userA, 'i1', s0, reps: 5);
      await answer(d2.db, userA, 'i1', t2, reps: 7);

      await d1.service.sync();
      await d2.service.sync();
      expect(server.stateOf(userA, 'i1')!.reps, 7);

      final report = await d1.service.sync();
      expect(report.statesPulled, 1);
      expect((await d1.state('i1'))!.reps, 7);
    });

    test(
      'равные updatedAt: побеждает серверная строка (как на сервере)',
      () async {
        final d1 = Device(server);
        final d2 = Device(server);
        await answer(d1.db, userA, 'i1', s0, reps: 5);
        await answer(d2.db, userA, 'i1', s0, reps: 9);

        await d1.service.sync();
        await d2.service.sync();

        expect(server.stateOf(userA, 'i1')!.reps, 5);
        expect((await d2.state('i1'))!.reps, 5);
        expect((await d2.state('i1'))!.dirty, isFalse);
      },
    );

    test('pull не затирает более новое несинхронизированное локальное '
        'состояние', () async {
      final d = Device(server);
      server.putState(userA, syncState('i1', s0, reps: 3));
      server.offline = true;
      final local = s0.add(const Duration(minutes: 10));
      await answer(d.db, userA, 'i1', local, reps: 4);
      server.offline = false;
      // Push отправит локальное (новее) раньше pull.
      server.failBefore.add(server.calls + 2); // состояния не дошли

      expect((await d.service.sync()).outcome, SyncOutcome.offline);
      // Прямой pull: локальное новее серверного — остаётся, dirty.
      await d.db.syncDao.mergePulledStates(userA, [
        syncState('i1', s0, reps: 3),
      ], cursor: 1);
      final row = (await d.state('i1'))!;
      expect((row.reps, row.dirty), (4, true));

      expect((await d.service.sync()).outcome, SyncOutcome.success);
      expect(server.stateOf(userA, 'i1')!.reps, 4);
    });

    test('новый ответ во время отправки не теряется: dirty остаётся, '
        'уходит следующим прогоном', () async {
      final d = Device(server);
      await answer(d.db, userA, 'i1', s0, reps: 1);
      final held = server.hold('upsertItemStates');
      final run = d.service.sync();
      await held.reached.future;
      // Пока состояния «в полёте», пользователь ответил снова.
      final later = s0.add(const Duration(minutes: 5));
      await answer(d.db, userA, 'i1', later, reps: 2);
      held.release.complete();
      final report = await run;
      expect(report.outcome, SyncOutcome.success);
      expect(server.stateOf(userA, 'i1')!.reps, 1);

      final row = (await d.state('i1'))!;
      // Сервер принял reps 1, но локально уже reps 2 — новее, dirty.
      expect((row.reps, row.dirty), (2, true));

      await d.service.sync();
      expect(server.stateOf(userA, 'i1')!.reps, 2);
      expect((await d.state('i1'))!.dirty, isFalse);
    });

    test('часы устройства спешат на сутки: сервер зажимает updatedAt, '
        'устройство принимает зажатое значение', () async {
      final d = Device(server);
      final serverNow = server.now();
      final future = serverNow.add(const Duration(days: 1));
      await answer(d.db, userA, 'i1', future, reps: 3);

      await d.service.sync();

      final clamped = serverNow.add(const Duration(minutes: 2));
      expect(server.stateOf(userA, 'i1')!.updatedAt, clamped);
      final row = (await d.state('i1'))!;
      expect((row.updatedAt.toUtc(), row.dirty, row.reps), (clamped, false, 3));

      // Нормальное устройство после окна допуска побеждает.
      server.now = () => serverNow.add(const Duration(minutes: 10));
      final d2 = Device(server);
      await answer(
        d2.db,
        userA,
        'i1',
        serverNow.add(const Duration(minutes: 9)),
        reps: 4,
      );
      await d2.service.sync();
      expect(server.stateOf(userA, 'i1')!.reps, 4);
    });
  });

  test('параллельные вызовы: не больше одного прогона одновременно, '
      'вызовы во время прогона сливаются в один следующий', () async {
    final d = Device(server);
    await answer(d.db, userA, 'i1', s0);
    final gate = Completer<void>();
    server.gate = gate;

    final first = d.service.sync();
    await pumpEventQueue();
    // Записано во время прогона: обязано уйти следующим.
    await answer(d.db, userA, 'i2', s0.add(const Duration(seconds: 1)));
    final others = [for (var i = 0; i < 5; i++) d.service.sync()];
    expect(others.toSet(), hasLength(1), reason: 'один следующий прогон');

    gate.complete();
    server.gate = null;
    final reports = await Future.wait([first, ...others]);

    expect(server.maxInFlight, 1);
    expect(reports.every((r) => r.isSuccess), isTrue);
    expect(server.logsOf(userA), hasLength(2));
    expect(server.stateOf(userA, 'i2'), isNotNull);
    // Ровно два прогона: 2 × (логи, состояния, 2 pull) + второй с 1 логом.
    expect(server.callLog.where((c) => c == 'pullItemStates'), hasLength(2));
  });

  group('пользователи', () {
    test('нет сессии: noSession, сервер не трогается', () async {
      final d = Device(server)..user = null;
      final report = await d.service.sync();
      expect(report.outcome, SyncOutcome.noSession);
      expect(server.calls, 0);
    });

    test('смена пользователя во время прогона: прогон прерван, данные A не '
        'ушли под сессией B', () async {
      final d = Device(server, pushBatchSize: 2);
      for (var i = 0; i < 4; i++) {
        await answer(d.db, userA, 'i$i', s0.add(Duration(seconds: i)));
      }
      final gate = Completer<void>();
      server.gate = gate;
      final run = d.service.sync();
      await pumpEventQueue();
      // Выход и анонимный вход B, пока первый пакет «в полёте».
      d.user = userB;
      server.sessionUserId = userB;
      server.gate = null;
      gate.complete();

      final report = await run;
      expect(report.outcome, SyncOutcome.authFailed);
      expect(server.logsOf(userB), isEmpty);
      expect(server.states.keys.where((k) => k.$1 == userB), isEmpty);
      // Неотправленное A так и лежит под A.
      expect(
        (await d.logs()).where((l) => l.userId == userA && l.syncedAt == null),
        hasLength(4),
      );

      // Прогон B не трогает строки A.
      final b = await d.service.sync();
      expect(b.outcome, SyncOutcome.success);
      expect((b.logsPushed, b.statesPushed), (0, 0));
      expect(server.logsOf(userB), isEmpty);
    });

    test('пользователь сменился между шагами: прогон останавливается до '
        'следующего сетевого шага', () async {
      final d = Device(server);
      await answer(d.db, userA, 'i1', s0);
      final held = server.hold('insertReviewLogs');
      final run = d.service.sync();
      await held.reached.future;
      d.user = userB; // сервер ещё «видит» прежний JWT
      held.release.complete();

      final report = await run;
      expect(report.outcome, SyncOutcome.authFailed);
      expect(server.callLog, ['insertReviewLogs']);
    });

    test('сервер отвечает AuthError (сессия другого пользователя): '
        'authFailed, ничего не помечено', () async {
      final d = Device(server);
      await answer(d.db, userA, 'i1', s0);
      server.sessionUserId = userB;
      final report = await d.service.sync();
      expect(report.outcome, SyncOutcome.authFailed);
      expect((await d.logs()).single.syncedAt, isNull);
    });
  });

  test('строки, которые сервер не примет, не отправляются и не мешают '
      'остальным', () async {
    final d = Device(server, pushBatchSize: 2);
    // id не uuid — сервер отклонил бы весь пакет.
    await d.db.reviewDao.recordReview(
      userId: userA,
      log: syncLog('i0', s0, id: 'log-1'),
      state: syncState('i0', s0).copyWith(difficulty: 11),
    );
    for (var i = 1; i < 4; i++) {
      await answer(d.db, userA, 'i$i', s0.add(Duration(seconds: i)));
    }
    final report = await d.service.sync();

    expect(report.outcome, SyncOutcome.success);
    expect(report.skippedInvalid, 2);
    expect(server.logsOf(userA), hasLength(3));
    expect(server.stateOf(userA, 'i0'), isNull);
    expect(server.stateOf(userA, 'i3'), isNotNull);
    final bad = (await d.logs()).singleWhere((l) => l.id == 'log-1');
    expect(bad.syncedAt, isNull, reason: 'остаётся локально, не потеряна');
  });

  test('длинный ответ и длительность нормализуются при отправке, локально '
      'не меняются', () async {
    final d = Device(server);
    final log = syncLog(
      'i1',
      s0,
    ).copyWith(durationMs: 3 * 86400000, answerText: 'я' * 5000);
    await d.db.reviewDao.recordReview(
      userId: userA,
      log: log,
      state: syncState('i1', s0),
    );
    await d.service.sync();
    final sent = server.logsOf(userA).single;
    expect((sent.durationMs, sent.answerText!.length), (86400000, 4000));
    expect((await d.logs()).single.durationMs, 3 * 86400000);
  });

  group('pull', () {
    test('страницы по курсору; курсор сохраняется, повтор ничего не '
        'тянет', () async {
      for (var i = 0; i < 1200; i++) {
        server.putState(userA, syncState('p$i', s0));
      }
      final d = Device(server, pullPageSize: 500);
      final report = await d.service.sync();
      expect(report.statesPulled, 1200);
      expect(await d.db.select(d.db.userItemStates).get(), hasLength(1200));
      expect(
        (await d.db.select(d.db.userItemStates).get()).any((s) => s.dirty),
        isFalse,
      );
      expect(server.callLog.where((c) => c == 'pullItemStates'), hasLength(3));
      expect(await d.db.syncDao.cursor(userA, SyncStream.itemStates), 1200);

      server.callLog.clear();
      final again = await d.service.sync();
      expect(again.statesPulled, 0);
      expect(server.callLog.where((c) => c == 'pullItemStates'), hasLength(1));
    });

    test('логи с сервера вставляются отправленными; свой неотмеченный лог '
        'отмечается', () async {
      final d = Device(server);
      final mine = await answer(d.db, userA, 'i1', s0);
      server.putLog(userA, mine); // дошёл раньше, ответ потерялся
      server.putLog(userA, syncLog('i2', s0));
      // Отправка логов «не дошла», pull — дошёл.
      server.failBefore.add(1);
      expect((await d.service.sync()).outcome, SyncOutcome.offline);
      expect((await d.logs()).single.syncedAt, isNull);
      expect(server.logsOf(userA), hasLength(2));

      final report = await d.service.sync();
      expect(report.logsPulled, 2);
      final logs = await d.logs();
      expect(logs, hasLength(2));
      expect(logs.every((l) => l.syncedAt != null), isTrue);
    });

    test('чужие строки на сервере не приходят', () async {
      server.putState(userB, syncState('b1', s0));
      server.putLog(userB, syncLog('b1', s0));
      final d = Device(server);
      final r = await d.service.sync();
      expect((r.statesPulled, r.logsPulled), (0, 0));
    });
  });

  group('outbox', () {
    test('обработчик по kind; без обработчика — остаётся; ошибка — '
        'attempts++, прогон идёт дальше', () async {
      final sent = <String>[];
      var failFirst = true;
      final d = Device(
        server,
        outboxHandlers: {
          OutboxKind.report: (userId, entry) async {
            expect(userId, userA);
            if (entry.payloadJson == 'bad' && failFirst) {
              failFirst = false;
              throw const SyncRejectedError('bad');
            }
            sent.add(entry.payloadJson);
          },
        },
      );
      OutboxEntry e(OutboxKind kind, String p) =>
          OutboxEntry(kind: kind, payloadJson: p, createdAt: s0);
      await d.db.reviewDao.enqueueOutbox(userA, e(OutboxKind.report, 'bad'));
      await d.db.reviewDao.enqueueOutbox(userA, e(OutboxKind.report, 'r1'));
      await d.db.reviewDao.enqueueOutbox(userA, e(OutboxKind.duelAnswer, 'd1'));
      await d.db.reviewDao.enqueueOutbox(userB, e(OutboxKind.report, 'b1'));

      final report = await d.service.sync();
      expect(report.outcome, SyncOutcome.success);
      expect(report.outboxSent, 1);
      expect(sent, ['r1']);
      final left = await d.db.select(d.db.outbox).get();
      expect(
        {for (final o in left) o.payloadJson: o.attempts},
        {'bad': 1, 'd1': 0, 'b1': 0},
      );

      await d.service.sync();
      expect(sent, ['r1', 'bad']);
    });

    test('сетевая ошибка обработчика останавливает прогон, запись '
        'остаётся', () async {
      final d = Device(
        server,
        outboxHandlers: {
          OutboxKind.report: (_, _) async => throw const NetworkError('x'),
        },
      );
      await d.db.reviewDao.enqueueOutbox(
        userA,
        OutboxEntry(kind: OutboxKind.report, payloadJson: '{}', createdAt: s0),
      );
      final report = await d.service.sync();
      expect(report.outcome, SyncOutcome.offline);
      expect((await d.db.select(d.db.outbox).getSingle()).attempts, 0);
    });
  });

  test('ошибка локальной БД: failed, без исключения наружу', () async {
    final d = Device(server);
    await d.db.customStatement('DROP TABLE sync_cursors');
    final report = await d.service.sync();
    expect(report.outcome, SyncOutcome.failed);
    expect(report.error, isA<AppError>());
  });

  test('после failed прогоны продолжаются (замок освобождён)', () async {
    final d = Device(server);
    server.offline = true;
    await d.service.sync();
    server.offline = false;
    await answer(d.db, userA, 'i1', s0);
    expect((await d.service.sync()).isSuccess, isTrue);
  });
}
