// Строки drift <-> доменные модели. Здесь только перекладывание полей.
import 'dart:convert';

import '../../features/catalog/domain/item_ref.dart';
import '../../features/catalog/domain/local_deck.dart';
import '../../features/catalog/domain/local_item.dart';
import '../../features/catalog/domain/question.dart';
import '../../features/catalog/domain/question_payload.dart';
import '../../features/catalog/domain/question_type.dart';
import '../../features/srs/domain/item_state.dart';
import '../../features/srs/domain/srs_state.dart';
import '../sync/outbox_entry.dart';
import 'database.dart';

LocalDeck deckFromRow(DeckRow r) => LocalDeck(
  id: r.id,
  version: r.version,
  title: r.title,
  topic: r.topic,
  lang: r.lang,
  downloadedAt: r.downloadedAt.toUtc(),
);

LocalItem itemFromRow(ItemRow r) => LocalItem(
  id: r.id,
  deckId: r.deckId,
  title: r.title,
  fact: r.fact,
  explanationShort: r.explanationShort,
  explanationLong: r.explanationLong,
  refs: [
    for (final ref in jsonDecode(r.refsJson) as List<dynamic>)
      ItemRef.fromJson(ref as Map<String, dynamic>),
  ],
  retired: r.retired,
);

Question questionFromRow(QuestionRow r) => Question(
  id: r.id,
  type: QuestionType.fromWire(r.type),
  prompt: r.prompt,
  explanationShort: r.explanationShort,
  payload: QuestionPayload.fromJson(
    jsonDecode(r.payloadJson) as Map<String, dynamic>,
  ),
);

ItemState itemStateFromRow(UserItemStateRow r) => ItemState(
  itemId: r.itemId,
  deckId: r.deckId,
  due: r.due.toUtc(),
  stability: r.stability,
  difficulty: r.difficulty,
  elapsedDays: r.elapsedDays,
  scheduledDays: r.scheduledDays,
  reps: r.reps,
  lapses: r.lapses,
  state: SrsState.fromCode(r.state),
  lastReview: r.lastReview?.toUtc(),
  lastQuestionId: r.lastQuestionId,
  updatedAt: r.updatedAt.toUtc(),
);

OutboxEntry outboxFromRow(OutboxRow r) => OutboxEntry(
  id: r.id,
  kind: r.kind,
  payloadJson: r.payloadJson,
  createdAt: r.createdAt.toUtc(),
  attempts: r.attempts,
);
