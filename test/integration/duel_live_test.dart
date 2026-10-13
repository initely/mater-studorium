// Интеграционный тест дуэли (T22) против ЖИВОГО локального Supabase:
// SupabaseDuelRepository и CreateDuelNotifier + миграция 0007_duels.sql.
// По умолчанию пропускается (тег live, нужны переменные окружения):
//
//   supabase start && supabase db reset
//   eval "$(supabase status -o env | sed 's/^/export /')"   # API_URL, ANON_KEY, SERVICE_ROLE_KEY
//   LIVE_SUPABASE_URL=$API_URL LIVE_SUPABASE_ANON_KEY=$ANON_KEY \
//   LIVE_SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY flutter test --tags live -j 1 test/integration/duel_live_test.dart
//
// Каждый тест создаёт своих анонимных пользователей и свою публичную колоду и
// удаляет их в конце (дуэли уходят каскадом). Просроченная дуэль вставляется
// через `docker exec <контейнер БД> psql` (LIVE_SUPABASE_DB_CONTAINER, по
// умолчанию supabase_db_mater_studorium): у service role на duels только
// SELECT и DELETE. Все live-тесты вместе запускать с `-j 1`.
@Tags(['live'])
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/supabase_sync_remote.dart';
import 'package:mater_studorium/core/sync/domain/duel_answer_outbox_handler.dart';
import 'package:mater_studorium/core/sync/domain/sync_service.dart';
import 'package:mater_studorium/core/sync/outbox_entry.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/duel/data/drift_duel_answer_queue.dart';
import 'package:mater_studorium/features/duel/data/duel_providers.dart';
import 'package:mater_studorium/features/duel/data/supabase_duel_repository.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_code.dart';
import 'package:mater_studorium/features/duel/domain/duel_result.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/create_duel_notifier.dart';
import 'package:mater_studorium/features/duel/presentation/duel_play_controller.dart';
import 'package:mater_studorium/features/questions/question_result.dart';
import 'package:mater_studorium/features/srs/domain/answer_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/db_fixtures.dart' show memoryDb;
import '../helpers/duel_fixtures.dart'
    show FakeDuelContentSource, contentOf, duelQuestionIds;
import '../helpers/fake_duel_repository.dart'
    show FakeDuelQuestionSource, snapshotOf;

String? _env(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : value;
}

