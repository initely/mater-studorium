import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';

import '../../generated/schema.dart';
import '../../generated/schema_v1.dart' as v1;
import '../../generated/schema_v2.dart' as v2;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 -> v2: появляется индекс журнала, данные сохраняются', () async {
    final schema = await verifier.schemaAt(1);

    // Данные v1 до миграции.
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO review_logs (id, user_id, deck_id, deck_version, item_id, "
      "question_id, question_type, rating, grade_source, duration_ms, "
      "reviewed_at) VALUES ('l1', 'u', 'd', 1, 'i1', 'q1', 'mcq', 3, 'auto', "
      "900, 1700000000)",
    );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    // Схема после миграции совпадает с эталонной v2 (таблицы, индексы).
    await verifier.migrateAndValidate(db, 3);

    final index = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_review_logs_user_item_time'",
        )
        .get();
    expect(index, hasLength(1));
    final logs = await db.select(db.reviewLogs).get();
    expect(logs.map((l) => l.id), ['l1']);
  });

  test(
    'v2 -> v3: app_settings и decks.description, данные сохраняются',
    () async {
      final schema = await verifier.schemaAt(2);
      final oldDb = v2.DatabaseAtV2(schema.newConnection());
      await oldDb.customStatement(
        "INSERT INTO decks (id, version, title, topic, lang, downloaded_at) "
        "VALUES ('d', 1, 'Колода', 'infosec', 'ru', 1700000000)",
      );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);

      final deck = await db.decksDao.getDeck('d');
      expect(deck?.title, 'Колода');
      expect(deck?.description, isEmpty);
      await db.settingsDao.write('new_per_day', '7');
      expect(await db.settingsDao.readAll(), {'new_per_day': '7'});
    },
  );

  test('схема приложения совпадает с дампом v3 (дамп не забыт)', () async {
    final schema = await verifier.schemaAt(3);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
  });
}
