// ВРЕМЕННЫЙ SPIKE (T05): проверка drift на Android и web.
// Удалить при T09 вместе со spike_providers.dart, тестами и блоком на Home;
// настоящую схему делает T09.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'spike_database.g.dart';

class SpikeNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Какая реализация хранилища выбрана на web (opfsLocks, sharedIndexedDb, ...).
/// На Android и в тестах остаётся null. Показывается на Home для ручной проверки.
final ValueNotifier<String?> spikeWebStorage = ValueNotifier(null);

@DriftDatabase(tables: [SpikeNotes])
class SpikeDatabase extends _$SpikeDatabase {
  SpikeDatabase(super.e);

  SpikeDatabase.defaults()
    : super(
        driftDatabase(
          name: 'mater_spike',
          web: DriftWebOptions(
            // Относительные URL: разрешаются от <base href>, поэтому работают
            // и на корне, и на подпути GitHub Pages (/<repo>/).
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            onResult: (result) =>
                spikeWebStorage.value = result.chosenImplementation.name,
          ),
        ),
      );

  @override
  int get schemaVersion => 1;

  Future<int> addNote(String text, DateTime createdAt) => into(
    spikeNotes,
  ).insert(SpikeNotesCompanion.insert(body: text, createdAt: createdAt));

  Stream<List<SpikeNote>> watchNotes() =>
      (select(spikeNotes)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();
}
