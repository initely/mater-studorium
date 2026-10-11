// Построитель очереди на реальных DAO и drift в памяти (ТЗ M3, AC3.1).
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/data/drift_session_repository.dart';
import 'package:mater_studorium/features/session/domain/local_day.dart';
import 'package:mater_studorium/features/session/domain/session_queue.dart';
import 'package:mater_studorium/features/session/domain/session_queue_builder.dart';
import 'package:mater_studorium/features/session/domain/session_settings.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/scheduler.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/session_db_fixtures.dart';
import '../../../helpers/time_zones.dart';

final now = DateTime.utc(2026, 10, 11, 12);

Duration h(int hours) => Duration(hours: hours);

SessionQueueBuilder builderFor(
  AppDatabase db, {
  int seed = 1,
  UtcOffsetAt? zone,
  String user = sessionUser,
}) => SessionQueueBuilder(
  repository: repositoryFor(db, user: user),
  random: math.Random(seed),
  utcOffsetAt: zone ?? fixedOffset(Duration.zero),
);

List<String> ids(SessionQueue q) => [for (final i in q.items) i.item.id];

/// Колода `fixture-good` (t.a, t.b, t.c) и `big` из 15 знаний.
Future<AppDatabase> dbWithDecks() async {
  final db = memoryDb();
  await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
  await db.decksDao.replaceDeck(bigDeck('big', 15), downloadedAt: t0);
  return db;
}

