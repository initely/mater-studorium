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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/utils/uuid.dart';
import 'package:mater_studorium/features/duel/data/duel_providers.dart';
import 'package:mater_studorium/features/duel/data/supabase_duel_repository.dart';
import 'package:mater_studorium/features/duel/domain/duel_code.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/create_duel_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_duel_repository.dart'
    show FakeDuelQuestionSource, snapshotOf;

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

  liveTest('неверный и просроченный коды неотличимы; перебор ограничен (AC10.2)', () async {
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
    // Остальные неудачи до лимита (две уже были: 10 в час).
    for (var i = 0; i < 8; i++) {
      await expectLater(
        rb.join('ZZZZZ${'BCDEFGHJ'[i]}'),
        throwsA(isA<DuelCodeNotFoundError>()),
      );
    }
    // Одиннадцатая: лимит, даже для верного по виду кода.
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
}
