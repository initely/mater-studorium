import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';

import '../../helpers/db_fixtures.dart';

const user = 'u1';

Future<AppDatabase> dbWithDeck() async {
  final db = memoryDb();
  await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
  return db;
}

Future<void> save(
  AppDatabase db,
  String itemId,
  DateTime due, {
  String u = user,
}) => db.reviewDao.recordReview(
  userId: u,
  log: logFor(itemId, id: 'log-$u-$itemId'),
  state: stateFor(itemId, due: due),
);

void main() {
  group('dueStates', () {
    test('due <= now по возрастанию due, будущие не попадают', () async {
      final db = await dbWithDeck();
      await save(db, 't.a', t0.subtract(const Duration(days: 1)));
      await save(db, 't.b', t0); // ровно сейчас: due
      await save(db, 't.c', t0.add(const Duration(hours: 1)));

      final due = await db.reviewDao.dueStates(user, now: t0);
      expect(due.map((s) => s.itemId), ['t.a', 't.b']);
      expect(due.first.due.isUtc, isTrue);
    });

    test('limit, фильтр по колодам, чужой пользователь', () async {
      final db = await dbWithDeck();
      final deck = goodDeck();
      await db.decksDao.replaceDeck(
        deck.copyWith(
          id: 'other',
          items: [
            deck.items[0].copyWith(
              id: 'o.1',
              questions: [deck.items[0].questions[0].copyWith(id: 'o.1.q1')],
            ),
          ],
        ),
        downloadedAt: t0,
      );
      final past = t0.subtract(const Duration(days: 1));
      await save(db, 't.a', past);
      await save(db, 't.b', past.add(const Duration(hours: 1)));
      await save(db, 'o.1', past.add(const Duration(hours: 2)));
      await save(db, 't.c', past, u: 'u2');

      expect(
        (await db.reviewDao.dueStates(
          user,
          now: t0,
          limit: 2,
        )).map((s) => s.itemId),
        ['t.a', 't.b'],
      );
      expect(
        (await db.reviewDao.dueStates(
          user,
          now: t0,
          deckIds: {'other'},
        )).map((s) => s.itemId),
        ['o.1'],
      );
      expect(
        (await db.reviewDao.dueStates('u2', now: t0)).map((s) => s.itemId),
        ['t.c'],
      );
    });

    test('retired и знания без доступных вопросов не попадают', () async {
      final db = await dbWithDeck();
      final past = t0.subtract(const Duration(days: 1));
      await save(db, 't.a', past);
      await save(db, 't.b', past);
      await save(db, 't.c', past);

      final deck = goodDeck();
      await db.decksDao.replaceDeck(
        deck.copyWith(version: 3, items: [deck.items[0], deck.items[1]]),
        downloadedAt: t0,
      ); // t.c retired
      await db.decksDao.replaceHiddenQuestions({'t.b.q1', 't.b.q2'});
      await db.decksDao.hideQuestion('t.a.q1'); // у t.a остался q2

      final due = await db.reviewDao.dueStates(user, now: t0);
      expect(due.map((s) => s.itemId), ['t.a']);
    });
  });

  group('newItems', () {
    test('знания без состояния, в порядке колоды, с лимитом', () async {
      final db = await dbWithDeck();
      expect((await db.reviewDao.newItems(user)).map((i) => i.id), [
        't.a',
        't.b',
        't.c',
      ]);

      await save(db, 't.b', t0);
      expect((await db.reviewDao.newItems(user)).map((i) => i.id), [
        't.a',
        't.c',
      ]);
      expect((await db.reviewDao.newItems(user, limit: 1)).map((i) => i.id), [
        't.a',
      ]);
      // У другого пользователя прогресса нет.
      expect(await db.reviewDao.newItems('u2'), hasLength(3));
      expect(await db.reviewDao.newItems(user, deckIds: {'nope'}), isEmpty);
    });

    test('retired и знания без доступных вопросов не попадают', () async {
      final db = await dbWithDeck();
      final deck = goodDeck();
      await db.decksDao.replaceDeck(
        deck.copyWith(version: 3, items: [deck.items[0], deck.items[1]]),
        downloadedAt: t0,
      ); // t.c retired
      await db.decksDao.replaceHiddenQuestions({'t.a.q1', 't.a.q2'});

      expect((await db.reviewDao.newItems(user)).map((i) => i.id), ['t.b']);
    });
  });

  group('nextDue', () {
    test(
      'ближайшее due строго после after; retired, чужие и скрытые не в счёт',
      () async {
        final db = await dbWithDeck();
        expect(await db.reviewDao.nextDue(user, after: t0), isNull);

        await save(db, 't.a', t0); // не в будущем: не считается
        await save(db, 't.b', t0.add(const Duration(hours: 5)));
        await save(db, 't.c', t0.add(const Duration(hours: 2)));
        await save(db, 't.a', t0.add(const Duration(hours: 1)), u: 'u2');

        final next = await db.reviewDao.nextDue(user, after: t0);
        expect(next, t0.add(const Duration(hours: 2)));
        expect(next!.isUtc, isTrue);
        // Строго после: само значение не подходит.
        expect(
          await db.reviewDao.nextDue(
            user,
            after: t0.add(const Duration(hours: 2)),
          ),
          t0.add(const Duration(hours: 5)),
        );

        // Фильтр по колодам.
        expect(
          await db.reviewDao.nextDue(user, after: t0, deckIds: {'nope'}),
          isNull,
        );
        expect(
          await db.reviewDao.nextDue(
            user,
            after: t0,
            deckIds: {'fixture-good'},
          ),
          t0.add(const Duration(hours: 2)),
        );

        // t.c скрыт целиком, значит следующий — t.b.
        await db.decksDao.replaceHiddenQuestions({'t.c.q1', 't.c.q2'});
        expect(
          await db.reviewDao.nextDue(user, after: t0),
          t0.add(const Duration(hours: 5)),
        );
      },
    );
  });

  group('countNewItemsFirstShown', () {
    final dayStart = DateTime.utc(2026, 10, 11);
    final dayEnd = DateTime.utc(2026, 10, 12);

    Future<void> answer(
      AppDatabase db,
      String itemId,
      DateTime at, {
      String id = '',
      String u = user,
    }) => db.reviewDao.recordReview(
      userId: u,
      log: logFor(
        itemId,
        id: id.isEmpty ? 'log-$u-$itemId-${at.millisecondsSinceEpoch}' : id,
      ).copyWith(reviewedAt: at),
      state: stateFor(itemId, due: at.add(const Duration(days: 3))),
    );

    Future<int> count(AppDatabase db, {String u = user}) =>
        db.reviewDao.countNewItemsFirstShown(u, from: dayStart, to: dayEnd);

    test('считает знания, у которых первый лог внутри суток', () async {
      final db = await dbWithDeck();
      expect(await count(db), 0);

      await answer(db, 't.a', DateTime.utc(2026, 10, 11, 8));
      await answer(db, 't.a', DateTime.utc(2026, 10, 11, 9)); // повтор того же
      await answer(db, 't.b', DateTime.utc(2026, 10, 11, 10));

      expect(await count(db), 2);
    });

    test(
      'знание, впервые показанное раньше, новым сегодня не считается',
      () async {
        final db = await dbWithDeck();
        await answer(
          db,
          't.a',
          dayStart.subtract(const Duration(microseconds: 1)),
        );
        await answer(db, 't.a', DateTime.utc(2026, 10, 11, 8));
        await answer(db, 't.b', DateTime.utc(2026, 10, 10, 1));

        expect(await count(db), 0);
      },
    );

    test('границы: from включается, to не включается', () async {
      final db = await dbWithDeck();
      await answer(db, 't.a', dayStart);
      await answer(db, 't.b', dayEnd.subtract(const Duration(seconds: 1)));
      await answer(db, 't.c', dayEnd);

      expect(await count(db), 2);
    });

    test('чужой пользователь не мешает', () async {
      final db = await dbWithDeck();
      await answer(db, 't.a', DateTime.utc(2026, 10, 11, 8), u: 'u2');
      // Свой лог уже вчера, чужой сегодня: у пользователя знание не новое.
      await answer(db, 't.b', DateTime.utc(2026, 10, 10, 8));
      await answer(db, 't.b', DateTime.utc(2026, 10, 11, 8), u: 'u2');

      expect(await count(db), 0);
      expect(await count(db, u: 'u2'), 2);
    });
  });

  group('lastShownAt', () {
    test('последний показ каждого вопроса выбранных знаний', () async {
      final db = await dbWithDeck();
      Future<void> log(String item, String q, DateTime at, {String u = user}) =>
          db.reviewDao.recordReview(
            userId: u,
            log: logFor(
              item,
              id: 'l-$u-$q-${at.millisecondsSinceEpoch}',
            ).copyWith(questionId: q, reviewedAt: at),
            state: stateFor(item, due: at),
          );
      await log('t.a', 't.a.q1', DateTime.utc(2026, 10, 1));
      await log('t.a', 't.a.q1', DateTime.utc(2026, 10, 5));
      await log('t.a', 't.a.q2', DateTime.utc(2026, 10, 3));
      await log('t.b', 't.b.q1', DateTime.utc(2026, 10, 4));
      await log('t.a', 't.a.q2', DateTime.utc(2026, 10, 9), u: 'u2');

      final shown = await db.reviewDao.lastShownAt(user, {'t.a', 't.c'});

      expect(shown, {
        't.a.q1': DateTime.utc(2026, 10, 5),
        't.a.q2': DateTime.utc(2026, 10, 3),
      });
      expect(shown['t.a.q1']!.isUtc, isTrue);
      expect(await db.reviewDao.lastShownAt(user, {}), isEmpty);
    });

    test('больше 500 знаний: порции запроса', () async {
      final db = await dbWithDeck();
      await save(db, 't.a', t0);

      final ids = {for (var i = 0; i < 1100; i++) 'x$i', 't.a'};

      expect(await db.reviewDao.lastShownAt(user, ids), {'t.a.q1': t0});
    });
  });

  group('recordReview', () {
    test('лог, состояние (dirty) и outbox пишутся вместе', () async {
      final db = await dbWithDeck();
      final state = stateFor('t.a', due: t0.add(const Duration(days: 4)));
      final report = OutboxEntry(
        kind: OutboxKind.report,
        payloadJson: '{"question_id":"t.a.q1"}',
        createdAt: t0,
      );

      await db.reviewDao.recordReview(
        userId: user,
        log: logFor('t.a'),
        state: state,
        outbox: [report],
      );

      expect(await db.reviewDao.getState(user, 't.a'), state);
      expect(await db.reviewDao.getState('u2', 't.a'), isNull);

      final stateRow = await db.select(db.userItemStates).getSingle();
      expect(stateRow.dirty, isTrue);
      expect(stateRow.userId, user);

      final logRow = await db.select(db.reviewLogs).getSingle();
      expect(logRow.id, 'log-1');
      expect(logRow.userId, user);
      expect(logRow.deckVersion, 2);
      expect(logRow.questionType, 'find_error');
      expect(logRow.rating, 2);
      expect(logRow.gradeSource, 'override');
      expect(logRow.llmScore, 0.6);
      expect(logRow.answerText, 'ответ');
      expect(logRow.durationMs, 4200);
      expect(logRow.reviewedAt.toUtc(), t0);
      expect(logRow.syncedAt, isNull);

      final pending = await db.reviewDao.pendingOutbox();
      expect(pending, hasLength(1));
      expect(pending.single.kind, OutboxKind.report);
      expect(pending.single.payloadJson, report.payloadJson);
      expect(pending.single.createdAt, t0);
      expect(pending.single.attempts, 0);
    });

    test(
      'повторный ответ по знанию обновляет состояние, а не дублирует',
      () async {
        final db = await dbWithDeck();
        await save(db, 't.a', t0);
        final later = t0.add(const Duration(days: 3));
        await db.reviewDao.recordReview(
          userId: user,
          log: logFor('t.a', id: 'log-2'),
          state: stateFor('t.a', due: later, updatedAt: later),
        );

        expect((await db.reviewDao.getState(user, 't.a'))!.due, later);
        expect(await db.select(db.userItemStates).get(), hasLength(1));
        expect(await db.select(db.reviewLogs).get(), hasLength(2));
      },
    );

    test('ошибка откатывает всё: состояние, outbox и лог', () async {
      final db = await dbWithDeck();
      final first = stateFor('t.a', due: t0);
      await db.reviewDao.recordReview(
        userId: user,
        log: logFor('t.a'),
        state: first,
      );

      // Тот же id лога: вставка лога падает последней, после записи
      // состояния и outbox.
      final later = t0.add(const Duration(days: 3));
      await expectLater(
        db.reviewDao.recordReview(
          userId: user,
          log: logFor('t.a'),
          state: stateFor('t.a', due: later, updatedAt: later),
          outbox: [
            OutboxEntry(
              kind: OutboxKind.duelAnswer,
              payloadJson: '{}',
              createdAt: later,
            ),
          ],
        ),
        throwsA(anything),
      );

      expect(await db.reviewDao.getState(user, 't.a'), first);
      expect(await db.reviewDao.pendingOutbox(), isEmpty);
      expect(await db.select(db.reviewLogs).get(), hasLength(1));
    });
  });

  test('outbox: порядок, попытки, удаление', () async {
    final db = await dbWithDeck();
    for (final p in ['1', '2']) {
      await db.reviewDao.enqueueOutbox(
        OutboxEntry(kind: OutboxKind.duelAnswer, payloadJson: p, createdAt: t0),
      );
    }

    var pending = await db.reviewDao.pendingOutbox();
    expect(pending.map((e) => e.payloadJson), ['1', '2']);
    expect((await db.reviewDao.pendingOutbox(limit: 1)), hasLength(1));

    await db.reviewDao.incrementOutboxAttempts(pending.first.id!);
    await db.reviewDao.deleteOutbox(pending.last.id!);
    pending = await db.reviewDao.pendingOutbox();
    expect(pending.single.payloadJson, '1');
    expect(pending.single.attempts, 1);
  });
}
