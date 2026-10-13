// Вопросы дуэли из локальной колоды и открытые результаты на drift в памяти
// (T23, ADR-36): что годится для игры, а что нет.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_content_source.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_seen_store.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/duel_fixtures.dart';

void main() {
  group('DriftDuelContentSource', () {
    Future<DriftDuelContentSource> sourceWith(
      Deck? deck, {
      Set<String> hidden = const {},
    }) async {
      final db = memoryDb();
      if (deck != null) {
        await db.decksDao.replaceDeck(deck, downloadedAt: t0);
      }
      for (final id in hidden) {
        await db.decksDao.hideQuestion(id);
      }
      return DriftDuelContentSource(db.decksDao);
    }

    test('колоды нет на устройстве: null', () async {
      final source = await sourceWith(null);
      expect(await source.load(kDuelDeckId, duelQuestionIds()), isNull);
    });

    test('все вопросы есть: версия колоды и вопросы со знаниями', () async {
      final source = await sourceWith(duelDeck(version: 3));
      final content = (await source.load(kDuelDeckId, duelQuestionIds()))!;
      expect(content.deckVersion, 3);
      expect(content.questions.keys, duelQuestionIds());
      final first = content.questions[duelQuestionIds()[0]]!;
      expect(first.question.prompt, 'Вопрос номер 1');
      expect(first.item.explanationShort, 'Разбор 1');
      expect(first.isPlayable, isTrue);
    });

    test(
      'вопроса нет в колоде (id соперника устарел): его нет и в ответе',
      () async {
        final source = await sourceWith(duelDeck(n: 4));
        final content = (await source.load(kDuelDeckId, duelQuestionIds()))!;
        expect(content.questions.keys, duelQuestionIds(4));
      },
    );

    test('скрытый жалобой вопрос недоступен', () async {
      final source = await sourceWith(
        duelDeck(),
        hidden: {duelQuestionIds()[2]},
      );
      final content = (await source.load(kDuelDeckId, duelQuestionIds()))!;
      expect(content.questions.containsKey(duelQuestionIds()[2]), isFalse);
      expect(content.questions, hasLength(4));
    });

    test('вопрос другого формата (flip) не отдаётся', () async {
      final deck = duelDeck();
      final items = [...deck.items];
      final first = items[0];
      items[0] = first.copyWith(
        questions: [
          first.questions[0].copyWith(
            type: QuestionType.flip,
            payload: const QuestionPayload.flip(back: 'оборот'),
          ),
        ],
      );
      final source = await sourceWith(deck.copyWith(items: items));
      final content = (await source.load(kDuelDeckId, duelQuestionIds()))!;
      expect(content.questions.containsKey(duelQuestionIds()[0]), isFalse);
    });

    test('знание исчезло из версии (retired): вопрос недоступен', () async {
      final db = memoryDb();
      await db.decksDao.replaceDeck(duelDeck(), downloadedAt: t0);
      // Новая версия без пятого знания.
      final v3 = duelDeck(n: 4, version: 3);
      await db.decksDao.replaceDeck(v3, downloadedAt: t0);
      final content = (await DriftDuelContentSource(db.decksDao)
          .load(kDuelDeckId, duelQuestionIds()))!;
      expect(content.deckVersion, 3);
      expect(content.questions.keys, duelQuestionIds(4));
    });

    test('вопросы чужой колоды по тем же id не подмешиваются', () async {
      final db = memoryDb();
      await db.decksDao.replaceDeck(duelDeck(), downloadedAt: t0);
      await db.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
      final content = (await DriftDuelContentSource(db.decksDao)
          .load('fixture-good', duelQuestionIds()))!;
      expect(content.questions, isEmpty);
    });
  });

  group('DriftDuelSeenStore', () {
    test('помнит открытые результаты', () async {
      final db = memoryDb();
      final store = DriftDuelSeenStore(db.settingsDao);
      expect(await store.seenResults(), isEmpty);
      await store.markResultSeen('a');
      await store.markResultSeen('b');
      await store.markResultSeen('a');
      expect(await store.seenResults(), {'a', 'b'});
    });

    test('хранит не больше $kDuelSeenResultsLimit последних', () async {
      final db = memoryDb();
      final store = DriftDuelSeenStore(db.settingsDao);
      for (var i = 0; i < kDuelSeenResultsLimit + 5; i++) {
        await store.markResultSeen('d$i');
      }
      final seen = await store.seenResults();
      expect(seen, hasLength(kDuelSeenResultsLimit));
      expect(seen.contains('d0'), isFalse);
      expect(seen.contains('d${kDuelSeenResultsLimit + 4}'), isTrue);
    });

    test('битое значение считается пустым, запись его чинит', () async {
      final db = memoryDb();
      await db.settingsDao.write(kDuelSeenResultsSettingKey, '{не json');
      final store = DriftDuelSeenStore(db.settingsDao);
      expect(await store.seenResults(), isEmpty);
      await store.markResultSeen('a');
      expect(await store.seenResults(), {'a'});
      await db.settingsDao.write(kDuelSeenResultsSettingKey, '{"a": 1}');
      expect(await store.seenResults(), isEmpty);
    });
  });
}
