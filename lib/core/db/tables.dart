// Локальная схема (ТЗ §7.3, T09). Время хранится как unix-секунды (UTC),
// на выходе из DAO — всегда UTC.
import 'package:drift/drift.dart';

import '../sync/outbox_entry.dart';

// Суффикс Row: имена Deck, Question и т.п. заняты доменными моделями.

/// Скачанные колоды.
@DataClassName('DeckRow')
class Decks extends Table {
  TextColumn get id => text()();
  IntColumn get version => integer()();
  TextColumn get title => text()();
  TextColumn get topic => text()();
  TextColumn get lang => text()();
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Знания. `id` глобально уникален между колодами (ADR-21), поэтому PK
/// `user_item_state` обходится без `deck_id`.
@DataClassName('ItemRow')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get title => text()();
  TextColumn get fact => text()();
  TextColumn get explanationShort => text()();
  TextColumn get explanationLong => text()();

  /// JSON-массив `ItemRef` (ссылки вместе с названием и URL источника).
  TextColumn get refsJson => text()();

  /// Знания нет в последней версии колоды.
  BoolColumn get retired => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Варианты вопросов.
@DataClassName('QuestionRow')
@TableIndex(name: 'idx_questions_item_id', columns: {#itemId})
class Questions extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(Items, #id)();

  /// `QuestionType.wire`: `mcq`, `find_error`, ...
  TextColumn get type => text()();
  TextColumn get prompt => text()();

  /// `QuestionPayload.toJson()`, вместе с ключом `type` (ADR-18).
  TextColumn get payloadJson => text()();
  TextColumn get explanationShort => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// FSRS-состояние знания у пользователя; пока знание не показывали, строки нет.
/// Поля — по §7.2 плюс `dirty` (ещё не отправлено на сервер).
@DataClassName('UserItemStateRow')
@TableIndex(name: 'idx_user_item_state_due', columns: {#due})
class UserItemStates extends Table {
  @override
  String get tableName => 'user_item_state';

  TextColumn get userId => text()();
  TextColumn get itemId => text()();
  TextColumn get deckId => text()();
  DateTimeColumn get due => dateTime()();
  RealColumn get stability => real()();
  RealColumn get difficulty => real()();
  IntColumn get elapsedDays => integer()();
  IntColumn get scheduledDays => integer()();
  IntColumn get reps => integer()();
  IntColumn get lapses => integer()();

  /// `SrsState.code`.
  IntColumn get state => integer()();
  DateTimeColumn get lastReview => dateTime().nullable()();
  TextColumn get lastQuestionId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {userId, itemId};
}

/// Журнал ответов. `id` — клиентский uuid, синхронизация идемпотентна по нему.
@DataClassName('ReviewLogRow')
class ReviewLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get deckId => text()();
  IntColumn get deckVersion => integer()();
  TextColumn get itemId => text()();
  TextColumn get questionId => text()();

  /// `QuestionType.wire`.
  TextColumn get questionType => text()();

  /// `Rating.code`.
  IntColumn get rating => integer()();

  /// `GradeSource.wire`: self, auto, llm, override.
  TextColumn get gradeSource => text()();
  RealColumn get llmScore => real().nullable()();
  TextColumn get answerText => text().nullable()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get reviewedAt => dateTime()();

  /// Пусто, пока лог не отправлен на сервер.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Очередь отправки для того, что не покрыто `dirty` и `synced_at`.
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<OutboxKind>()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

/// Вопросы, скрытые по жалобам (приходят с сервера).
@DataClassName('HiddenQuestionRow')
class HiddenQuestions extends Table {
  TextColumn get questionId => text()();

  @override
  Set<Column> get primaryKey => {questionId};
}
