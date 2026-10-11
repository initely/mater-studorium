// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decks_dao.dart';

// ignore_for_file: type=lint
mixin _$DecksDaoMixin on DatabaseAccessor<AppDatabase> {
  $DecksTable get decks => attachedDatabase.decks;
  $ItemsTable get items => attachedDatabase.items;
  $QuestionsTable get questions => attachedDatabase.questions;
  $HiddenQuestionsTable get hiddenQuestions => attachedDatabase.hiddenQuestions;
  DecksDaoManager get managers => DecksDaoManager(this);
}

class DecksDaoManager {
  final _$DecksDaoMixin _db;
  DecksDaoManager(this._db);
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
}
