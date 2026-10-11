import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/session/domain/review_log.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';

import 'deck_fixtures.dart';

/// БД в памяти; закрывается в конце теста.
AppDatabase memoryDb() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Колода `fixture-good` (версия 2, знания t.a, t.b, t.c).
Deck goodDeck() => Deck.fromJson(readJsonFile(goodDeckPath));

final t0 = DateTime.utc(2026, 10, 11, 12);

ItemState stateFor(
  String itemId, {
  String deckId = 'fixture-good',
  required DateTime due,
  DateTime? updatedAt,
}) => ItemState(
  itemId: itemId,
  deckId: deckId,
  due: due,
  stability: 4.5,
  difficulty: 5.25,
  elapsedDays: 2,
  scheduledDays: 4,
  reps: 3,
  lapses: 1,
  state: SrsState.review,
  lastReview: t0,
  lastQuestionId: '$itemId.q1',
  updatedAt: updatedAt ?? t0,
);

ReviewLog logFor(String itemId, {String id = 'log-1'}) => ReviewLog(
  id: id,
  deckId: 'fixture-good',
  deckVersion: 2,
  itemId: itemId,
  questionId: '$itemId.q1',
  questionType: QuestionType.findError,
  rating: Rating.hard,
  gradeSource: GradeSource.override,
  llmScore: 0.6,
  answerText: 'ответ',
  durationMs: 4200,
  reviewedAt: t0,
);