void main() {
  test(
    'AC3.1: порядок due, затем новые в порядке колоды; лимит новых',
    () async {
      final db = await dbWithDecks();
      final earlier = now.subtract(const Duration(days: 10));
      // Просрочено: t.b (3 дня), t.a (1 день); t.c наступит через час.
      await answerItem(
        db,
        't.a',
        at: earlier,
        due: now.subtract(const Duration(days: 1)),
      );
      await answerItem(
        db,
        't.b',
        at: earlier,
        due: now.subtract(const Duration(days: 3)),
      );
      await answerItem(db, 't.c', at: earlier, due: now.add(h(1)));

      final queue = await builderFor(db).build(
        now: now,
        settings: const SessionSettings(newPerDay: 4, sessionSize: 50),
      );

      expect(ids(queue), ['t.b', 't.a', 'big.1', 'big.2', 'big.3', 'big.4']);
      expect(queue.dueCount, 2);
      expect(queue.newCount, 4);
      expect(queue.moreNewAvailable, isTrue);
      expect(queue.nextDue, now.add(h(1)));
      // Вариант выбран из вопросов своего знания, версия колоды из БД.
      expect(queue.items[0].deckVersion, 2);
      expect(queue.items[2].deckVersion, 1);
      expect(queue.items[0].state.itemId, 't.b');
      for (final i in queue.items) {
        expect(i.question.id, startsWith(i.item.id));
      }
    },
  );

  test('новое знание: первый показ — flip, если он есть', () async {
    final db = await dbWithDecks();

    final queue = await builderFor(db).build(now: now);

    final newBig = queue.items.where((i) => i.item.id.startsWith('big.'));
    for (final i in newBig) {
      expect(i.question.type, QuestionType.flip);
    }
  });

  test('retired, скрытые вопросы и полностью скрытые знания не попадают', () async {
    final db = await dbWithDecks();
    final past = now.subtract(const Duration(days: 2));
    await answerItem(db, 't.a', at: t0, due: past);
    await answerItem(db, 't.b', at: t0, due: past.add(h(1)));
    await answerItem(db, 't.c', at: t0, due: past.add(h(2)));

    // t.c выпало из версии колоды: retired. У t.b скрыты оба вопроса.
    final deck = goodDeck();
    await db.decksDao.replaceDeck(
      deck.copyWith(version: 3, items: [deck.items[0], deck.items[1]]),
      downloadedAt: t0,
    );
    // t.b и big.1 скрыты целиком, у t.a и big.2 скрыт первый вопрос.
    await db.decksDao.replaceHiddenQuestions({
      't.b.q1',
      't.b.q2',
      't.a.q1',
      'big.1.q1',
      'big.1.q2',
      'big.2.q1',
    });

    for (var seed = 0; seed < 20; seed++) {
      final queue = await builderFor(
        db,
        seed: seed,
      ).build(now: now, settings: const SessionSettings(sessionSize: 50));

      expect(ids(queue).take(1), ['t.a']);
      expect(ids(queue), isNot(contains('t.b')));
      expect(ids(queue), isNot(contains('t.c')));
      expect(ids(queue), isNot(contains('big.1')));
      final byItem = {for (final i in queue.items) i.item.id: i.question.id};
      // Скрытые вопросы не выбираются никогда: у t.a остался q2, у big.2 — q2.
      expect(byItem['t.a'], 't.a.q2');
      expect(byItem['big.2'], 'big.2.q2');
    }
  });

  test('пустая очередь: колод нет, затем всё повторено', () async {
    final empty = memoryDb();
    final none = await builderFor(empty).build(now: now);
    expect(none.isEmpty, isTrue);
    expect(none.emptyReason, EmptyQueueReason.noContent);

    final db = memoryDb();
    await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
    for (final (i, id) in ['t.a', 't.b', 't.c'].indexed) {
      await answerItem(db, id, at: t0, due: now.add(h(3 + i)));
    }

    final done = await builderFor(db).build(now: now);

    expect(done.emptyReason, EmptyQueueReason.allDone);
    expect(done.nextDue, now.add(h(3)));
  });

  test(
    'повторный запуск в тот же день: уже взятые новые учтены в лимите',
    () async {
      final db = await dbWithDecks();
      final builder = builderFor(db);
      const settings = SessionSettings(newPerDay: 8, sessionSize: 50);

      final first = await builder.build(now: now, settings: settings);
      expect(first.newCount, 8);
      // Ответили на первые 5 из 8 (t.a, t.b, t.c, big.1, big.2) в 12:05 (так же, как это делает контроллер).
      final answeredAt = now.add(const Duration(minutes: 5));
      final repo = repositoryFor(db);
      for (final item in first.items.take(5)) {
        await repo.recordReview(
          log: logFor(item.item.id, id: 'l-${item.item.id}').copyWith(
            deckId: item.item.deckId,
            questionId: item.question.id,
            reviewedAt: answeredAt,
          ),
          state: const Scheduler()
              .review(item.state, Rating.good, answeredAt)
              .copyWith(lastQuestionId: item.question.id),
        );
      }

      final second = await builder.build(
        now: answeredAt.add(h(2)),
        settings: settings,
      );

      expect(second.newCount, 3, reason: '8 в день минус 5 уже показанных');
      expect(ids(second), ['big.3', 'big.4', 'big.5']);
      // Отвеченные пять новыми больше не считаются и ещё не наступили.
      expect(ids(second), isNot(contains('t.a')));
    },
  );

  test('граница суток по часовому поясу и переход на зимнее время', () async {
    final db = await dbWithDecks();
    // Первый показ t.a: 1 ноября 2026, 00:30 EDT (04:30Z).
    await answerItem(
      db,
      't.a',
      at: DateTime.utc(2026, 11, 1, 4, 30),
      due: DateTime.utc(2026, 12, 1),
    );
    // 23:30 EST того же 1 ноября (25-часовые сутки).
    final late = DateTime.utc(2026, 11, 2, 4, 30);
    const settings = SessionSettings(newPerDay: 5, sessionSize: 50);

    final inNewYork = await builderFor(
      db,
      zone: newYork,
    ).build(now: late, settings: settings);
    // Тот же момент по UTC уже 2 ноября: лимит новый.
    final inUtc = await builderFor(db).build(now: late, settings: settings);

    expect(inNewYork.newCount, 4, reason: 't.a показан сегодня по Нью-Йорку');
    expect(inUtc.newCount, 5);
  });

  test('пользователи не видят прогресс друг друга', () async {
    final db = await dbWithDecks();
    await answerItem(db, 't.a', at: t0, due: now.subtract(h(1)));
    await answerItem(db, 't.b', at: t0, due: now.subtract(h(1)), user: 'u2');

    final u1 = await builderFor(db).build(now: now);
    final u2 = await builderFor(db, user: 'u2').build(now: now);

    expect(ids(u1).first, 't.a');
    expect(ids(u1), contains('t.b')); // для u1 t.b — новое знание
    expect(u1.dueCount, 1);
    expect(ids(u2).first, 't.b');
    expect(u2.dueCount, 1);
  });

  test('одинаковый seed на одинаковых данных — одинаковая очередь', () async {
    final db = await dbWithDecks();
    for (final id in ['t.a', 't.b', 't.c']) {
      await answerItem(db, id, at: t0, due: now.subtract(h(1)));
    }

    List<String> run(SessionQueue q) => [
      for (final i in q.items) '${i.item.id}:${i.question.id}',
    ];
    final a = await builderFor(db, seed: 7).build(now: now);
    final b = await builderFor(db, seed: 7).build(now: now);

    expect(run(a), run(b));
  });

  group('DriftSessionRepository', () {
    test('contentFor: версия колоды и только видимые вопросы', () async {
      final db = await dbWithDecks();
      await db.decksDao.replaceHiddenQuestions({'t.a.q1', 't.b.q1', 't.b.q2'});

      final content = await repositoryFor(db)
          .contentFor({'t.a', 't.b', 'big.1', 'нет'});

      expect(content.keys.toSet(), {'t.a', 'big.1'});
      expect(content['t.a']!.deckVersion, 2);
      expect(content['t.a']!.questions.map((q) => q.id), ['t.a.q2']);
      expect(content['big.1']!.deckVersion, 1);
      expect(content['big.1']!.item.id, 'big.1');
    });

    test('типизированные ошибки (нет сессии) не оборачиваются', () async {
      final db = await dbWithDecks();
      final repo = DriftSessionRepository(
        review: db.reviewDao,
        decks: db.decksDao,
        userId: () => throw const AuthError('нет сессии'),
      );

      await expectLater(repo.dueStates(now: now), throwsA(isA<AuthError>()));
    });

    test('ошибка записи: LocalStorageError, ничего не записано', () async {
      final db = await dbWithDecks();
      final repo = repositoryFor(db);
      final log = logFor('t.a', id: 'dup');
      final state = stateFor('t.a', due: now);
      await repo.recordReview(log: log, state: state);

      await expectLater(
        repo.recordReview(
          log: log,
          state: stateFor('t.a', due: now.add(h(5)), updatedAt: now),
        ),
        throwsA(
          isA<LocalStorageError>().having((e) => e.cause, 'cause', isNotNull),
        ),
      );

      expect((await db.reviewDao.getState(sessionUser, 't.a'))!.due, now);
    });
  });
}
