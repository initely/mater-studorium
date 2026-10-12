// Интеграционный тест синхронизации (T17) против ЖИВОГО локального Supabase:
// drift в памяти + SupabaseSyncRemote + миграция 0003_sync.sql.
// По умолчанию пропускается (тег live, нужны переменные окружения):
//
//   supabase start && supabase db reset
//   eval "$(supabase status -o env | sed 's/^/export /')"   # API_URL, ANON_KEY, SERVICE_ROLE_KEY
//   LIVE_SUPABASE_URL=$API_URL LIVE_SUPABASE_ANON_KEY=$ANON_KEY \
//   LIVE_SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY flutter test --tags live test/integration
//
// Каждый тест создаёт своих анонимных пользователей и удаляет их в конце
// (строки синхронизации уходят каскадом). Ключ service role берётся только из
// окружения и нужен для проверки строк на сервере и уборки.
@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mater_studorium/core/db/database.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/supabase_sync_remote.dart';
import 'package:mater_studorium/core/sync/domain/sync_report.dart';
import 'package:mater_studorium/core/sync/domain/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/db_fixtures.dart' show memoryDb;
import '../helpers/sync_fixtures.dart';

String? _env(String name) {
  final value = Platform.environment[name];
  return value == null || value.isEmpty ? null : value;
}

