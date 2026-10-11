import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/data/drift_session_repository.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import 'db_fixtures.dart';

const sessionUser = 'u1';

/// Колода [id] из [n] знаний `<id>.1 .. <id>.n`, у каждого два вопроса
/// (`flip` и `find_error`, id `<знание>.q1/.q2`). Контент берётся из
/// `fixture-good`, ссылки на источники те же.
Deck bigDeck(String id, int n, {int version = 1}) {
  final template = goodDeck().items[2]; // t.c: flip + find_error
  return goodDeck().copyWith(
    id: id,
    version: version,
    items: [
      for (var k = 1; k <= n; k++)
        template.copyWith(
          id: '$id.$k',
          questions: [
            template.questions[0].copyWith(id: '$id.$k.q1'),
            template.questions[1].copyWith(id: '$id.$k.q2'),
          ],
        ),
    ],
  );
}

DriftSessionRepository repositoryFor(
  AppDatabase db, {
  String user = sessionUser,
}) => DriftSessionRepository(
  review: db.reviewDao,
  decks: db.decksDao,
  userId: () => user,
);

/// Записывает ответ по знанию в [at] (лог и состояние со сроком [due]).
Future<void> answerItem(
  AppDatabase db,
  String itemId, {
  required DateTime at,
  required DateTime due,
  String user = sessionUser,
  String deckId = 'fixture-good',
  String? questionId,
  String? logId,
}) => db.reviewDao.recordReview(
  userId: user,
  log: ReviewLog(
    id: logId ?? 'log-$user-$itemId-${at.microsecondsSinceEpoch}',
    deckId: deckId,
    deckVersion: 1,
    itemId: itemId,
    questionId: questionId ?? '$itemId.q1',
    questionType: QuestionType.mcq,
    rating: Rating.good,
    gradeSource: GradeSource.auto,
    durationMs: 1000,
    reviewedAt: at,
  ),
  state: stateFor(itemId, deckId: deckId, due: due, updatedAt: at),
);
