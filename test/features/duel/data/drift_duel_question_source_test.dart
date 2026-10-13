// DriftDuelQuestionSource на drift в памяти: какие вопросы скачанной колоды
// попадают в дуэль (автопроверяемые, не скрытые, не из исчезнувших знаний).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_question_source.dart';

import '../../../helpers/db_fixtures.dart';
import '../../../helpers/deck_fixtures.dart';

/// Колода `fixture-good` плюс [n] знаний `m.<i>` с вопросами mcq и open.
Deck _deckWith(int n, {int version = 2, Set<int> drop = const {}}) {
  final json = readJsonFile(goodDeckPath);
  json['version'] = version;
  final items = json['items'] as List<dynamic>;
  final template = jsonEncode(items.first);
  for (var i = 1; i <= n; i++) {
    if (drop.contains(i)) continue;
    final copy = jsonDecode(
      template
          .replaceAll('"t.a.q1"', '"m.$i.q1"')
          .replaceAll('"t.a.q2"', '"m.$i.q2"')
          .replaceAll('"t.a"', '"m.$i"'),
    ) as Map<String, dynamic>;
    items.add(copy);
  }
  return Deck.fromJson(json);
}

void main() {
  late AppDatabase db;
  late DriftDuelQuestionSource source;

  setUp(() {
    db = memoryDb();
    source = DriftDuelQuestionSource(db.decksDao);
  });

  test('колоды нет на устройстве — null', () async {
    expect(await source.snapshot('fixture-good'), isNull);
  });

  test('только mcq: flip, open, cloze, order, find_error не берутся', () async {
    await db.decksDao.replaceDeck(_deckWith(0), downloadedAt: t0);
    final snapshot = (await source.snapshot('fixture-good'))!;
    expect(snapshot.deckVersion, 2);
    expect([for (final c in snapshot.candidates) c.questionId], ['t.a.q1']);
    expect(snapshot.candidates.single.itemId, 't.a');
  });

  test('вопросы нескольких знаний, у каждого свой itemId', () async {
    await db.decksDao.replaceDeck(_deckWith(4), downloadedAt: t0);
    final candidates = (await source.snapshot('fixture-good'))!.candidates;
    expect(candidates, hasLength(5));
    expect(
      {for (final c in candidates) c.questionId},
      {'t.a.q1', 'm.1.q1', 'm.2.q1', 'm.3.q1', 'm.4.q1'},
    );
    for (final c in candidates) {
      expect(c.questionId.startsWith(c.itemId), isTrue, reason: c.questionId);
    }
  });

  test('скрытые вопросы (жалобы) не берутся', () async {
    await db.decksDao.replaceDeck(_deckWith(4), downloadedAt: t0);
    await db.decksDao.hideQuestion('m.2.q1');
    await db.decksDao.replaceServerHiddenQuestions({'m.3.q1'});
    final ids = [
      for (final c in (await source.snapshot('fixture-good'))!.candidates)
        c.questionId,
    ];
    expect(ids, isNot(contains('m.2.q1')));
    expect(ids, isNot(contains('m.3.q1')));
    expect(ids, hasLength(3));
  });

  test('знания, исчезнувшие из новой версии, не берутся', () async {
    await db.decksDao.replaceDeck(_deckWith(3), downloadedAt: t0);
    await db.decksDao.replaceDeck(
      _deckWith(3, version: 3, drop: {1}),
      downloadedAt: t0,
    );
    final snapshot = (await source.snapshot('fixture-good'))!;
    expect(snapshot.deckVersion, 3);
    expect([
      for (final c in snapshot.candidates) c.questionId,
    ], isNot(contains('m.1.q1')));
    expect(snapshot.candidates, hasLength(3));
  });
}
