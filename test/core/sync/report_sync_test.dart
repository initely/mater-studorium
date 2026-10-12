// Жалобы через outbox и SyncService (T20, AC11.1, ТЗ §7.3, ADR-33): drift в
// памяти, сервер в памяти (FakeSyncServer с семантикой 0005_reports.sql).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/sync/domain/report_outbox_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_report.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/reports/data/drift_reports_repository.dart';
import 'package:mater_studorium/features/reports/domain/report.dart';
import 'package:mater_studorium/features/reports/domain/report_outbox.dart';
import 'package:mater_studorium/features/reports/domain/report_reason.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';

import '../../helpers/fake_sync_server.dart';
import '../../helpers/session_db_fixtures.dart' show repositoryFor;
import '../../helpers/sync_fixtures.dart';

void main() {
  late FakeSyncServer server;
  late Device d;
  var ids = 0;

  setUp(() {
    ids = 0;
    server = FakeSyncServer(now: () => s0, sessionUserId: userA);
    d = Device(
      server,
      outboxHandlers: {OutboxKind.report: reportOutboxHandler(server)},
    );
  });

  DriftReportsRepository repo({void Function()? onQueued}) =>
      DriftReportsRepository(
        db: d.db,
        userId: () => userA,
        clock: () => s0,
        newId: () =>
            'aaaaaaaa-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}',
        onQueued: onQueued,
      );

  Future<void> report(
    String question, {
    ReportReason reason = ReportReason.typo,
    String? comment,
    DriftReportsRepository? r,
  }) => (r ?? repo()).reportQuestion(
    deckId: 'infosec',
    deckVersion: 1,
    questionId: question,
    questionText: 'Текст $question',
    reason: reason,
    comment: comment,
  );

  Future<List<OutboxRow>> outbox() => d.db.select(d.db.outbox).get();

  group('AC11.1: жалоба уходит офлайн-первой', () {
    test('нет сети: жалоба лежит в очереди и скрыта локально; сеть '
        'появилась — на сервере, очередь пуста', () async {
      server.offline = true;
      await report('xss.q1', comment: 'ответ неверен');

      // Локально сразу: скрыто и стоит в очереди под пользователем.
      expect(await d.db.decksDao.hiddenQuestionIds(), {'xss.q1'});
      final queued = await outbox();
      expect(queued.single.kind, OutboxKind.report);
      expect(queued.single.userId, userA);
      expect(
        Report.fromJson(jsonDecode(queued.single.payloadJson)).comment,
        'ответ неверен',
      );

      final offline = await d.service.sync();
      expect(offline.outcome, SyncOutcome.offline);
      expect(await outbox(), hasLength(1), reason: 'не потеряна');
      expect(server.reports, isEmpty);

      server.offline = false;
      final ok = await d.service.sync();
      expect(ok.outcome, SyncOutcome.success, reason: '$ok');
      expect(ok.outboxSent, 1);
      expect(await outbox(), isEmpty);
      final sent = server.reports.values.single;
      expect(sent.userId, userA);
      expect(sent.report.questionId, 'xss.q1');
      expect(sent.report.reason, ReportReason.typo);
      expect(sent.report.questionText, 'Текст xss.q1');
    });

    test('ответ сервера потерян: повтор идемпотентен, на сервере одна '
        'жалоба', () async {
      await report('xss.q1');
      // Логов и состояний нет: первый вызов прогона — submitReport.
      server.failAfter.add(1);
      final lost = await d.service.sync();
      expect(lost.outcome, SyncOutcome.offline);
      expect(server.reports, hasLength(1), reason: 'сервер записал');
      expect(await outbox(), hasLength(1), reason: 'клиент не знает');

      final again = await d.service.sync();
      expect(again.outcome, SyncOutcome.success, reason: '$again');
      expect(server.reports, hasLength(1), reason: 'повтор не создал вторую');
      expect(await outbox(), isEmpty);
    });

    test('«не согласен» вместе с ответом: один пакет и в очереди, и на '
        'сервере', () async {
      final log = syncLog(
        'i1',
        s0,
      ).copyWith(gradeSource: GradeSource.override, answerText: 'мой ответ');
      final disagreement = Report.disagreement(
        id: 'aaaaaaaa-0000-4000-8000-0000000000d1',
        deckId: 'infosec',
        deckVersion: 1,
        questionId: 'i1.q1',
        answerText: 'мой ответ',
        verdict: GradeVerdict.incorrect,
        userRating: Rating.good,
        llmScore: 0.2,
      );
      await repositoryFor(d.db, user: userA).recordReview(
        log: log,
        state: syncState('i1', s0),
        report: disagreement,
      );
      expect(await outbox(), hasLength(1));

      final r = await d.service.sync();
      expect(r.outcome, SyncOutcome.success, reason: '$r');
      expect((r.logsPushed, r.outboxSent), (1, 1));
      final sent = server.reports.values.single.report;
      expect(sent.reason, ReportReason.gradingDisagree);
      expect(sent.disagreement!.userRating, Rating.good);
      expect(sent.disagreement!.llmScore, 0.2);
    });
  });

  group('«ядовитые» записи не блокируют синк (урок T17)', () {
    test('жалоба, которую сервер отвергает, отбрасывается после трёх '
        'попыток; остальные и pull доходят', () async {
      server.hidden.add('xss.q9');
      server.rejectReport = (r) => r.questionId == 'bad.q1';
      await report('bad.q1');
      await report('good.q1');

      final first = await d.service.sync();
      expect(first.outcome, SyncOutcome.success, reason: '$first');
      expect(first.outboxSent, 1);
      expect(server.reports.values.map((e) => e.report.questionId), [
        'good.q1',
      ]);
      expect((await outbox()).single.attempts, 1);
      expect(first.hiddenQuestions, 1, reason: 'pull выполнен после отказа');

      await d.service.sync();
      expect((await outbox()).single.attempts, 2);
      final third = await d.service.sync();
      expect(await outbox(), isEmpty, reason: 'отброшена на третьей попытке');
      expect(third.outcome, SyncOutcome.success);
      expect(server.reports, hasLength(1));
    });

    test('запись, которая не разбирается или не пройдёт серверные '
        'ограничения, отбрасывается без обращения к серверу', () async {
      final now = s0;
      Future<void> raw(String payload) => d.db.reviewDao.enqueueOutbox(
        userA,
        OutboxEntry(
          kind: OutboxKind.report,
          payloadJson: payload,
          createdAt: now,
        ),
      );
      await raw('{не json');
      await raw('[1, 2]');
      await raw(jsonEncode({'id': 'x', 'reason': 'spam'}));
      // Разобралась, но id не uuid: сервер отверг бы навсегда.
      await raw(
        jsonEncode(
          Report.question(
            id: 'не-uuid',
            deckId: 'infosec',
            deckVersion: 1,
            questionId: 'xss.q1',
            reason: ReportReason.typo,
          ).toJson(),
        ),
      );
      await report('good.q1');

      final r = await d.service.sync();
      expect(r.outcome, SyncOutcome.success, reason: '$r');
      expect(await outbox(), isEmpty);
      expect(server.callLog.where((c) => c == 'submitReport'), hasLength(1));
      expect(server.reports.values.single.report.questionId, 'good.q1');
    });

    test('дневной лимит: остаток ждёт, pull и логи не страдают; после '
        'сброса лимита уходит', () async {
      server.reportLimit = 1;
      server.hidden.add('xss.q9');
      await report('a.q1');
      await report('b.q1');
      await answer(d.db, userA, 'i1', s0);

      final first = await d.service.sync();
      expect(first.outcome, SyncOutcome.success, reason: '$first');
      expect(first.outboxSent, 1);
      expect(first.logsPushed, 1);
      expect(first.hiddenQuestions, 1);
      final waiting = (await outbox()).single;
      expect(waiting.attempts, 0, reason: 'ожидание лимита не попытка');

      // Сутки сменились (лимит снова есть).
      server.reportLimit = 30;
      final next = await d.service.sync();
      expect(next.outboxSent, 1);
      expect(await outbox(), isEmpty);
      expect(server.reports, hasLength(2));
    });

    test('лимит не «ядовитит» жалобу: ожидание сколь угодно долго не '
        'расходует попытки, остальные не бьются в лимит, после сброса '
        'уходят', () async {
      server.reportLimit = 0;
      await report('a.q1');
      await report('b.q1');
      await report('c.q1');
      for (var run = 0; run < 5; run++) {
        server.callLog.clear();
        final r = await d.service.sync();
        expect(r.outcome, SyncOutcome.success, reason: '$r');
        expect(r.outboxSent, 0);
        expect(
          server.callLog.where((c) => c == 'submitReport'),
          hasLength(1),
          reason: 'после первого отказа по лимиту остальные не отправляются',
        );
      }
      expect((await outbox()).map((e) => e.attempts), [0, 0, 0]);

      // Первый же отказ сервера после долгого ожидания лимита не отбрасывает
      // жалобу (раньше ожидание лимита засчитывалось как неудачные попытки).
      server
        ..reportLimit = 30
        ..rejectReport = (r) => r.questionId == 'a.q1';
      await d.service.sync();
      expect((await outbox()).map((e) => e.attempts), [
        1,
      ], reason: 'a.q1 отвергнута один раз и осталась, остальные ушли');
      expect(server.reports, hasLength(2));

      server.rejectReport = null;
      await d.service.sync();
      expect(await outbox(), isEmpty);
      expect(server.reports, hasLength(3));
    });

    test('жалобы другого пользователя не уходят под чужой сессией', () async {
      await repo().reportQuestion(
        deckId: 'infosec',
        deckVersion: 1,
        questionId: 'xss.q1',
        questionText: 'q',
        reason: ReportReason.other,
      );
      server.sessionUserId = userB;
      d.user = userB;
      final r = await d.service.sync();
      expect(r.outcome, SyncOutcome.success);
      expect(server.reports, isEmpty);
      expect(await outbox(), hasLength(1));
    });
  });

  group('шаг 6: hidden_questions', () {
    test(
      'серверный список заменяет прежний, локально скрытое остаётся',
      () async {
        await d.db.decksDao.hideQuestion('mine.q1');
        server.hidden.addAll({'srv.q1', 'srv.q2'});
        final first = await d.service.sync();
        expect(first.hiddenQuestions, 2);
        expect(await d.db.decksDao.hiddenQuestionIds(), {
          'mine.q1',
          'srv.q1',
          'srv.q2',
        });

        // Куратор вернул srv.q2.
        server.hidden.remove('srv.q2');
        await d.service.sync();
        expect(await d.db.decksDao.hiddenQuestionIds(), {'mine.q1', 'srv.q1'});

        server.hidden.clear();
        await d.service.sync();
        expect(await d.db.decksDao.hiddenQuestionIds(), {'mine.q1'});
      },
    );

    test(
      'пользователь сменился во время pull: список не записывается',
      () async {
        await d.db.decksDao.replaceServerHiddenQuestions({'old.q1'});
        server.hidden.add('srv.q1');
        var current = userA;
        final service = d.serviceWithUser(() => current);
        final held = server.hold('pullHiddenQuestions');
        final run = service.sync();
        await held.reached.future;
        current = userB;
        held.release.complete();

        final report = await run;
        expect(report.outcome, SyncOutcome.authFailed);
        expect(await d.db.decksDao.hiddenQuestionIds(), {'old.q1'});
      },
    );

    test('сбой pull не ломает остальные шаги и не стирает список', () async {
      server.hidden.add('srv.q1');
      await d.service.sync();
      server.failUnexpected.add('pullHiddenQuestions');
      await answer(d.db, userA, 'i1', s0);
      final r = await d.service.sync();
      expect(r.outcome, SyncOutcome.failed);
      expect(r.logsPushed, 1);
      expect(await d.db.decksDao.hiddenQuestionIds(), {'srv.q1'});
    });
  });

  test('репозиторий просит синхронизацию после записи в очередь', () async {
    var asked = 0;
    await report('xss.q1', r: repo(onQueued: () => asked++));
    expect(asked, 1);
  });

  test('payload очереди — тело RPC submit_report', () async {
    await report('xss.q1', reason: ReportReason.badSource, comment: 'ссылка');
    final entry = (await outbox()).single;
    expect(jsonDecode(entry.payloadJson), {
      'id': 'aaaaaaaa-0000-4000-8000-000000000001',
      'deck_id': 'infosec',
      'deck_version': 1,
      'question_id': 'xss.q1',
      'reason': 'bad_source',
      'comment': 'ссылка',
      'question_text': 'Текст xss.q1',
    });
    expect(
      entry.payloadJson,
      jsonEncode(Report.fromJson(jsonDecode(entry.payloadJson)).toJson()),
    );
    expect(
      reportOutboxEntry(
        Report.fromJson(jsonDecode(entry.payloadJson)),
        s0,
      ).payloadJson,
      entry.payloadJson,
    );
  });
}
