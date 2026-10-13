// Ответы дуэли через outbox и SyncService (T23, ADR-16, ADR-36): drift в
// памяти, сервер в памяти (FakeSyncServer с семантикой `submit_duel_answer`).
// Обработчик: что пробрасывается, что отбрасывается; «ядовитая» запись не
// блокирует очередь (урок T17); ответы дуэли не попадают в FSRS.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/domain/duel_answer_outbox_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_report.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_answer_queue.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';

import '../../helpers/duel_fixtures.dart';
import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';

const _duel2 = '00000000-0000-4000-8000-0000000000d2';

DuelAnswerPayload _a(
  int i, {
  String duelId = kDuelId,
  Map<String, Object?> answer = const {
    'selected': ['a'],
  },
  int ms = 1000,
}) => DuelAnswerPayload(
  duelId: duelId,
  questionId: duelQuestionIds()[i],
  answer: answer,
  isCorrect: true,
  durationMs: ms,
);

OutboxEntry _entry(DuelAnswerPayload a, {int attempts = 0}) => OutboxEntry(
  kind: OutboxKind.duelAnswer,
  payloadJson: jsonEncode(a.toJson()),
  createdAt: s0,
  attempts: attempts,
);

void main() {
  late FakeSyncServer server;

  setUp(() => server = FakeSyncServer(now: () => s0, sessionUserId: userA));

  group('обработчик', () {
    Future<void> run(OutboxEntry e) =>
        duelAnswerOutboxHandler(server)(userA, e);

    test('успех: ответ на сервере', () async {
      await run(_entry(_a(0)));
      expect(server.duelAnswers, hasLength(1));
    });

    test('повтор идемпотентен: второй вызов не ошибка и не дубль', () async {
      await run(_entry(_a(0)));
      await run(_entry(_a(0)));
      expect(server.duelAnswers, hasLength(1));
    });

    test('сеть и доступ пробрасываются при любом числе попыток', () async {
      for (final attempts in [0, 2, 10]) {
        server.offline = true;
        await expectLater(
          run(_entry(_a(0), attempts: attempts)),
          throwsA(isA<NetworkError>()),
        );
        server
          ..offline = false
          ..sessionUserId = userB;
        await expectLater(
          run(_entry(_a(0), attempts: attempts)),
          throwsA(isA<AuthError>()),
        );
        server.sessionUserId = userA;
      }
      expect(server.duelAnswers, isEmpty);
    });

    test('дуэль закрыта: запись отбрасывается сразу, без исключения', () async {
      server.closedDuels.add(kDuelId);
      await run(_entry(_a(0)));
      expect(server.duelAnswers, isEmpty);
    });

    test('отказ по значению: повтор, на третьей попытке отброс', () async {
      server.rejectDuelAnswer = (_) => true;
      for (final attempts in [0, 1]) {
        await expectLater(
          run(_entry(_a(0), attempts: attempts)),
          throwsA(isA<SyncRejectedError>()),
        );
      }
      await run(_entry(_a(0), attempts: kMaxFailedDuelAnswerAttempts - 1));
    });

    test('неожиданный сбой: повтор, затем отброс', () async {
      server.failUnexpected.add('submitDuelAnswer');
      await expectLater(run(_entry(_a(0))), throwsA(isA<UnexpectedError>()));
      await run(_entry(_a(0), attempts: kMaxFailedDuelAnswerAttempts - 1));
    });

    test('запись не разбирается или нарушает правила сервера: отброс без '
        'вызова сервера', () async {
      final bad = [
        OutboxEntry(
          kind: OutboxKind.duelAnswer,
          payloadJson: 'не json',
          createdAt: s0,
        ),
        OutboxEntry(
          kind: OutboxKind.duelAnswer,
          payloadJson: '{"duel_id": 1}',
          createdAt: s0,
        ),
        _entry(_a(0, ms: -5)),
        _entry(_a(0, answer: {'x': 'a' * 600})),
        _entry(_a(0, duelId: 'не-uuid')),
      ];
      for (final e in bad) {
        await run(e);
      }
      expect(server.calls, 0);
      expect(server.duelAnswers, isEmpty);
    });
  });

  group('очередь на drift и SyncService', () {
    late Device d;
    late DriftDuelAnswerQueue queue;
    var queuedCalls = 0;

    setUp(() {
      queuedCalls = 0;
      d = Device(
        server,
        outboxHandlers: {
          OutboxKind.duelAnswer: duelAnswerOutboxHandler(server),
        },
      );
      queue = DriftDuelAnswerQueue(
        db: d.db,
        userId: () => userA,
        clock: () => s0,
        onQueued: () => queuedCalls++,
      );
    });

    Future<List<OutboxRow>> outbox() => d.db.select(d.db.outbox).get();

    test(
      'ответ ставится в outbox под пользователем, FSRS не затронут',
      () async {
        expect(await queue.enqueue(_a(0)), isTrue);
        final rows = await outbox();
        expect(rows.single.kind, OutboxKind.duelAnswer);
        expect(rows.single.userId, userA);
        expect(
          DuelAnswerPayload.tryParse(jsonDecode(rows.single.payloadJson))!
              .questionId,
          duelQuestionIds()[0],
        );
        expect(
          queuedCalls,
          1,
          reason: 'просьба к SyncService отправить очередь',
        );
        expect(await d.db.select(d.db.reviewLogs).get(), isEmpty);
        expect(await d.db.select(d.db.userItemStates).get(), isEmpty);
      },
    );

    test('повторный ответ на тот же вопрос не ставится в очередь', () async {
      expect(await queue.enqueue(_a(0)), isTrue);
      expect(
        await queue.enqueue(
          _a(
            0,
            answer: {
              'selected': ['b'],
            },
          ),
        ),
        isFalse,
      );
      expect(await outbox(), hasLength(1));
      expect(queuedCalls, 1);
    });

    test('одновременные ответы на один вопрос: в очереди один', () async {
      final results = await Future.wait([
        queue.enqueue(_a(0)),
        queue.enqueue(_a(0)),
        queue.enqueue(_a(0)),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(await outbox(), hasLength(1));
    });

    test('pendingQuestionIds: только своя дуэль и свой пользователь', () async {
      await queue.enqueue(_a(0));
      await queue.enqueue(_a(1));
      await queue.enqueue(_a(0, duelId: _duel2));
      final other = DriftDuelAnswerQueue(
        db: d.db,
        userId: () => userB,
        clock: () => s0,
      );
      await other.enqueue(_a(2));
      expect(await queue.pendingQuestionIds(kDuelId), {
        duelQuestionIds()[0],
        duelQuestionIds()[1],
      });
      expect(await queue.pendingQuestionIds(_duel2), {duelQuestionIds()[0]});
      expect(await other.pendingQuestionIds(kDuelId), {duelQuestionIds()[2]});
    });

    test(
      'другой пользователь может ответить на тот же вопрос той же дуэли',
      () async {
        final other = DriftDuelAnswerQueue(
          db: d.db,
          userId: () => userB,
          clock: () => s0,
        );
        expect(await queue.enqueue(_a(0)), isTrue);
        expect(await other.enqueue(_a(0)), isTrue);
      },
    );

    test('нет сессии: AuthError, ничего не записано', () async {
      final noUser = DriftDuelAnswerQueue(
        db: d.db,
        userId: () => throw const AuthError('нет сессии'),
        clock: () => s0,
      );
      await expectLater(noUser.enqueue(_a(0)), throwsA(isA<AuthError>()));
      expect(await outbox(), isEmpty);
    });

    test(
      'офлайн: ответы лежат, при сети уходят; очередь пуста; FSRS пуст',
      () async {
        server.offline = true;
        for (var i = 0; i < 5; i++) {
          await queue.enqueue(_a(i));
        }
        final offline = await d.service.sync();
        expect(offline.outcome, SyncOutcome.offline);
        expect(await outbox(), hasLength(5), reason: 'не потеряны');
        expect(server.duelAnswers, isEmpty);

        server.offline = false;
        final ok = await d.service.sync();
        expect(ok.outcome, SyncOutcome.success, reason: '$ok');
        expect(ok.outboxSent, 5);
        expect(await outbox(), isEmpty);
        expect(server.duelAnswers, hasLength(5));
        expect(server.duelAnswers.keys.map((k) => k.$2).toSet(), {
          userA,
        }, reason: 'под пользователем сессии');
        expect(await d.logs(), isEmpty);
        expect(await d.db.select(d.db.userItemStates).get(), isEmpty);
        expect(server.logs, isEmpty);
        expect(server.states, isEmpty);
      },
    );

    test('ответ сервера потерян: повтор не создаёт дубль', () async {
      await queue.enqueue(_a(0));
      server.failAfter.add(1);
      final lost = await d.service.sync();
      expect(lost.outcome, SyncOutcome.offline);
      expect(server.duelAnswers, hasLength(1), reason: 'сервер записал');
      expect(await outbox(), hasLength(1), reason: 'клиент не знает');
      final again = await d.service.sync();
      expect(again.outcome, SyncOutcome.success, reason: '$again');
      expect(server.duelAnswers, hasLength(1));
      expect(await outbox(), isEmpty);
    });

    test(
      'дуэль закрылась: ответ отброшен и следующие ответы не блокируются',
      () async {
        await queue.enqueue(_a(0, duelId: _duel2));
        await queue.enqueue(_a(0));
        server.closedDuels.add(_duel2);
        final r = await d.service.sync();
        expect(r.outcome, SyncOutcome.success, reason: '$r');
        expect(await outbox(), isEmpty, reason: 'закрытая отброшена');
        expect(server.duelAnswers.keys.map((k) => k.$1), [kDuelId]);
      },
    );

    test('«ядовитая» запись не блокирует очередь и отбрасывается после '
        'трёх отказов', () async {
      await queue.enqueue(_a(0, duelId: _duel2));
      await queue.enqueue(_a(1));
      server.rejectDuelAnswer = (a) => a.duelId == _duel2;
      for (var run = 1; run <= 2; run++) {
        final r = await d.service.sync();
        expect(r.outboxSent, run == 1 ? 1 : 0);
        final left = await outbox();
        expect(left.single.attempts, run, reason: 'отказ засчитан');
      }
      await d.service.sync();
      expect(await outbox(), isEmpty, reason: 'отброшена на третьей попытке');
      expect(server.duelAnswers.keys.map((k) => k.$1).toSet(), {kDuelId});
    });

    test('сессия сменилась: ответы чужого пользователя не уходят', () async {
      await queue.enqueue(_a(0));
      d.user = userB;
      server.sessionUserId = userB;
      final r = await d.service.sync();
      expect(r.outcome, SyncOutcome.success);
      expect(server.duelAnswers, isEmpty);
      expect(await outbox(), hasLength(1), reason: 'ждёт своего пользователя');
    });
  });
}
