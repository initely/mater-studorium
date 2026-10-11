// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spike_database.dart';

// ignore_for_file: type=lint
class $SpikeNotesTable extends SpikeNotes
    with TableInfo<$SpikeNotesTable, SpikeNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikeNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, body, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spike_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpikeNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpikeNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikeNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SpikeNotesTable createAlias(String alias) {
    return $SpikeNotesTable(attachedDatabase, alias);
  }
}

class SpikeNote extends DataClass implements Insertable<SpikeNote> {
  final int id;
  final String body;
  final DateTime createdAt;
  const SpikeNote({
    required this.id,
    required this.body,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SpikeNotesCompanion toCompanion(bool nullToAbsent) {
    return SpikeNotesCompanion(
      id: Value(id),
      body: Value(body),
      createdAt: Value(createdAt),
    );
  }

  factory SpikeNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikeNote(
      id: serializer.fromJson<int>(json['id']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SpikeNote copyWith({int? id, String? body, DateTime? createdAt}) => SpikeNote(
    id: id ?? this.id,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
  );
  SpikeNote copyWithCompanion(SpikeNotesCompanion data) {
    return SpikeNote(
      id: data.id.present ? data.id.value : this.id,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikeNote(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, body, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpikeNote &&
          other.id == this.id &&
          other.body == this.body &&
          other.createdAt == this.createdAt);
}

class SpikeNotesCompanion extends UpdateCompanion<SpikeNote> {
  final Value<int> id;
  final Value<String> body;
  final Value<DateTime> createdAt;
  const SpikeNotesCompanion({
    this.id = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SpikeNotesCompanion.insert({
    this.id = const Value.absent(),
    required String body,
    required DateTime createdAt,
  }) : body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<SpikeNote> custom({
    Expression<int>? id,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SpikeNotesCompanion copyWith({
    Value<int>? id,
    Value<String>? body,
    Value<DateTime>? createdAt,
  }) {
    return SpikeNotesCompanion(
      id: id ?? this.id,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpikeNotesCompanion(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$SpikeDatabase extends GeneratedDatabase {
  _$SpikeDatabase(QueryExecutor e) : super(e);
  $SpikeDatabaseManager get managers => $SpikeDatabaseManager(this);
  late final $SpikeNotesTable spikeNotes = $SpikeNotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [spikeNotes];
}

typedef $$SpikeNotesTableCreateCompanionBuilder =
    SpikeNotesCompanion Function({
      Value<int> id,
      required String body,
      required DateTime createdAt,
    });
typedef $$SpikeNotesTableUpdateCompanionBuilder =
    SpikeNotesCompanion Function({
      Value<int> id,
      Value<String> body,
      Value<DateTime> createdAt,
    });

class $$SpikeNotesTableFilterComposer
    extends Composer<_$SpikeDatabase, $SpikeNotesTable> {
  $$SpikeNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpikeNotesTableOrderingComposer
    extends Composer<_$SpikeDatabase, $SpikeNotesTable> {
  $$SpikeNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpikeNotesTableAnnotationComposer
    extends Composer<_$SpikeDatabase, $SpikeNotesTable> {
  $$SpikeNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SpikeNotesTableTableManager
    extends
        RootTableManager<
          _$SpikeDatabase,
          $SpikeNotesTable,
          SpikeNote,
          $$SpikeNotesTableFilterComposer,
          $$SpikeNotesTableOrderingComposer,
          $$SpikeNotesTableAnnotationComposer,
          $$SpikeNotesTableCreateCompanionBuilder,
          $$SpikeNotesTableUpdateCompanionBuilder,
          (
            SpikeNote,
            BaseReferences<_$SpikeDatabase, $SpikeNotesTable, SpikeNote>,
          ),
          SpikeNote,
          PrefetchHooks Function()
        > {
  $$SpikeNotesTableTableManager(_$SpikeDatabase db, $SpikeNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpikeNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpikeNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpikeNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) =>
                  SpikeNotesCompanion(id: id, body: body, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String body,
                required DateTime createdAt,
              }) => SpikeNotesCompanion.insert(
                id: id,
                body: body,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpikeNotesTable, SpikeNote>(table),
                  BaseReferences<_$SpikeDatabase, $SpikeNotesTable, SpikeNote>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikeNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpikeDatabase,
      $SpikeNotesTable,
      SpikeNote,
      $$SpikeNotesTableFilterComposer,
      $$SpikeNotesTableOrderingComposer,
      $$SpikeNotesTableAnnotationComposer,
      $$SpikeNotesTableCreateCompanionBuilder,
      $$SpikeNotesTableUpdateCompanionBuilder,
      (SpikeNote, BaseReferences<_$SpikeDatabase, $SpikeNotesTable, SpikeNote>),
      SpikeNote,
      PrefetchHooks Function()
    >;

class $SpikeDatabaseManager {
  final _$SpikeDatabase _db;
  $SpikeDatabaseManager(this._db);
  $$SpikeNotesTableTableManager get spikeNotes =>
      $$SpikeNotesTableTableManager(_db, _db.spikeNotes);
}
