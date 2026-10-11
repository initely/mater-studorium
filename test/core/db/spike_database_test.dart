// ВРЕМЕННЫЙ SPIKE (T05): удалить при T09.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/spike_database.dart';

void main() {
  final t1 = DateTime.utc(2026, 10, 11, 12);
  final t2 = DateTime.utc(2026, 10, 11, 13);

  test('addNote и watchNotes: новые записи сверху, время в UTC', () async {
    final db = SpikeDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.addNote('первая', t1);
    await db.addNote('вторая', t2);

    final notes = await db.watchNotes().first;
    expect(notes.map((n) => n.body), ['вторая', 'первая']);
    expect(notes.first.createdAt.toUtc(), t2);
  });

  test('данные переживают закрытие и повторное открытие файла', () async {
    final dir = await Directory.systemTemp.createTemp('spike_db_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/spike.sqlite');

    final first = SpikeDatabase(NativeDatabase(file));
    await first.addNote('останется', t1);
    await first.close();

    final second = SpikeDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final notes = await second.watchNotes().first;
    expect(notes.map((n) => n.body), ['останется']);
  });
}
