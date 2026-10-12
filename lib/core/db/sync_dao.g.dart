// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserItemStatesTable get userItemStates => attachedDatabase.userItemStates;
  $ReviewLogsTable get reviewLogs => attachedDatabase.reviewLogs;
  $OutboxTable get outbox => attachedDatabase.outbox;
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$UserItemStatesTableTableManager get userItemStates =>
      $$UserItemStatesTableTableManager(
        _db.attachedDatabase,
        _db.userItemStates,
      );
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db.attachedDatabase, _db.reviewLogs);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db.attachedDatabase, _db.outbox);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
}
