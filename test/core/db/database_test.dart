import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';

import '../../helpers/db_fixtures.dart';

void main() {
  test('БД создаётся в памяти: таблицы и индексы по ТЗ', () async {
    final db = memoryDb();
    expect(db.schemaVersion, 2);

    final master = await db
        .customSelect('SELECT type, name FROM sqlite_master')
        .get();
    final names = {for (final r in master) r.read<String>('name')};
    expect(
      names,
      containsAll([
        'decks',
        'items',
        'questions',
        'user_item_state',
        'review_logs',
        'outbox',
        'hidden_questions',
        'idx_user_item_state_due',
        'idx_questions_item_id',
        'idx_review_logs_user_item_time',
      ]),
    );
  });

  test('внешние ключи включены', () async {
    final db = memoryDb();
    final r = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(r.read<int>('foreign_keys'), 1);
  });

  test('данные переживают закрытие и повторное открытие файла', () async {
    final dir = await Directory.systemTemp.createTemp('mater_db_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await first.decksDao.replaceDeck(goodDeck(), downloadedAt: t0);
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect((await second.decksDao.getDeck('fixture-good'))!.version, 2);
  });
}
