import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/sync/domain/sync_store.dart';

import '../../generated/schema.dart';
import '../../generated/schema_v1.dart' as v1;
import '../../generated/schema_v2.dart' as v2;
import '../../generated/schema_v3.dart' as v3;
import '../../generated/schema_v4.dart' as v4;

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
    await verifier.migrateAndValidate(db, 5);

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
      await verifier.migrateAndValidate(db, 5);

      final deck = await db.decksDao.getDeck('d');
      expect(deck?.title, 'Колода');
      expect(deck?.description, isEmpty);
      await db.settingsDao.write('new_per_day', '7');
      expect(await db.settingsDao.readAll(), {'new_per_day': '7'});
    },
  );

  test('v3 -> v4: outbox.user_id, sync_cursors, индекс неотправленных логов; '
      'данные и признаки «не отправлено» сохраняются', () async {
    final schema = await verifier.schemaAt(3);
    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO review_logs (id, user_id, deck_id, deck_version, item_id, "
      "question_id, question_type, rating, grade_source, duration_ms, "
      "reviewed_at) VALUES ('l1', 'u', 'd', 1, 'i1', 'q1', 'mcq', 3, 'auto', "
      "900, 1700000000)",
    );
    await oldDb.customStatement(
      "INSERT INTO user_item_state (user_id, item_id, deck_id, due, "
      "stability, difficulty, elapsed_days, scheduled_days, reps, lapses, "
      "state, updated_at, dirty) VALUES ('u', 'i1', 'd', 1700086400, 2.3, "
      "5.1, 0, 1, 1, 0, 2, 1700000000, 1)",
    );
    await oldDb.customStatement(
      "INSERT INTO outbox (kind, payload_json, created_at) "
      "VALUES ('report', '{}', 1700000000)",
    );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    // Неотправленное осталось неотправленным.
    final logs = await db.syncDao.unsyncedLogs('u', limit: 10);
    expect(logs.map((l) => l.id), ['l1']);
    final dirty = await db.syncDao.dirtyStates('u', limit: 10);
    expect(dirty.map((s) => s.itemId), ['i1']);
    // Старая запись outbox без владельца не уйдёт ни под чьей сессией.
    final outbox = await db.select(db.outbox).getSingle();
    expect(outbox.userId, '');
    expect(await db.syncDao.pendingOutbox('u', limit: 10), isEmpty);
    expect(await db.syncDao.cursor('u', SyncStream.itemStates), 0);
    final index = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_review_logs_unsynced'",
        )
        .get();
    expect(index, hasLength(1));
  });

  test('v4 -> v5: hidden_questions.source, прежние скрытые — серверные, '
      'жалобы и очередь не тронуты', () async {
    final schema = await verifier.schemaAt(4);
    final oldDb = v4.DatabaseAtV4(schema.newConnection());
    await oldDb.customStatement(
      "INSERT INTO hidden_questions (question_id) VALUES ('t.a.q1')",
    );
    await oldDb.customStatement(
      "INSERT INTO outbox (user_id, kind, payload_json, created_at) "
      "VALUES ('u', 'report', '{}', 1700000000)",
    );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    final hidden = await db.select(db.hiddenQuestions).getSingle();
    expect(hidden.questionId, 't.a.q1');
    expect(hidden.source, 'server');
    // Серверный список заменяется, локально скрытое остаётся.
    await db.decksDao.hideQuestion('t.a.q2');
    await db.decksDao.replaceServerHiddenQuestions({'t.b.q1'});
    expect(await db.decksDao.hiddenQuestionIds(), {'t.a.q2', 't.b.q1'});
    expect(await db.syncDao.pendingOutbox('u', limit: 10), hasLength(1));
  });

  test('схема приложения совпадает с дампом v5 (дамп не забыт)', () async {
    final schema = await verifier.schemaAt(5);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
  });
}
