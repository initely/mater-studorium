// ВРЕМЕННЫЙ SPIKE (T05): удалить при T09.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/clock.dart';
import 'spike_database.dart';

/// В тестах подменяется на `SpikeDatabase(NativeDatabase.memory())`.
final spikeDatabaseProvider = Provider<SpikeDatabase>((ref) {
  final db = SpikeDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});

final spikeNotesProvider = StreamProvider<List<SpikeNote>>(
  (ref) => ref.watch(spikeDatabaseProvider).watchNotes(),
);

/// Добавляет запись с временем из [clockProvider].
Future<void> addSpikeNote(WidgetRef ref, String text) =>
    ref.read(spikeDatabaseProvider).addNote(text, ref.read(clockProvider)());