void main() {
  // Два игрока в одном тесте: по базе в памяти на каждого.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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
  const questions = ['q.1', 'q.2', 'q.3', 'q.4', 'q.5'];

  void liveTest(String name, Future<void> Function() body) =>
      test(name, body, skip: skip);

  setUp(() async {
    if (skip != false) return;
    admin = SupabaseClient(url!, serviceKey!);
    deckId = 'duel${DateTime.now().microsecondsSinceEpoch}';
    await admin.from('decks').insert({
      'id': deckId,
      'title': 'Колода дуэли',
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

  Future<(SupabaseClient, String)> signIn() async {
    final client = SupabaseClient(url!, anonKey!);
    clients.add(client);
    final res = await client.auth.signInAnonymously();
    created.add(res.user!.id);
    return (client, res.user!.id);
  }

  var seq = 0;
  String duelUuid() => generateUuidV4(math.Random(++seq * 7919));

  Future<void> psql(String sql) async {
    final container =
        _env('LIVE_SUPABASE_DB_CONTAINER') ?? 'supabase_db_mater_studorium';
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
      sql,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
  }

  liveTest(
    'создание, вход по коду, имена только участникам (AC10.1, AC10.2)',
    () async {
      final (a, aId) = await signIn();
      final (b, _) = await signIn();
      final (c, _) = await signIn();
      final ra = SupabaseDuelRepository(a);
      final rb = SupabaseDuelRepository(b);
      final rc = SupabaseDuelRepository(c);

      await ra.setDisplayName('Алиса');
      await rb.setDisplayName('Боб');
      await rc.setDisplayName('Чужая');
      expect(await ra.displayName(), 'Алиса');

      final id = duelUuid();
      final duel = await ra.create(
        duelId: id,
        deckId: deckId,
        deckVersion: 2,
        questionIds: questions,
      );
      expect(duel.id, id);
      expect(duel.status, DuelStatus.open);
      expect(duel.isCreator, isTrue);
      expect(
        normalizeDuelCode(duel.code!),
        duel.code,
        reason: 'код допустимого вида',
      );
      expect(duel.questionIds, questions);
      expect(
        duel.expiresAt.difference(duel.createdAt),
        const Duration(hours: 72),
      );
      expect(duel.otherName, isNull);

      // Идемпотентность: повтор с тем же id — та же дуэль и тот же код.
      final again = await ra.create(
        duelId: id,
        deckId: deckId,
        deckVersion: 2,
        questionIds: questions,
      );
      expect(again.code, duel.code);

      // До входа: B дуэли не видит ни по id, ни прямым SELECT.
      expect(await rb.get(id), isNull);
      expect(await b.from('duels').select(), isEmpty);

      // Вход: регистр и пробелы не важны; B видит имя создателя, но не код.
      final joined = await rb.join(' ${duel.code!.toLowerCase()} ');
      expect(joined.id, id);
      expect(joined.status, DuelStatus.active);
      expect(joined.isCreator, isFalse);
      expect(joined.code, isNull);
      expect(joined.otherName, 'Алиса');
      // Повторный вход идемпотентен.
      expect((await rb.join(duel.code!)).id, id);

      // A видит имя соперника.
      final seenByA = (await ra.get(id))!;
      expect(seenByA.otherName, 'Боб');
      expect(seenByA.otherJoined, isTrue);
      expect(seenByA.code, duel.code);
      expect((await ra.mine()).map((d) => d.id), [id]);
      expect((await rb.mine()).map((d) => d.id), [id]);

      // Свой код создателя — не ошибка.
      expect((await ra.join(duel.code!)).isCreator, isTrue);

      // Третий: дуэль занята, ничего о ней не узнаёт.
      await expectLater(rc.join(duel.code!), throwsA(isA<DuelFullError>()));
      expect(await rc.get(id), isNull);
      expect(await rc.mine(), isEmpty);
      expect(await c.from('duels').select(), isEmpty);
      expect(await c.from('duel_answers').select(), isEmpty);
      // Профили чужих закрыты (display_name только через RPC).
      expect(
        await c.from('profiles').select().eq('id', aId),
        isEmpty,
        reason: 'чужой профиль через SELECT не читается',
      );
    },
  );

  liveTest('неверный и просроченный коды неотличимы; перебор ограничен (AC10.2, молодой аккаунт: 3 в час)', () async {
    final (a, aId) = await signIn();
    final (b, _) = await signIn();
    final rb = SupabaseDuelRepository(b);
    await psql(
      "insert into public.duels (id, code, deck_id, deck_version, question_ids, "
      "creator_id, status, created_at, expires_at) values ('${duelUuid()}', 'EXPRDK', "
      "'$deckId', 1, array['q.1','q.2','q.3','q.4','q.5'], '$aId', 'open', "
      "now() - interval '80 hours', now() - interval '8 hours')",
    );
    await expectLater(rb.join('EXPRDK'), throwsA(isA<DuelCodeNotFoundError>()));
    await expectLater(rb.join('ZZZZZZ'), throwsA(isA<DuelCodeNotFoundError>()));
    // Новый аккаунт «молодой»: 3 неудачи в час (старым 10); две уже были.
    await expectLater(rb.join('ZZZZZB'), throwsA(isA<DuelCodeNotFoundError>()));
    // Четвёртая: лимит, даже для верного по виду кода.
    await expectLater(
      rb.join('EXPRDK'),
      throwsA(
        isA<DuelLimitError>().having(
          (e) => e.kind,
          'kind',
          DuelLimitKind.joinAttempts,
        ),
      ),
    );
    // Создатель просроченной дуэли видит её как expired.
    final mine = await SupabaseDuelRepository(a).mine();
    expect(mine.single.status, DuelStatus.expired);
  });

  liveTest('лимит активных дуэлей и проверка колоды', () async {
    final (a, _) = await signIn();
    final ra = SupabaseDuelRepository(a);
    for (var i = 0; i < 5; i++) {
      await ra.create(
        duelId: duelUuid(),
        deckId: deckId,
        deckVersion: 2,
        questionIds: questions,
      );
    }
    await expectLater(
      ra.create(
        duelId: duelUuid(),
        deckId: deckId,
        deckVersion: 2,
        questionIds: questions,
      ),
      throwsA(
        isA<DuelLimitError>().having(
          (e) => e.kind,
          'kind',
          DuelLimitKind.activeDuels,
        ),
      ),
    );

    final (b, _) = await signIn();
    final rb = SupabaseDuelRepository(b);
    await expectLater(
      rb.create(
        duelId: duelUuid(),
        deckId: 'no-such-deck',
        deckVersion: 1,
        questionIds: questions,
      ),
      throwsA(isA<DeckNotFoundError>()),
    );
    await expectLater(
      rb.create(
        duelId: duelUuid(),
        deckId: deckId,
        deckVersion: 3,
        questionIds: questions,
      ),
      throwsA(isA<DeckNotFoundError>()),
      reason: 'версия выше серверной',
    );
    await expectLater(
      rb.create(
        duelId: duelUuid(),
        deckId: deckId,
        deckVersion: 2,
        questionIds: const ['q.1', 'q.1', 'q.3', 'q.4', 'q.5'],
      ),
      throwsA(isA<RequestRejectedError>()),
      reason: 'повтор вопроса',
    );
  });

  liveTest('имя: управляющие и bidi-символы сервер не принимает', () async {
    final (a, _) = await signIn();
    final ra = SupabaseDuelRepository(a);
    await expectLater(
      ra.setDisplayName('Са${String.fromCharCode(0x202E)}ша'),
      throwsA(isA<RequestRejectedError>()),
    );
    await expectLater(
      ra.setDisplayName(''),
      throwsA(isA<RequestRejectedError>()),
    );
    await expectLater(
      ra.setDisplayName(' Саша'),
      throwsA(isA<RequestRejectedError>()),
    );
    expect(await ra.displayName(), isNull);
    await ra.setDisplayName('Саша');
    await ra.setDisplayName(null);
    expect(await ra.displayName(), isNull);
  });

  liveTest(
    'CreateDuelNotifier на настоящем сервере: 5 вопросов колоды, код',
    () async {
      final (a, _) = await signIn();
      final container = ProviderContainer(
        overrides: [
          duelRepositoryProvider.overrideWithValue(SupabaseDuelRepository(a)),
          duelQuestionSourceProvider.overrideWithValue(
            FakeDuelQuestionSource(
              snapshots: {deckId: snapshotOf(9, version: 2)},
            ),
          ),
          randomProvider.overrideWithValue(math.Random(5)),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(createDuelProvider, (_, _) {});
      await container.read(createDuelProvider.notifier).create(deckId);
      final state = sub.read();
      expect(state.error, isNull);
      final duel = state.duel!;
      expect(duel.questionIds.toSet(), hasLength(5));
      expect(normalizeDuelCode(duel.code!), duel.code);
      expect(duel.deckVersion, 2);
    },
  );

  liveTest('без входа RPC дуэли недоступны (anon)', () async {
    final client = SupabaseClient(url!, anonKey!);
    clients.add(client);
    await expectLater(
      client.rpc<dynamic>('my_duels'),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      client.from('duels').select(),
      throwsA(isA<PostgrestException>()),
    );
  });

  DuelAnswerPayload answerOf(
    String duelId,
    int i, {
    required bool correct,
    required int ms,
    List<String> selected = const ['a'],
  }) => DuelAnswerPayload(
    duelId: duelId,
    questionId: questions[i],
    answer: {'selected': selected},
    isCorrect: correct,
    durationMs: ms,
  );

  liveTest(
    'T23: два игрока проходят дуэль через RPC; ответы скрыты до завершения '
    '(AC10.1); результат у обоих согласован',
    () async {
      final (a, aId) = await signIn();
      final (b, bId) = await signIn();
      final ra = SupabaseDuelRepository(a);
      final rb = SupabaseDuelRepository(b);
      final sa = SupabaseSyncRemote(a);
      final sb = SupabaseSyncRemote(b);
      final id = duelUuid();
      final duel = await ra.create(
        duelId: id,
        deckId: deckId,
        deckVersion: 2,
        questionIds: questions,
      );
      await rb.join(duel.code!);

      // A отвечает на 3 из 5: ответы B (когда он ответит) ему не видны.
      for (var i = 0; i < 3; i++) {
        expect(
          await sa.submitDuelAnswer(
            aId,
            answerOf(id, i, correct: i != 1, ms: 1000),
          ),
          isTrue,
        );
      }
      // Повтор того же вопроса с другим ответом: duplicate, первый остаётся.
      expect(
        await sa.submitDuelAnswer(
          aId,
          answerOf(id, 0, correct: false, ms: 9, selected: ['b']),
        ),
        isFalse,
      );
      final mineBefore = (await ra.answers(id)).mine;
      expect(mineBefore, hasLength(3));
      expect(
        mineBefore.firstWhere((r) => r.questionId == questions[0]).isCorrect,
        isTrue,
      );
      expect(
        mineBefore.firstWhere((r) => r.questionId == questions[0]).durationMs,
        1000,
      );

      // B отвечает на все пять: видит ответы A (их 3), а A про B ничего.
      for (var i = 0; i < 5; i++) {
        await sb.submitDuelAnswer(
          bId,
          answerOf(id, i, correct: i < 2, ms: 1500),
        );
      }
      final bSees = await rb.answers(id, withOther: true);
      expect(bSees.mine, hasLength(5));
      expect(bSees.other, hasLength(3), reason: 'B закончил: ответы A видны');
      final aSees = await ra.answers(id, withOther: true);
      expect(aSees.mine, hasLength(3));
      expect(aSees.other, isEmpty, reason: 'AC10.1: A не закончил, B скрыт');
      final midA = (await ra.get(id))!;
      expect(midA.status, DuelStatus.active);
      expect(midA.otherDoneAt, isNotNull);
      expect(midA.myDoneAt, isNull);

      // A заканчивает: дуэль finished, все ответы видны обоим.
      await sa.submitDuelAnswer(aId, answerOf(id, 3, correct: true, ms: 1000));
      await sa.submitDuelAnswer(aId, answerOf(id, 4, correct: true, ms: 1000));
      expect((await ra.get(id))!.status, DuelStatus.finished);
      expect((await rb.get(id))!.status, DuelStatus.finished);
      final aFinal = await ra.answers(id, withOther: true);
      final bFinal = await rb.answers(id, withOther: true);
      expect(aFinal.mine, hasLength(5));
      expect(aFinal.other, hasLength(5));
      DuelResult result(DuelAnswers x) => computeDuelResult(
        questionIds: questions,
        mine: x.mine,
        other: x.other,
      );
      final ar = result(aFinal);
      final br = result(bFinal);
      expect(
        (ar.mine.correct, ar.mine.totalMs),
        (br.other.correct, br.other.totalMs),
      );
      expect(
        (ar.other.correct, ar.other.totalMs),
        (br.mine.correct, br.mine.totalMs),
      );
      expect(ar.mine.correct, 4);
      expect(ar.other.correct, 2);
      expect(ar.outcome, DuelOutcome.won);
      expect(br.outcome, DuelOutcome.lost);

      // Повтор после завершения: duplicate, а не ошибка.
      expect(
        await sa.submitDuelAnswer(
          aId,
          answerOf(id, 0, correct: true, ms: 1000),
        ),
        isFalse,
      );
    },
  );

  liveTest('T23: чужой, просроченный и неверный ответ отклоняются', () async {
    final (a, aId) = await signIn();
    final (b, bId) = await signIn();
    final (c, cId) = await signIn();
    final ra = SupabaseDuelRepository(a);
    final id = duelUuid();
    final duel = await ra.create(
      duelId: id,
      deckId: deckId,
      deckVersion: 2,
      questionIds: questions,
    );
    await SupabaseDuelRepository(b).join(duel.code!);
    final sa = SupabaseSyncRemote(a);

    // Не участник: MS404 -> DuelClosedError, ничего не записано.
    await expectLater(
      SupabaseSyncRemote(c)
          .submitDuelAnswer(cId, answerOf(id, 0, correct: true, ms: 1)),
      throwsA(isA<DuelClosedError>()),
    );
    // p_user_id другого пользователя при своей сессии (в обход проверки клиента).
    await expectLater(
      a.rpc<dynamic>(
        'submit_duel_answer',
        params: {
          'p_user_id': bId,
          'p_duel_id': id,
          'p_question_id': questions[0],
          'p_answer': {
            'selected': ['a'],
          },
          'p_is_correct': true,
          'p_duration_ms': 1,
        },
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    // Несуществующая дуэль выглядит как чужая.
    await expectLater(
      sa.submitDuelAnswer(
        aId,
        DuelAnswerPayload(
          duelId: duelUuid(),
          questionId: questions[0],
          answer: const {},
          isCorrect: true,
          durationMs: 1,
        ),
      ),
      throwsA(isA<DuelClosedError>()),
    );
    // Вне набора и слишком большой ответ: отказ по значению.
    await expectLater(
      sa.submitDuelAnswer(
        aId,
        DuelAnswerPayload(
          duelId: id,
          questionId: 'q.9',
          answer: const {},
          isCorrect: true,
          durationMs: 1,
        ),
      ),
      throwsA(isA<SyncRejectedError>()),
    );
    await expectLater(
      sa.submitDuelAnswer(
        aId,
        DuelAnswerPayload(
          duelId: id,
          questionId: questions[0],
          answer: {'x': 'a' * 600},
          isCorrect: true,
          durationMs: 1,
        ),
      ),
      throwsA(isA<SyncRejectedError>()),
    );
    expect((await ra.answers(id)).mine, isEmpty);

    // Просроченная дуэль: MS410 -> DuelClosedError.
    final past = duelUuid();
    await psql(
      "insert into public.duels (id, code, deck_id, deck_version, question_ids, "
      "creator_id, opponent_id, status, created_at, expires_at, joined_at) values "
      "('$past', 'PASTBB', '$deckId', 1, array['q.1','q.2','q.3','q.4','q.5'], '$aId', "
      "'$bId', 'active', now() - interval '80 hours', now() - interval '8 hours', "
      "now() - interval '79 hours')",
    );
    await expectLater(
      sa.submitDuelAnswer(aId, answerOf(past, 0, correct: true, ms: 1)),
      throwsA(isA<DuelClosedError>()),
    );
    // Прямая вставка в таблицу клиенту закрыта.
    await expectLater(
      a.from('duel_answers').insert({
        'duel_id': id,
        'user_id': aId,
        'question_id': questions[0],
        'answer': <String, Object?>{},
        'is_correct': true,
        'duration_ms': 1,
      }),
      throwsA(isA<PostgrestException>()),
    );
  });

  liveTest(
    'T23: DuelPlayController + drift-очередь + SyncService на живом сервере: '
    'ответы доходят, FSRS пуст, соперник видит результат',
    () async {
      final (a, aId) = await signIn();
      final (b, bId) = await signIn();
      final qIds = duelQuestionIds();
      final id = duelUuid();
      final duel = await SupabaseDuelRepository(
        a,
      ).create(duelId: id, deckId: deckId, deckVersion: 2, questionIds: qIds);
      await SupabaseDuelRepository(b).join(duel.code!);

      /// Один игрок: контроллер на настоящем сервере, очередь в drift.
      Future<void> playAs(
        SupabaseClient client,
        String userId,
        List<bool> correct, {
        required DuelPlayPhase reopened,
      }) async {
        final db = memoryDb();
        final queue = DriftDuelAnswerQueue(
          db: db,
          userId: () => userId,
          clock: () => DateTime.now().toUtc(),
        );
        final container = ProviderContainer(
          overrides: [
            duelRepositoryProvider.overrideWithValue(
              SupabaseDuelRepository(client),
            ),
            duelAnswerQueueProvider.overrideWithValue(queue),
            duelContentSourceProvider.overrideWithValue(
              FakeDuelContentSource(content: contentOf()),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(duelPlayProvider(id), (_, _) {});
        final controller = container.read(duelPlayProvider(id).notifier);
        await controller.load();
        for (var i = 0; i < 5; i++) {
          expect(
            container.read(duelPlayProvider(id)).phase,
            DuelPlayPhase.playing,
          );
          await controller.onAnswered(
            QuestionResult(
              outcome: correct[i]
                  ? AnswerOutcome.autoCorrect
                  : AnswerOutcome.autoIncorrect,
              answer: {
                'selected': [correct[i] ? 'a' : 'b'],
              },
            ),
          );
          controller.next();
        }
        expect(container.read(duelPlayProvider(id)).phase, DuelPlayPhase.done);

        // ADR-16: в drift только outbox.
        expect(await db.select(db.outbox).get(), hasLength(5));
        expect(await db.select(db.reviewLogs).get(), isEmpty);
        expect(await db.select(db.userItemStates).get(), isEmpty);

        final remote = SupabaseSyncRemote(client);
        final service = SyncService(
          remote: remote,
          store: db.syncDao,
          currentUserId: () => userId,
          clock: () => DateTime.now().toUtc(),
          outboxHandlers: {
            OutboxKind.duelAnswer: duelAnswerOutboxHandler(remote),
          },
        );
        final report = await service.sync();
        expect(report.outboxSent, 5, reason: '$report');
        expect(await db.select(db.outbox).get(), isEmpty);

        // Повторное открытие игры: всё уже отвечено, новых вопросов нет.
        container.invalidate(duelPlayProvider(id));
        container.listen(duelPlayProvider(id), (_, _) {});
        await container.read(duelPlayProvider(id).notifier).load();
        // У активной дуэли играть больше нечего (done), у завершённой она
        // закрыта (closed).
        expect(container.read(duelPlayProvider(id)).phase, reopened);
      }

      await playAs(a, aId, [
        true,
        true,
        true,
        false,
        false,
      ], reopened: DuelPlayPhase.done);
      final mid = await SupabaseDuelRepository(a).answers(id, withOther: true);
      expect(mid.mine, hasLength(5));
      expect(mid.other, isEmpty);
      await playAs(b, bId, [
        true,
        false,
        false,
        false,
        false,
      ], reopened: DuelPlayPhase.closed);

      final ra = SupabaseDuelRepository(a);
      final rb = SupabaseDuelRepository(b);
      expect((await ra.get(id))!.status, DuelStatus.finished);
      final aSide = await ra.answers(id, withOther: true);
      final bSide = await rb.answers(id, withOther: true);
      final ar = computeDuelResult(
        questionIds: qIds,
        mine: aSide.mine,
        other: aSide.other,
      );
      final br = computeDuelResult(
        questionIds: qIds,
        mine: bSide.mine,
        other: bSide.other,
      );
      expect((ar.mine.correct, ar.other.correct), (3, 1));
      expect((br.mine.correct, br.other.correct), (1, 3));
      expect((ar.outcome, br.outcome), (DuelOutcome.won, DuelOutcome.lost));
      expect(
        aSide.mine.map((r) => r.selectedOptionIds.first).toList()..sort(),
        ['a', 'a', 'a', 'b', 'b'],
      );
      expect(aSide.mine.every((r) => r.durationMs >= 0), isTrue);
    },
  );
}
