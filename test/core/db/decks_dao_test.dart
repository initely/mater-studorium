import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/domain/deck_validator.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';

import '../../helpers/db_fixtures.dart';

void main() {
  test(
    'replaceDeck: новая колода, знания, вопросы и ссылки на месте',
    () async {
      final db = memoryDb();
      final deck = goodDeck();

      await db.decksDao.replaceDeck(deck, downloadedAt: t0);

      final local = await db.decksDao.getDeck('fixture-good');
      expect(local!.version, 2);
      expect(local.title, deck.title);
      expect(local.downloadedAt, t0);
      expect(local.downloadedAt.isUtc, isTrue);

      final item = await db.decksDao.getItem('t.c');
      expect(item!.deckId, 'fixture-good');
      expect(item.retired, isFalse);
      expect(item.fact, deck.items[2].fact);
      // refs_json содержит данные источника: sources в БД нет.
      expect(item.refs.map((r) => r.sourceId), ['src-a', 'src-b']);
      expect(item.refs.first.url, deck.sources.first.url);
      expect(item.refs.first.sourceTitle, deck.sources.first.title);
      expect(item.refs.first.license, deck.sources.first.license);

      // Вопрос и payload восстанавливаются без потерь, тип — в wire-формате.
      final q = await db.decksDao.getQuestion('t.c.q2');
      expect(q, deck.items[2].questions[1]);
      expect(q!.type, QuestionType.findError);
      final rows = await db.select(db.questions).get();
      expect(rows.map((r) => r.type), contains('find_error'));
      expect(rows, hasLength(6));
    },
  );

  test('replaceDeck: новая версия обновляет, добавляет и списывает', () async {
    final db = memoryDb();
    final v2 = goodDeck();
    await db.decksDao.replaceDeck(v2, downloadedAt: t0);

    // v3: нет знания t.b, у t.a убран вопрос q2, у t.a изменён факт, есть t.d.
    final t1 = t0.add(const Duration(days: 1));
    final v3 = v2.copyWith(
      version: 3,
      items: [
        v2.items[0].copyWith(
          fact: 'новый факт',
          questions: [v2.items[0].questions[0]],
        ),
        v2.items[2],
        v2.items[2].copyWith(
          id: 't.d',
          questions: [v2.items[2].questions[0].copyWith(id: 't.d.q1')],
        ),
      ],
    );
    await db.decksDao.replaceDeck(v3, downloadedAt: t1);

    expect((await db.decksDao.getDeck('fixture-good'))!.version, 3);
    expect((await db.decksDao.getDeck('fixture-good'))!.downloadedAt, t1);
    expect((await db.decksDao.getItem('t.a'))!.fact, 'новый факт');
    expect((await db.decksDao.getItem('t.d')), isNotNull);
    expect((await db.decksDao.visibleQuestions('t.a')).map((q) => q.id), [
      't.a.q1',
    ]);
    // Исчезнувшее знание: retired, но строка и вопросы остались.
    expect((await db.decksDao.getItem('t.b'))!.retired, isTrue);
    expect(await db.decksDao.getQuestion('t.b.q1'), isNotNull);
    expect(await db.select(db.decks).get(), hasLength(1));

    // Знание вернулось в более новой версии: снова активно.
    await db.decksDao.replaceDeck(
      v3.copyWith(version: 4, items: [...v3.items, v2.items[1]]),
      downloadedAt: t1,
    );
    expect((await db.decksDao.getItem('t.b'))!.retired, isFalse);
  });

  test(
    'replaceDeck: item_id другой колоды — ошибка, ничего не записано',
    () async {
      final db = memoryDb();
      final deck = goodDeck();
      await db.decksDao.replaceDeck(deck, downloadedAt: t0);

      final other = deck.copyWith(
        id: 'other',
        items: [
          deck.items[0].copyWith(id: 'o.new', questions: const []),
          deck.items[1], // t.b уже принадлежит fixture-good
        ],
      );
      await expectLater(
        db.decksDao.replaceDeck(other, downloadedAt: t0),
        throwsA(
          isA<ItemIdCollisionError>()
              .having((e) => e.itemId, 'itemId', 't.b')
              .having((e) => e.otherDeckId, 'otherDeckId', 'fixture-good'),
        ),
      );

      expect(await db.decksDao.getDeck('other'), isNull);
      expect(await db.decksDao.getItem('o.new'), isNull);
      expect((await db.decksDao.getItem('t.b'))!.deckId, 'fixture-good');
    },
  );

  test(
    'replaceDeck: id вопроса другой колоды — ошибка, чужой вопрос не тронут',
    () async {
      final db = memoryDb();
      final deck = goodDeck();
      await db.decksDao.replaceDeck(deck, downloadedAt: t0);
      final original = await db.decksDao.getQuestion('t.a.q1');

      // Колода Y: знание `t` свободно, а вопрос `t.a.q1` принадлежит
      // fixture-good. Валидатор одной колоды такое пропускает (id вопроса
      // начинается с `t.`), поэтому последний рубеж — DAO.
      final y = deck.copyWith(
        id: 'y',
        items: [
          deck.items[0].copyWith(
            id: 't',
            questions: [
              deck.items[0].questions[0].copyWith(prompt: 'подменённый вопрос'),
            ],
          ),
        ],
      );
      expect(validateDeck(y), isEmpty);

      await expectLater(
        db.decksDao.replaceDeck(y, downloadedAt: t0),
        throwsA(
          isA<QuestionIdCollisionError>()
              .having((e) => e.questionId, 'questionId', 't.a.q1')
              .having((e) => e.otherDeckId, 'otherDeckId', 'fixture-good'),
        ),
      );

      // Вопрос первой колоды не изменился и всё ещё привязан к t.a.
      expect(await db.decksDao.getQuestion('t.a.q1'), original);
      final row = await (db.select(
        db.questions,
      )..where((q) => q.id.equals('t.a.q1'))).getSingle();
      expect(row.itemId, 't.a');
      expect(await db.decksDao.getDeck('y'), isNull);
      expect(await db.decksDao.getItem('t'), isNull);
    },
  );

  test('hidden_questions: скрытые не попадают в visibleQuestions', () async {
    final db = memoryDb();
    await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);

    await db.decksDao.hideQuestion('t.a.q2');
    await db.decksDao.hideQuestion('t.a.q2'); // повтор безвреден
    expect(await db.decksDao.hiddenQuestionIds(), {'t.a.q2'});
    expect((await db.decksDao.visibleQuestions('t.a')).map((q) => q.id), [
      't.a.q1',
    ]);
    // Вопросы других знаний не затронуты.
    expect(await db.decksDao.visibleQuestions('t.b'), hasLength(2));

    // Pull с сервера заменяет серверный список целиком, а скрытое самим
    // пользователем (жалоба) остаётся: решение сервера его не возвращает.
    await db.decksDao.replaceServerHiddenQuestions({'t.b.q1', 't.b.q2'});
    expect(await db.decksDao.hiddenQuestionIds(), {
      't.a.q2',
      't.b.q1',
      't.b.q2',
    });
    await db.decksDao.replaceServerHiddenQuestions({'t.b.q1'});
    expect(await db.decksDao.hiddenQuestionIds(), {'t.a.q2', 't.b.q1'});
    await db.decksDao.replaceServerHiddenQuestions({});
    expect(await db.decksDao.hiddenQuestionIds(), {'t.a.q2'});
    expect((await db.decksDao.visibleQuestions('t.a')).map((q) => q.id), [
      't.a.q1',
    ]);
    expect(await db.decksDao.visibleQuestions('t.b'), hasLength(2));

    // Пользователь сам возвращает вопрос; серверное скрытие так не снять.
    await db.decksDao.replaceServerHiddenQuestions({'t.a.q1'});
    await db.decksDao.unhideLocalQuestion('t.a.q2');
    await db.decksDao.unhideLocalQuestion('t.a.q1');
    expect(await db.decksDao.hiddenQuestionIds(), {'t.a.q1'});
    // Жалоба на уже скрытый сервером вопрос делает его и локально скрытым.
    await db.decksDao.hideQuestion('t.a.q1');
    await db.decksDao.replaceServerHiddenQuestions({});
    expect(await db.decksDao.hiddenQuestionIds(), {'t.a.q1'});
  });

  test('visibleQuestionsFor: вопросы нескольких знаний без скрытых', () async {
    final db = memoryDb();
    await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
    await db.decksDao.hideQuestion('t.a.q1');
    await db.decksDao.replaceServerHiddenQuestions({
      't.a.q1',
      't.b.q1',
      't.b.q2',
    });

    final result = await db.decksDao.visibleQuestionsFor({
      't.a',
      't.b',
      't.c',
      'нет-такого',
    });

    // Порядок колоды; t.b полностью скрыто, значит ключа нет; неизвестное
    // знание тоже отсутствует.
    expect(result.keys.toSet(), {'t.a', 't.c'});
    expect(result['t.a']!.map((q) => q.id), ['t.a.q2']);
    expect(result['t.c']!.map((q) => q.id), ['t.c.q1', 't.c.q2']);
    expect(await db.decksDao.visibleQuestionsFor({}), isEmpty);
  });

  test('visibleQuestionsFor: больше 500 знаний (порции запроса)', () async {
    final db = memoryDb();
    await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);

    final ids = {for (var i = 0; i < 1100; i++) 'x$i', 't.a', 't.c'};
    final result = await db.decksDao.visibleQuestionsFor(ids);

    expect(result.keys.toSet(), {'t.a', 't.c'});
  });

  test('watchDecks отдаёт колоды по названию', () async {
    final db = memoryDb();
    final deck = goodDeck();
    await db.decksDao.replaceDeck(deck, downloadedAt: t0);
    final other = deck.copyWith(
      id: 'aaa',
      title: 'A',
      items: [deck.items[0].copyWith(id: 'a.1', questions: const [])],
    );
    await db.decksDao.replaceDeck(other, downloadedAt: t0);

    final list = await db.decksDao.watchDecks().first;
    expect(list.map((d) => d.id), ['aaa', 'fixture-good']);
  });
}