/// HTTP-клиент с «авиарежимом»: при [offline] любой запрос падает так же,
/// как без сети (ClientException).
class _SwitchableHttp extends http.BaseClient {
  final _inner = http.Client();
  var offline = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline) throw http.ClientException('airplane mode', request.url);
    return _inner.send(request);
  }
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
  final created = <String>[];
  final clients = <SupabaseClient>[];

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    if (skip != false) return;
    admin = SupabaseClient(url!, serviceKey!);
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
    await admin.dispose();
  });

  /// Новый анонимный пользователь, как в приложении.
  Future<(SupabaseClient, String, _SwitchableHttp)> signIn() async {
    final net = _SwitchableHttp();
    final client = SupabaseClient(url!, anonKey!, httpClient: net);
    clients.add(client);
    final res = await client.auth.signInAnonymously();
    final id = res.user!.id;
    created.add(id);
    return (client, id, net);
  }

  SyncService serviceFor(
    AppDatabase db,
    SupabaseClient client, {
    int push = 200,
    int pull = 500,
  }) => SyncService(
    remote: SupabaseSyncRemote(client),
    store: db.syncDao,
    currentUserId: () => client.auth.currentUser?.id,
    clock: () => DateTime.utc(2026, 10, 12, 12),
    pushBatchSize: push,
    pullPageSize: pull,
  );

  Future<List<Map<String, dynamic>>> serverLogs(String userId) =>
      admin.from('review_logs').select('id').eq('user_id', userId);

  Future<Map<String, dynamic>> serverState(String userId, String item) async =>
      (await admin
              .from('user_item_state')
              .select()
              .eq('user_id', userId)
              .eq('item_id', item))
          .single;

  // Время в прошлом (секундной точности): сервер его не зажимает.
  final base = DateTime.utc(2026, 1, 15, 10);

  test('AC8.1: 20 ответов в «авиарежиме», затем сеть — все логи на сервере, '
      'дублей нет; повторная отправка идемпотентна', () async {
    final (client, uid, net) = await signIn();
    final db = memoryDb();
    final sync = serviceFor(db, client, push: 7);

    net.offline = true;
    for (var i = 0; i < 20; i++) {
      await answer(db, uid, 'i$i', base.add(Duration(minutes: i)));
    }
    final offline = await sync.sync();
    expect(offline.outcome, SyncOutcome.offline);
    expect(offline.error, isA<NetworkError>());

    net.offline = false;
    final report = await sync.sync();
    expect(report.outcome, SyncOutcome.success, reason: '$report');
    expect(report.logsPushed, 20);
    expect(report.statesPushed, 20);

    final onServer = await serverLogs(uid);
    expect(onServer, hasLength(20));
    expect({for (final r in onServer) r['id']}, hasLength(20));
    final local = await db.select(db.reviewLogs).get();
    expect(local.every((l) => l.syncedAt != null), isTrue);
    expect(
      (await db.select(db.userItemStates).get()).every((s) => !s.dirty),
      isTrue,
    );

    // Ответ сервера «потерялся»: сбрасываем пометки и отправляем снова.
    await db
        .update(db.reviewLogs)
        .write(const ReviewLogsCompanion(syncedAt: Value(null)));
    final again = await sync.sync();
    expect(again.outcome, SyncOutcome.success);
    expect(again.logsPushed, 20);
    expect(await serverLogs(uid), hasLength(20), reason: 'дублей нет');
  }, skip: skip);

  test('AC8.2: два устройства, разные ответы по одному знанию — на сервере '
      'и на обоих устройствах остаётся более позднее', () async {
    final (client, uid, _) = await signIn();
    final d1 = memoryDb();
    final d2 = memoryDb();
    final t1 = base;
    final t2 = base.add(const Duration(minutes: 5));
    await answer(d1, uid, 'shared', t1, reps: 5);
    await answer(d2, uid, 'shared', t2, reps: 7);

    // Позднее приходит первым, раннее — вторым (должно быть отклонено).
    expect((await serviceFor(d2, client).sync()).isSuccess, isTrue);
    expect((await serviceFor(d1, client).sync()).isSuccess, isTrue);

    final row = await serverState(uid, 'shared');
    expect(DateTime.parse(row['updated_at'] as String).toUtc(), t2);
    expect(row['reps'], 7);
    final local1 = await d1.syncDao.dirtyStates(uid, limit: 10);
    expect(local1, isEmpty);
    final s1 = (await d1.select(d1.userItemStates).getSingle());
    expect((s1.reps, s1.updatedAt.toUtc()), (7, t2));
    expect(await serverLogs(uid), hasLength(2));

    // Обратный порядок на другом знании: раннее первым, позднее перезаписывает.
    await answer(d1, uid, 'other', t1, reps: 1);
    await answer(d2, uid, 'other', t2, reps: 2);
    await serviceFor(d1, client).sync();
    await serviceFor(d2, client).sync();
    expect((await serverState(uid, 'other'))['reps'], 2);
    await serviceFor(d1, client).sync();
    final o1 = await (d1.select(
      d1.userItemStates,
    )..where((s) => s.itemId.equals('other'))).getSingle();
    expect(o1.reps, 2);
  }, skip: skip);

  test('часы устройства в будущем: сервер зажимает updatedAt, устройство '
      'принимает зажатое', () async {
    final (client, uid, _) = await signIn();
    final db = memoryDb();
    await answer(db, uid, 'future', DateTime.utc(2100), reps: 3);
    expect((await serviceFor(db, client).sync()).isSuccess, isTrue);

    final serverAt = DateTime.parse(
      (await serverState(uid, 'future'))['updated_at'] as String,
    ).toUtc();
    expect(serverAt.isBefore(DateTime.utc(2100)), isTrue);
    final local = await db.select(db.userItemStates).getSingle();
    expect((local.updatedAt.toUtc(), local.dirty), (serverAt, false));
  }, skip: skip);

  test('pull постранично: новое устройство получает всё', () async {
    final (client, uid, _) = await signIn();
    final d1 = memoryDb();
    for (var i = 0; i < 25; i++) {
      await answer(d1, uid, 'p$i', base.add(Duration(seconds: i)));
    }
    expect((await serviceFor(d1, client, push: 10).sync()).isSuccess, isTrue);

    final d2 = memoryDb();
    final report = await serviceFor(d2, client, pull: 10).sync();
    expect(report.outcome, SyncOutcome.success);
    expect((report.statesPulled, report.logsPulled), (25, 25));
    expect(await d2.select(d2.userItemStates).get(), hasLength(25));
    final logs = await d2.select(d2.reviewLogs).get();
    expect(logs.every((l) => l.syncedAt != null), isTrue);
    final again = await serviceFor(d2, client, pull: 10).sync();
    expect((again.statesPulled, again.logsPulled), (0, 0));
  }, skip: skip);

  test('изоляция на живом стеке: B не видит и не пишет данные A; без входа '
      'ничего; лимит пакета', () async {
    final (a, aId, _) = await signIn();
    final (b, bId, _) = await signIn();
    final db = memoryDb();
    await answer(db, aId, 'i1', base, reps: 4);
    expect((await serviceFor(db, a).sync()).isSuccess, isTrue);

    // B видит только своё.
    expect(await b.from('user_item_state').select(), isEmpty);
    expect(await b.from('review_logs').select(), isEmpty);
    // B не пишет от имени A (p_user_id A под сессией B).
    await expectLater(
      b.rpc<dynamic>(
        'upsert_item_states',
        params: {
          'p_user_id': aId,
          'p_states': [stateToJson(syncState('i1', base, reps: 99))],
        },
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    // Прямой записи нет ни у кого.
    await expectLater(
      b.from('user_item_state').update({'reps': 99}).eq('user_id', aId),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      a.from('review_logs').insert({
        'id': newUuid(),
        'user_id': aId,
        'deck_id': 'infosec',
        'deck_version': 1,
        'item_id': 'i1',
        'question_id': 'i1.q1',
        'question_type': 'mcq',
        'rating': 3,
        'grade_source': 'auto',
        'duration_ms': 1,
        'reviewed_at': base.toIso8601String(),
        'sync_seq': 0,
      }),
      throwsA(isA<PostgrestException>()),
    );
    expect((await serverState(aId, 'i1'))['reps'], 4);

    // Наш клиент и сам не отправит данные A под сессией B.
    await expectLater(
      SupabaseSyncRemote(b).upsertItemStates(aId, [syncState('i1', base)]),
      throwsA(isA<AuthError>()),
    );

    // Без входа (только anon-ключ): ни чтения, ни RPC.
    final guest = SupabaseClient(url!, anonKey!);
    clients.add(guest);
    await expectLater(
      guest.from('user_item_state').select(),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      guest.rpc<dynamic>(
        'insert_review_logs',
        params: {'p_user_id': aId, 'p_logs': <Object>[]},
      ),
      throwsA(isA<PostgrestException>()),
    );

    // Пакет больше 500 — SyncRejectedError, ничего не записано.
    await expectLater(
      SupabaseSyncRemote(b).upsertItemStates(bId, [
        for (var i = 0; i < 501; i++) syncState('x$i', base),
      ]),
      throwsA(isA<SyncRejectedError>()),
    );
    expect(
      await admin.from('user_item_state').select('item_id').eq('user_id', bId),
      isEmpty,
    );
  }, skip: skip);
}
