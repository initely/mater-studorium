// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_dao.dart';

// ignore_for_file: type=lint
mixin _$ReviewDaoMixin on DatabaseAccessor<AppDatabase> {
  $DecksTable get decks => attachedDatabase.decks;
  $ItemsTable get items => attachedDatabase.items;
  $QuestionsTable get questions => attachedDatabase.questions;
  $HiddenQuestionsTable get hiddenQuestions => attachedDatabase.hiddenQuestions;
  $UserItemStatesTable get userItemStates => attachedDatabase.userItemStates;
  $ReviewLogsTable get reviewLogs => attachedDatabase.reviewLogs;
  $OutboxTable get outbox => attachedDatabase.outbox;
  ReviewDaoManager get managers => ReviewDaoManager(this);
}

class ReviewDaoManager {
  final _$ReviewDaoMixin _db;
  ReviewDaoManager(this._db);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db.attachedDatabase, _db.decks);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db.attachedDatabase, _db.items);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db.attachedDatabase, _db.questions);
  $$HiddenQuestionsTableTableManager get hiddenQuestions =>
      $$HiddenQuestionsTableTableManager(
        _db.attachedDatabase,
        _db.hiddenQuestions,
      );
  $$UserItemStatesTableTableManager get userItemStates =>
      $$UserItemStatesTableTableManager(
        _db.attachedDatabase,
        _db.userItemStates,
      );
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db.attachedDatabase, _db.reviewLogs);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db.attachedDatabase, _db.outbox);
}
