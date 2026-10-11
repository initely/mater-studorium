import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// ignore: unused_import
import '../sync/outbox_entry.dart'; // нужен сгенерированному коду (textEnum)
import 'decks_dao.dart';
import 'review_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Decks,
    Items,
    Questions,
    UserItemStates,
    ReviewLogs,
    Outbox,
    HiddenQuestions,
  ],
  daos: [DecksDao, ReviewDao],
)
class AppDatabase extends _$AppDatabase {
  /// В тестах: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase(super.e);

  /// Native: файл в каталоге приложения. Web: wasm + воркер из `web/` (T05).
  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'mater_studorium',
          web: DriftWebOptions(
            // Относительные URL: разрешаются от <base href>, поэтому работают
            // и на корне, и на подпути GitHub Pages (/<repo>/).
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Каждое изменение схемы: поднять schemaVersion, `dart run drift_dev
    // schema dump lib/core/db/database.dart drift_schemas/`, затем
    // `schema generate drift_schemas/ test/generated/` и проверить миграцию
    // в test/core/db/migration_test.dart.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createIndex(idxReviewLogsUserItemTime);
      }
    },
    beforeOpen: (details) async {
      // Внешние ключи в SQLite выключены по умолчанию.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
