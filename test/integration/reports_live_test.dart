// Интеграционный тест жалоб (T20) против ЖИВОГО локального Supabase: drift в
// памяти + SupabaseSyncRemote + миграция 0005_reports.sql.
// По умолчанию пропускается (тег live, нужны переменные окружения):
//
//   supabase start && supabase db reset
//   eval "$(supabase status -o env | sed 's/^/export /')"   # API_URL, ANON_KEY, SERVICE_ROLE_KEY
//   LIVE_SUPABASE_URL=$API_URL LIVE_SUPABASE_ANON_KEY=$ANON_KEY \
//   LIVE_SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY flutter test --tags live -j 1 test/integration/reports_live_test.dart
//
// Каждый тест создаёт своих анонимных пользователей и свою колоду и удаляет их
// в конце (жалобы уходят каскадом). Ключ service role берётся только из
// окружения: проверка строк на сервере, inbox и уборка. Возраст аккаунтов
// (голос в скрытии считается, если аккаунту ≥ 24 ч, ADR-33 п. 4) ставится
// через `docker exec <контейнер БД> psql` (LIVE_SUPABASE_DB_CONTAINER, по
// умолчанию supabase_db_mater_studorium): через HTTP `auth.users.created_at`
// не изменить. Все live-тесты вместе
// запускать с `-j 1`: публичная колода этого теста видна каталогу, и
// параллельный catalog_live_test пытался бы её скачать.
@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/supabase_sync_remote.dart';
import 'package:mater_studorium/core/sync/domain/report_outbox_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_report.dart';
import 'package:mater_studorium/core/sync/domain/sync_service.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:mater_studorium/features/reports/data/drift_reports_repository.dart';
import 'package:mater_studorium/features/reports/domain/report.dart';
import 'package:mater_studorium/features/reports/domain/report_reason.dart';
import 'package:mater_studorium/features/session/domain/grade_source.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/db_fixtures.dart' show memoryDb;
import '../helpers/session_db_fixtures.dart' show repositoryFor;
import '../helpers/sync_fixtures.dart';

String? _env(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : value;
}

