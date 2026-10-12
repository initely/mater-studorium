// DriftReportsRepository на drift в памяти (T20, M11, AC11.1): жалоба и
// скрытие вопроса — одна транзакция, ошибки типизированы.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/reports/data/drift_reports_repository.dart';
import 'package:mater_studorium/features/reports/domain/report_reason.dart';

import '../../../helpers/db_fixtures.dart';

final _now = DateTime.utc(2026, 10, 12, 10);

void main() {
  late AppDatabase db;
  var user = 'u1';
  var ids = 0;

  DriftReportsRepository repo({void Function()? onQueued}) =>
      DriftReportsRepository(
        db: db,
        userId: () => user,
        clock: () => _now,
        newId: () =>
            'aaaaaaaa-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}',
        onQueued: onQueued,
      );

  setUp(() {
    db = memoryDb();
    user = 'u1';
    ids = 0;
  });

  Future<void> report(DriftReportsRepository r, {String? comment}) =>
      r.reportQuestion(
        deckId: 'infosec',
        deckVersion: 2,
        questionId: 'xss.q1',
        questionText: 'Что такое XSS?',
        reason: ReportReason.wrongAnswer,
        comment: comment,
      );

  test(
    'запись в очередь под текущим пользователем и скрытие вопроса',
    () async {
      await report(repo(), comment: '  в разборе ошибка  ');

      final row = (await db.select(db.outbox).get()).single;
      expect(row.kind.name, 'report');
      expect(row.userId, 'u1');
      expect(row.createdAt.toUtc(), _now);
      expect(row.attempts, 0);
      expect(jsonDecode(row.payloadJson), {
        'id': 'aaaaaaaa-0000-4000-8000-000000000001',
        'deck_id': 'infosec',
        'deck_version': 2,
        'question_id': 'xss.q1',
        'reason': 'wrong_answer',
        'comment': 'в разборе ошибка',
        'question_text': 'Что такое XSS?',
      });
      expect(await db.decksDao.hiddenQuestionIds(), {'xss.q1'});
      final hidden = await db.select(db.hiddenQuestions).getSingle();
      expect(hidden.source, 'local');
    },
  );

  test(
    'жалоба на вопрос, уже скрытый сервером, делает скрытие локальным',
    () async {
      await db.decksDao.replaceServerHiddenQuestions({'xss.q1'});
      await report(repo());
      await db.decksDao.replaceServerHiddenQuestions({});
      expect(await db.decksDao.hiddenQuestionIds(), {'xss.q1'});
    },
  );

  test('ошибка записи откатывает обе части: ни очереди, ни скрытия', () async {
    // Ломаем таблицу очереди: вставка в неё падает после скрытия?
    // Порядок в репозитории — очередь, затем скрытие; ломаем скрытие,
    // чтобы очередь уже была записана к моменту сбоя.
    await db.customStatement('DROP TABLE hidden_questions');
    await expectLater(report(repo()), throwsA(isA<LocalStorageError>()));
    expect(
      await db.select(db.outbox).get(),
      isEmpty,
      reason: 'очередь откатилась вместе с неудавшимся скрытием',
    );
  });

  test('ошибка очереди: вопрос не скрыт', () async {
    await db.customStatement('DROP TABLE outbox');
    await expectLater(report(repo()), throwsA(isA<LocalStorageError>()));
    expect(await db.decksDao.hiddenQuestionIds(), isEmpty);
  });

  test('нет сессии: AuthError как есть, ничего не записано', () async {
    final r = DriftReportsRepository(
      db: db,
      userId: () => throw const AuthError('нет сессии'),
      clock: () => _now,
      newId: () => 'aaaaaaaa-0000-4000-8000-000000000001',
    );
    await expectLater(report(r), throwsA(isA<AuthError>()));
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.decksDao.hiddenQuestionIds(), isEmpty);
  });

  test('синхронизацию просят только после успешной записи', () async {
    var asked = 0;
    await db.customStatement('DROP TABLE outbox');
    await expectLater(
      report(repo(onQueued: () => asked++)),
      throwsA(isA<LocalStorageError>()),
    );
    expect(asked, 0);
  });

  test('очистка текста при создании: управляющие символы, длина', () async {
    await report(repo(), comment: 'при\u0000ве\u0001т ${'я' * 600}');
    final payload = jsonDecode(
      (await db.select(db.outbox).getSingle()).payloadJson,
    ) as Map<String, dynamic>;
    expect((payload['comment'] as String).length, 500);
    expect(payload['comment'], startsWith('привет я'));
  });

  test(
    'каждая жалоба получает свой id (uuid генерируется на каждую)',
    () async {
      final r = repo();
      await r.reportQuestion(
        deckId: 'infosec',
        deckVersion: 1,
        questionId: 'a.q1',
        questionText: 'a',
        reason: ReportReason.typo,
      );
      await r.reportQuestion(
        deckId: 'infosec',
        deckVersion: 1,
        questionId: 'b.q1',
        questionText: 'b',
        reason: ReportReason.typo,
      );
      final rows = await db.select(db.outbox).get();
      final payloadIds = {
        for (final row in rows) (jsonDecode(row.payloadJson) as Map)['id'],
      };
      expect(payloadIds, hasLength(2));
    },
  );
}
