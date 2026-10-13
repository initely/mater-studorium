import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/catalog/domain/deck.dart';
import '../../features/catalog/domain/item_ref.dart';
import '../../features/catalog/domain/local_deck.dart';
import '../../features/catalog/domain/local_item.dart';
import '../../features/catalog/domain/question.dart';
import '../errors/app_error.dart';
import 'database.dart';
import 'mappers.dart';
import 'tables.dart';

part 'decks_dao.g.dart';

/// Контент: колоды, знания, вопросы и скрытые вопросы. Без бизнес-логики.
@DriftAccessor(tables: [Decks, Items, Questions, HiddenQuestions])
class DecksDao extends DatabaseAccessor<AppDatabase> with _$DecksDaoMixin {
  DecksDao(super.attachedDatabase);

  /// Записывает колоду целиком одной транзакцией: новая колода или замена
  /// версии. Знания и вопросы upsert-ятся (прогресс по знаниям не трогаем);
  /// знания, исчезнувшие из версии, получают `retired = true`; вопросы,
  /// исчезнувшие у оставшегося знания, удаляются.
  ///
  /// Бросает [ItemIdCollisionError], если `id` знания уже принадлежит другой
  /// колоде (ADR-21), и [QuestionIdCollisionError], если так же совпал `id`
  /// вопроса (иначе upsert перезаписал бы вопрос чужой колоды; валидатор
  /// колоды это не ловит, он видит одну колоду); тогда не записывается ничего.
  Future<void> replaceDeck(Deck deck, {required DateTime downloadedAt}) {
    return transaction(() async {
      final itemIds = [for (final i in deck.items) i.id];

      final clash =
          await (select(items)
                ..where(
                  (t) => t.id.isIn(itemIds) & t.deckId.equals(deck.id).not(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (clash != null) throw ItemIdCollisionError(clash.id, clash.deckId);

      final allQuestionIds = [
        for (final i in deck.items)
          for (final q in i.questions) q.id,
      ];
      final qClash =
          await (select(
                  questions,
                ).join([innerJoin(items, items.id.equalsExp(questions.itemId))])
                ..where(
                  questions.id.isIn(allQuestionIds) &
                      items.deckId.equals(deck.id).not(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (qClash != null) {
        throw QuestionIdCollisionError(
          qClash.readTable(questions).id,
          qClash.readTable(items).deckId,
        );
      }

      await into(decks).insertOnConflictUpdate(
        DecksCompanion.insert(
          id: deck.id,
          version: deck.version,
          title: deck.title,
          topic: deck.topic,
          lang: deck.lang,
          description: Value(deck.description),
          downloadedAt: downloadedAt.toUtc(),
        ),
      );

      final sources = {for (final s in deck.sources) s.id: s};
      for (final item in deck.items) {
        final refs = [
          for (final r in item.refs)
            ItemRef(
              sourceId: r.sourceId,
              quote: r.quote,
              quoteUnverifiable: r.quoteUnverifiable,
              sourceTitle: sources[r.sourceId]!.title,
              url: sources[r.sourceId]!.url,
              license: sources[r.sourceId]!.license,
            ),
        ];
        await into(items).insertOnConflictUpdate(
          ItemsCompanion.insert(
            id: item.id,
            deckId: deck.id,
            title: item.title,
            fact: item.fact,
            explanationShort: item.explanationShort,
            explanationLong: item.explanationLong,
            refsJson: jsonEncode([for (final r in refs) r.toJson()]),
            retired: const Value(false),
          ),
        );

        final questionIds = [for (final q in item.questions) q.id];
        await (delete(questions)..where(
              (q) => q.itemId.equals(item.id) & q.id.isIn(questionIds).not(),
            ))
            .go();
        for (final q in item.questions) {
          await into(questions).insertOnConflictUpdate(
            QuestionsCompanion.insert(
              id: q.id,
              itemId: item.id,
              type: q.type.wire,
              prompt: q.prompt,
              payloadJson: jsonEncode(q.payload.toJson()),
              explanationShort: Value(q.explanationShort),
            ),
          );
        }
      }

      await (update(items)
            ..where((t) => t.deckId.equals(deck.id) & t.id.isIn(itemIds).not()))
          .write(const ItemsCompanion(retired: Value(true)));
    });
  }

  /// Удаляет колоду с устройства: строки `questions`, `items` и `decks`
  /// одной транзакцией. Прогресс (`user_item_state`, `review_logs`) не
  /// трогается (ADR-27): при повторном скачивании колоды он подхватится по
  /// стабильным `item_id` (ADR-21). Скрытые вопросы тоже остаются.
  Future<void> deleteDeck(String id) => transaction(() async {
    final itemIds = selectOnly(items)
      ..addColumns([items.id])
      ..where(items.deckId.equals(id));
    await (delete(questions)..where((q) => q.itemId.isInQuery(itemIds))).go();
    await (delete(items)..where((i) => i.deckId.equals(id))).go();
    await (delete(decks)..where((d) => d.id.equals(id))).go();
  });

  Future<LocalDeck?> getDeck(String id) async {
    final row = await (select(
      decks,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    return row == null ? null : deckFromRow(row);
  }

  Stream<List<LocalDeck>> watchDecks() =>
      (select(decks)..orderBy([(d) => OrderingTerm.asc(d.title)])).watch().map(
        (rows) => rows.map(deckFromRow).toList(),
      );

  /// Колода по id; `null`, пока её нет на устройстве (и после удаления).
  Stream<LocalDeck?> watchDeck(String id) =>
      (select(decks)..where((d) => d.id.equals(id))).watchSingleOrNull().map(
        (row) => row == null ? null : deckFromRow(row),
      );

  Future<LocalItem?> getItem(String id) async {
    final row = await (select(
      items,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
    return row == null ? null : itemFromRow(row);
  }

  Future<Question?> getQuestion(String id) async {
    final row = await (select(
      questions,
    )..where((q) => q.id.equals(id))).getSingleOrNull();
    return row == null ? null : questionFromRow(row);
  }

  /// Вопросы знания без скрытых, в порядке колоды.
  Future<List<Question>> visibleQuestions(String itemId) async {
    final rows =
        await (select(questions)
              ..where(
                (q) =>
                    q.itemId.equals(itemId) &
                    q.id.isNotInQuery(
                      selectOnly(hiddenQuestions)
                        ..addColumns([hiddenQuestions.questionId]),
                    ),
              )
              ..orderBy([
                (q) => OrderingTerm.asc(
                  const CustomExpression<int>('questions.rowid'),
                ),
              ]))
            .get();
    return rows.map(questionFromRow).toList();
  }

  /// Видимые вопросы нескольких знаний одним запросом: `item_id` -> вопросы
  /// в порядке колоды. Знание без видимых вопросов в карте отсутствует.
  Future<Map<String, List<Question>>> visibleQuestionsFor(
    Set<String> itemIds,
  ) async {
    final result = <String, List<Question>>{};
    final ids = itemIds.toList();
    // Лимит переменных SQLite: порциями.
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final rows =
          await (select(questions)
                ..where(
                  (q) =>
                      q.itemId.isIn(chunk) &
                      q.id.isNotInQuery(
                        selectOnly(hiddenQuestions)
                          ..addColumns([hiddenQuestions.questionId]),
                      ),
                )
                ..orderBy([
                  (q) => OrderingTerm.asc(
                    const CustomExpression<int>('questions.rowid'),
                  ),
                ]))
              .get();
      for (final row in rows) {
        (result[row.itemId] ??= []).add(questionFromRow(row));
      }
    }
    return result;
  }

  /// Скрывает вопрос у самого пользователя (жалоба, ТЗ M11): `source =
  /// local`; уже скрытый сервером вопрос становится и локально скрытым.
  Future<void> hideQuestion(String questionId) => into(hiddenQuestions).insert(
    HiddenQuestionsCompanion.insert(
      questionId: questionId,
      source: const Value(kHiddenSourceLocal),
    ),
    mode: InsertMode.insertOrReplace,
  );

  /// Возвращает вопрос, скрытый самим пользователем (`source = local`).
  /// Скрытое сервером остаётся скрытым.
  Future<void> unhideLocalQuestion(String questionId) =>
      (delete(hiddenQuestions)..where(
            (h) =>
                h.questionId.equals(questionId) &
                h.source.equals(kHiddenSourceLocal),
          ))
          .go();

  /// Заменяет серверный список скрытых целиком (pull `hidden_questions()`,
  /// ТЗ §7.3, шаг 5); `local` не трогает, при совпадении остаётся `local`.
  Future<void> replaceServerHiddenQuestions(Set<String> questionIds) =>
      transaction(() async {
        await (delete(
          hiddenQuestions,
        )..where((h) => h.source.equals(kHiddenSourceServer))).go();
        await batch(
          (b) => b.insertAll(hiddenQuestions, [
            for (final id in questionIds)
              HiddenQuestionsCompanion.insert(questionId: id),
          ], mode: InsertMode.insertOrIgnore),
        );
      });

  /// Вопросы колоды заданных форматов [wireTypes] (`QuestionType.wire`) для
  /// дуэли (T22): без скрытых и без знаний, исчезнувших из версии колоды.
  /// Пары `(id вопроса, id знания)` в порядке колоды.
  Future<List<({String questionId, String itemId})>> questionsOfTypes(
    String deckId,
    Set<String> wireTypes,
  ) async {
    final query =
        select(questions)
            .join([innerJoin(items, items.id.equalsExp(questions.itemId))])
          ..where(
            items.deckId.equals(deckId) &
                items.retired.equals(false) &
                questions.type.isIn(wireTypes) &
                questions.id.isNotInQuery(
                  selectOnly(hiddenQuestions)
                    ..addColumns([hiddenQuestions.questionId]),
                ),
          )
          ..orderBy([
            OrderingTerm.asc(const CustomExpression<int>('questions.rowid')),
          ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        (questionId: row.read(questions.id)!, itemId: row.read(items.id)!),
    ];
  }

  Future<Set<String>> hiddenQuestionIds() async {
    final rows = await select(hiddenQuestions).get();
    return {for (final r in rows) r.questionId};
  }
}
