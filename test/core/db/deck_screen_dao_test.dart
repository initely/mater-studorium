// DAO для экрана колоды и настроек (T18): прогресс по стадиям FSRS,
// удаление колоды без потери прогресса, app_settings, описание колоды.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/deck/domain/deck_progress.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

import '../../helpers/db_fixtures.dart';

const user = 'u1';

void main() {
  group('watchDeckProgress', () {
    test(
      'новые / изучаемые / выученные по стадии FSRS; retired не считается',
      () async {
        final db = memoryDb();
        await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
        // t.a: learning, t.b: review; t.c: строки нет (новое).
        await db.reviewDao.recordReview(
          userId: user,
          log: logFor('t.a', id: 'l1'),
          state: stateFor('t.a', due: t0).copyWith(state: SrsState.learning),
        );
        await db.reviewDao.recordReview(
          userId: user,
          log: logFor('t.b', id: 'l2'),
          state: stateFor('t.b', due: t0),
        );

        final progress = await db.reviewDao
            .watchDeckProgress(user, 'fixture-good')
            .first;
        expect(progress.newCount, 1);
        expect(progress.learningCount, 1);
        expect(progress.masteredCount, 1);
        expect(progress.total, 3);

        // Новая версия без t.c: знание ретайрится и выпадает из подсчёта.
        final deck = goodDeck();
        await db.decksDao.replaceDeck(
          deck.copyWith(version: 3, items: deck.items.take(2).toList()),
          downloadedAt: t0,
        );
        final after = await db.reviewDao
            .watchDeckProgress(user, 'fixture-good')
            .first;
        expect(after.newCount, 0);
        expect(after.total, 2);
      },
    );

    test(
      'прогресс чужого пользователя не учитывается; поток обновляется',
      () async {
        final db = memoryDb();
        await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
        await db.reviewDao.recordReview(
          userId: 'other',
          log: logFor('t.a', id: 'l1'),
          state: stateFor('t.a', due: t0),
        );

        final stream = db.reviewDao.watchDeckProgress(user, 'fixture-good');
        final emitted = <DeckProgress>[];
        final sub = stream.listen(emitted.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();
        expect(emitted.last.newCount, 3);

        await db.reviewDao.recordReview(
          userId: user,
          log: logFor('t.a', id: 'l2'),
          state: stateFor('t.a', due: t0),
        );
        await pumpEventQueue();
        expect(emitted.last.newCount, 2);
        expect(emitted.last.masteredCount, 1);
      },
    );
  });

  group('deleteDeck', () {
    test(
      'убирает колоду, знания и вопросы; прогресс и логи остаются',
      () async {
        final db = memoryDb();
        await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
        await db.reviewDao.recordReview(
          userId: user,
          log: logFor('t.a', id: 'l1'),
          state: stateFor('t.a', due: t0),
        );

        await db.decksDao.deleteDeck('fixture-good');

        expect(await db.decksDao.getDeck('fixture-good'), isNull);
        expect(await db.select(db.items).get(), isEmpty);
        expect(await db.select(db.questions).get(), isEmpty);
        expect(await db.select(db.userItemStates).get(), hasLength(1));
        expect(await db.select(db.reviewLogs).get(), hasLength(1));
        // Без знаний в БД повторять нечего: due и новые пусты.
        expect(await db.reviewDao.dueStates(user, now: t0), isEmpty);
        expect(await db.reviewDao.newItems(user), isEmpty);
      },
    );

    test(
      'повторное скачивание возвращает прогресс по тем же item_id',
      () async {
        final db = memoryDb();
        await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
        await db.reviewDao.recordReview(
          userId: user,
          log: logFor('t.a', id: 'l1'),
          state: stateFor('t.a', due: t0),
        );
        await db.decksDao.deleteDeck('fixture-good');
        await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);

        final due = await db.reviewDao.dueStates(user, now: t0);
        expect(due.map((s) => s.itemId), ['t.a']);
        expect((await db.reviewDao.newItems(user)).map((i) => i.id), [
          't.b',
          't.c',
        ]);
      },
    );

    test('чужие колоды не затрагиваются', () async {
      final db = memoryDb();
      final deck = goodDeck();
      await db.decksDao.replaceDeck(deck, downloadedAt: t0);
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

      await db.decksDao.deleteDeck('other');

      expect(await db.decksDao.getDeck('fixture-good'), isNotNull);
      expect((await db.select(db.items).get()).length, 3);
      expect((await db.select(db.questions).get()).length, 6);
    });
  });

  test('описание колоды сохраняется и читается', () async {
    final db = memoryDb();
    await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
    final deck = await db.decksDao.getDeck('fixture-good');
    expect(deck?.description, goodDeck().description);
    expect(deck?.description, isNotEmpty);
  });

  group('app_settings', () {
    test('запись, перезапись и чтение всех ключей', () async {
      final db = memoryDb();
      expect(await db.settingsDao.readAll(), isEmpty);
      await db.settingsDao.write('new_per_day', '5');
      await db.settingsDao.write('new_per_day', '7');
      await db.settingsDao.write('onboarding_done', '1');
      expect(await db.settingsDao.readAll(), {
        'new_per_day': '7',
        'onboarding_done': '1',
      });
    });
  });
}