void main() {
  final url = _env('LIVE_SUPABASE_URL');
  final anonKey = _env('LIVE_SUPABASE_ANON_KEY');
  final serviceKey = _env('LIVE_SUPABASE_SERVICE_KEY');
  final skip = url == null || anonKey == null || serviceKey == null
      ? 'нужны LIVE_SUPABASE_URL, LIVE_SUPABASE_ANON_KEY, LIVE_SUPABASE_SERVICE_KEY '
            'и запущенный локальный Supabase'
      : false;

  late SupabaseClient admin;
  late String deckId;
  final created = <String>[];
  final clients = <SupabaseClient>[];
  var ids = 0;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  void liveTest(String name, Future<void> Function() body) =>
      test(name, body, skip: skip);

  setUp(() async {
    if (skip != false) return;
    admin = SupabaseClient(url!, serviceKey!);
    deckId = 'rep${DateTime.now().microsecondsSinceEpoch}';
    await admin.from('decks').insert({
      'id': deckId,
      'title': 'Колода жалоб',
      'topic': 'live',
      'lang': 'ru',
      'version': 2,
      'visibility': 'public',
      'storage_path': '$deckId/v2.json',
      'item_count': 1,
    });
  });

  tearDown(() async {
    if (skip != false) return;
    for (final id in created) {
      await admin.auth.admin.deleteUser(id);
    }
    created.clear();
    for (final c in clients) {
      await c.dispose();
    }
    clients.clear();
    await admin.from('decks').delete().eq('id', deckId);
    await admin.dispose();
  });

  /// Новый анонимный пользователь, как в приложении.
  Future<(SupabaseClient, String)> signIn() async {
    final client = SupabaseClient(url!, anonKey!);
    clients.add(client);
    final res = await client.auth.signInAnonymously();
    final id = res.user!.id;
    created.add(id);
    return (client, id);
  }

  /// Устройство пользователя: своя БД, репозиторий жалоб и SyncService
  /// поверх настоящего Supabase.
  ({AppDatabase db, DriftReportsRepository reports, SyncService sync})
  deviceFor(SupabaseClient client) {
    final db = memoryDb();
    final remote = SupabaseSyncRemote(client);
    return (
      db: db,
      reports: DriftReportsRepository(
        db: db,
        userId: () => client.auth.currentUser!.id,
        clock: () => DateTime.utc(2026, 10, 12, 12),
        newId: () => _uuid(++ids),
      ),
      sync: SyncService(
        remote: remote,
        store: db.syncDao,
        currentUserId: () => client.auth.currentUser?.id,
        clock: () => DateTime.utc(2026, 10, 12, 12),
        outboxHandlers: {OutboxKind.report: reportOutboxHandler(remote)},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> serverReports(String question) => admin
      .from('reports')
      .select()
      .eq('question_id', question)
      .order('created_at');

  Future<void> report(
    DriftReportsRepository repo,
    String question, {
    ReportReason reason = ReportReason.wrongAnswer,
    String? comment,
  }) => repo.reportQuestion(
    deckId: deckId,
    deckVersion: 2,
    questionId: question,
    questionText: 'Текст $question',
    reason: reason,
    comment: comment,
  );

  /// Делает аккаунты «взрослыми» (30 суток): их жалобы голосуют.
  Future<void> ageUsers(List<String> ids) async {
    final container =
        _env('LIVE_SUPABASE_DB_CONTAINER') ?? 'supabase_db_mater_studorium';
    final list = ids.map((i) => "'$i'").join(',');
    final r = await Process.run('docker', [
      'exec',
      '-i',
      container,
      'psql',
      '-U',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-qtAX',
      '-c',
      "update auth.users set created_at = now() - interval '30 days' "
          'where id in ($list)',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
  }

  /// Пользователь отвечал на вопрос: лог уходит на сервер (условие голоса).
  Future<void> answered(
    ({AppDatabase db, DriftReportsRepository reports, SyncService sync}) d,
    String userId,
    String question,
  ) async {
    final at = DateTime.utc(2026, 10, 12, 11);
    await repositoryFor(d.db, user: userId).recordReview(
      log: syncLog(
        '$question.item',
        at,
      ).copyWith(deckId: deckId, questionId: question),
      state: syncState('$question.item', at).copyWith(deckId: deckId),
    );
    expect((await d.sync.sync()).outcome, SyncOutcome.success);
  }

  liveTest('AC11.1/AC11.2: две жалобы разных пользователей на вопрос — на '
      'сервере, в inbox, и вопрос скрыт у обоих после синка; молодые аккаунты '
      'не голосуют', () async {
    final (a, aId) = await signIn();
    final (b, bId) = await signIn();
    final da = deviceFor(a);
    final db = deviceFor(b);
    await ageUsers([aId, bId]);
    await answered(da, aId, 'live.q1');
    await answered(db, bId, 'live.q1');

    await report(da.reports, 'live.q1', comment: 'ответ в разборе неверен');
    // До синка скрыт только у автора жалобы.
    expect(await da.db.decksDao.hiddenQuestionIds(), {'live.q1'});
    expect(await db.db.decksDao.hiddenQuestionIds(), isEmpty);

    final first = await da.sync.sync();
    expect(first.outcome, SyncOutcome.success, reason: '$first');
    expect(first.outboxSent, 1);
    expect(await da.db.select(da.db.outbox).get(), isEmpty);
    // Одна жалоба вопрос серверно не скрывает.
    expect(first.hiddenQuestions, 0);
    expect((await serverReports('live.q1')), hasLength(1));

    // Повтор прогона и повтор RPC того же отчёта: дубликатов нет.
    await da.sync.sync();
    expect((await serverReports('live.q1')), hasLength(1));

    await report(db.reports, 'live.q1', reason: ReportReason.typo);
    final second = await db.sync.sync();
    expect(second.outcome, SyncOutcome.success, reason: '$second');
    expect(second.hiddenQuestions, 1);
    expect(await db.db.decksDao.hiddenQuestionIds(), {'live.q1'});

    // Второй пользователь пожаловался: после следующего синка вопрос
    // скрыт и у первого (серверное скрытие, а не только локальное).
    final third = await da.sync.sync();
    expect(third.hiddenQuestions, 1);
    final rows = await da.db.select(da.db.hiddenQuestions).get();
    expect(rows.map((r) => (r.questionId, r.source)), [('live.q1', 'local')]);

    // Третий пользователь, который не жаловался, тоже получает скрытие.
    final (c, _) = await signIn();
    final dc = deviceFor(c);
    final fromC = await dc.sync.sync();
    expect(fromC.hiddenQuestions, 1);
    final cRows = await dc.db.select(dc.db.hiddenQuestions).get();
    expect(cRows.map((r) => (r.questionId, r.source)), [('live.q1', 'server')]);

    // Молодые аккаунты (нет суток) с ответом на вопрос не голосуют: две
    // жалобы с пачки свежих анонимов вопрос не скрывают (S1).
    final (y1, y1Id) = await signIn();
    final (y2, y2Id) = await signIn();
    final dy1 = deviceFor(y1);
    final dy2 = deviceFor(y2);
    await answered(dy1, y1Id, 'young.q1');
    await answered(dy2, y2Id, 'young.q1');
    await report(dy1.reports, 'young.q1');
    await report(dy2.reports, 'young.q1');
    await dy1.sync.sync();
    await dy2.sync.sync();
    expect(await serverReports('young.q1'), hasLength(2));
    expect((await dc.sync.sync()).hiddenQuestions, 1, reason: 'только live.q1');
    expect(await dc.db.decksDao.hiddenQuestionIds(), {'live.q1'});

    // Куратор в Dashboard: reports_inbox.
    final inbox = await admin
        .from('reports_inbox')
        .select()
        .eq('question_id', 'live.q1')
        .single();
    expect(inbox['deck_id'], deckId);
    expect(inbox['question_text'], 'Текст live.q1');
    expect(inbox['reporters'], 2);
    expect(inbox['flagged'], isTrue);
    expect(inbox['wrong_answer'], 1);
    expect(inbox['typo'], 1);

    // Подтверждение куратора скрывает вопрос само по себе, даже с молодых
    // аккаунтов.
    await admin
        .from('reports')
        .update({'status': 'accepted'})
        .eq('question_id', 'young.q1');
    expect((await dc.sync.sync()).hiddenQuestions, 2);
    await admin
        .from('reports')
        .update({'status': 'rejected'})
        .eq('question_id', 'young.q1');

    // Решение куратора: отклонил одну — вопрос возвращается, после синка
    // серверное скрытие у третьего пропадает.
    await admin
        .from('reports')
        .update({'status': 'rejected'})
        .eq('question_id', 'live.q1')
        .eq('reason', 'typo');
    final back = await dc.sync.sync();
    expect(back.hiddenQuestions, 0);
    expect(await dc.db.decksDao.hiddenQuestionIds(), isEmpty);
  });

  liveTest('RLS: пользователь видит только свои жалобы, не пишет напрямую, '
      'reports_inbox ему недоступен', () async {
    final (a, aId) = await signIn();
    final (b, _) = await signIn();
    final da = deviceFor(a);
    await report(da.reports, 'rls.q1');
    await da.sync.sync();
    final db = deviceFor(b);
    await report(db.reports, 'rls.q2');
    await db.sync.sync();

    final aRows = await a.from('reports').select();
    expect(aRows.map((r) => r['question_id']), ['rls.q1']);
    expect(aRows.single['user_id'], aId);

    // Прямые INSERT/UPDATE/DELETE запрещены (нет привилегий).
    for (final action in <Future<Object?> Function()>[
      () => a.from('reports').insert({
        'id': _uuid(900),
        'user_id': aId,
        'deck_id': deckId,
        'deck_version': 2,
        'question_id': 'rls.direct',
        'reason': 'typo',
      }),
      () => a.from('reports').update({'status': 'rejected'}).eq('user_id', aId),
      () => a.from('reports').delete().eq('user_id', aId),
      () => a.from('reports_inbox').select(),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
    }
    expect(await serverReports('rls.direct'), isEmpty);

    // Без входа (anon): ни RPC, ни таблицы.
    final anon = SupabaseClient(url!, anonKey!);
    clients.add(anon);
    for (final action in <Future<Object?> Function()>[
      () => anon.rpc<dynamic>('hidden_questions'),
      () => anon.rpc<dynamic>(
        'submit_report',
        params: {'p_user_id': aId, 'p_report': <String, Object>{}},
      ),
      () => anon.from('reports').select(),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
    }

    // Чужой p_user_id: отказ и ничего не записано.
    final remoteA = SupabaseSyncRemote(a);
    await expectLater(
      remoteA.submitReport(
        '00000000-0000-4000-8000-000000000001',
        Report.question(
          id: _uuid(901),
          deckId: deckId,
          deckVersion: 2,
          questionId: 'rls.alien',
          reason: ReportReason.typo,
        ),
      ),
      throwsA(isA<AuthError>()),
    );
    // Прямой вызов RPC с чужим p_user_id мимо клиентской защиты.
    await expectLater(
      a.rpc<dynamic>(
        'submit_report',
        params: {
          'p_user_id': '00000000-0000-4000-8000-000000000001',
          'p_report': {'id': _uuid(902), 'deck_id': deckId},
        },
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    expect(await serverReports('rls.alien'), isEmpty);
  });

  liveTest(
    '«не согласен»: ответ, вердикт и оценка на сервере; лимит 30 в сутки '
    'и ошибки типизированы',
    () async {
      final (a, aId) = await signIn();
      final da = deviceFor(a);
      final remote = SupabaseSyncRemote(a);

      final log = syncLog('live.item', DateTime.utc(2026, 10, 12, 11)).copyWith(
        deckId: deckId,
        questionId: 'live.item.q1',
        gradeSource: GradeSource.override,
        answerText: 'мой ответ',
      );
      await repositoryFor(da.db, user: aId).recordReview(
        log: log,
        state: syncState(
          'live.item',
          DateTime.utc(2026, 10, 12, 11),
        ).copyWith(deckId: deckId),
        report: Report.disagreement(
          id: _uuid(++ids),
          deckId: deckId,
          deckVersion: 2,
          questionId: 'live.item.q1',
          answerText: 'мой ответ',
          verdict: GradeVerdict.partial,
          userRating: Rating.good,
          llmScore: 0.55,
          comment: 'ИИ придирается',
          questionText: 'Объясните XSS',
        ),
      );
      final r = await da.sync.sync();
      expect(r.outcome, SyncOutcome.success, reason: '$r');
      expect((r.logsPushed, r.outboxSent), (1, 1));
      final row = (await serverReports('live.item.q1')).single;
      expect(row['reason'], 'grading_disagree');
      expect(row['answer_text'], 'мой ответ');
      expect(row['llm_verdict'], 'partial');
      expect(row['llm_score'], closeTo(0.55, 1e-6));
      expect(row['user_rating'], 3);
      expect(row['comment'], 'ИИ придирается');
      expect(row['status'], 'new');
      // Оспоренный вопрос в списке скрытых не оказывается.
      expect(await remote.pullHiddenQuestions(aId), isEmpty);

      // Лимит: ещё 29 до 30, 31-я — QuotaExceededError (не сеть и не отказ).
      for (var i = 0; i < 29; i++) {
        final ok = await remote.submitReport(
          aId,
          Report.question(
            id: _uuid(1000 + i),
            deckId: deckId,
            deckVersion: 2,
            questionId: 'lim.q$i',
            reason: ReportReason.typo,
          ),
        );
        expect(ok, isTrue);
      }
      Report over(int n) => Report.question(
        id: _uuid(n),
        deckId: deckId,
        deckVersion: 2,
        questionId: 'lim.over$n',
        reason: ReportReason.typo,
      );
      await expectLater(
        remote.submitReport(aId, over(2000)),
        throwsA(isA<QuotaExceededError>()),
      );
      // Повтор уже принятой жалобы при исчерпанном лимите: false, не ошибка.
      expect(
        await remote.submitReport(
          aId,
          Report.question(
            id: _uuid(1000),
            deckId: deckId,
            deckVersion: 2,
            questionId: 'lim.q0',
            reason: ReportReason.typo,
          ),
        ),
        isFalse,
      );
      expect(await serverReports('lim.over2000'), isEmpty);

      // Жалоба с исчерпанным лимитом в очереди: ждёт, синк идёт дальше.
      await report(da.reports, 'lim.queued');
      final waiting = await da.sync.sync();
      expect(waiting.outcome, SyncOutcome.success, reason: '$waiting');
      expect(await da.db.select(da.db.outbox).get(), hasLength(1));
      expect((await da.db.select(da.db.outbox).getSingle()).attempts, 0);
    },
  );

  liveTest('«ядовитые» жалобы: неизвестная колода и «грязный» текст', () async {
    final (a, aId) = await signIn();
    final da = deviceFor(a);

    // Грязный текст очищается на клиенте и принимается сервером.
    await report(
      da.reports,
      'dirty.q1',
      comment: 'при\u0000ве\u0001т \ud800 мир',
    );
    // Колода, которой нет на сервере: сервер отвергает (23503) на каждой
    // попытке; после трёх запись отбрасывается, остальные не страдают.
    await da.reports.reportQuestion(
      deckId: 'no-such-deck',
      deckVersion: 1,
      questionId: 'ghost.q1',
      questionText: 'призрак',
      reason: ReportReason.other,
    );
    await report(da.reports, 'fine.q1');

    for (var run = 0; run < 3; run++) {
      final r = await da.sync.sync();
      expect(r.outcome, SyncOutcome.success, reason: '$r');
    }
    expect(await da.db.select(da.db.outbox).get(), isEmpty);
    expect(await serverReports('ghost.q1'), isEmpty);
    expect(await serverReports('fine.q1'), hasLength(1));
    final dirty = (await serverReports('dirty.q1')).single;
    expect(dirty['comment'], 'привет � мир');
    expect(dirty['user_id'], aId);
  });
}

String _uuid(int n) =>
    'cccccccc-0000-4000-8000-${n.toString().padLeft(12, '0')}';
