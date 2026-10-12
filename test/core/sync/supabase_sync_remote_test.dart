// SupabaseSyncRemote на настоящем SupabaseClient с подменённым HTTP
// (package:http/testing): что уходит в сеть, а что отсекается до запроса.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/supabase_sync_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/sync_fixtures.dart';

String _jwt(String sub) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': sub, 'role': 'authenticated', 'exp': 4102444800})}.sig';
}

http.Response _json(http.Request req, Object body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      request: req,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late List<http.Request> rest;
  late http.Response Function(http.Request) restReply;

  /// Клиент, вошедший анонимно как [sessionUser] (через фейковый /signup).
  Future<SupabaseClient> clientAs(String? sessionUser) async {
    rest = [];
    final client = SupabaseClient(
      'http://fake.local',
      'anon',
      httpClient: MockClient((req) async {
        if (req.url.path == '/auth/v1/signup') {
          return _json(req, {
            'access_token': _jwt(sessionUser!),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'r',
            'user': {
              'id': sessionUser,
              'aud': 'authenticated',
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
              'created_at': '2026-10-12T00:00:00Z',
              'is_anonymous': true,
            },
          });
        }
        rest.add(req);
        return restReply(req);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    if (sessionUser != null) await client.auth.signInAnonymously();
    return client;
  }

  setUp(() => restReply = (req) => _json(req, <Object>[]));

  group('проверка сессии в _guard: без запроса в сеть', () {
    test('сессия другого пользователя — AuthError', () async {
      final remote = SupabaseSyncRemote(await clientAs(userB));
      await expectLater(
        remote.insertReviewLogs(userA, [syncLog('i1', s0)]),
        throwsA(isA<AuthError>()),
      );
      await expectLater(
        remote.upsertItemStates(userA, [syncState('i1', s0)]),
        throwsA(isA<AuthError>()),
      );
      await expectLater(
        remote.pullItemStates(userA, afterSeq: 0, limit: 10),
        throwsA(isA<AuthError>()),
      );
      await expectLater(
        remote.pullReviewLogs(userA, afterSeq: 0, limit: 10),
        throwsA(isA<AuthError>()),
      );
      expect(rest, isEmpty);
    });

    test('нет сессии — AuthError', () async {
      final remote = SupabaseSyncRemote(await clientAs(null));
      await expectLater(
        remote.insertReviewLogs(userA, [syncLog('i1', s0)]),
        throwsA(isA<AuthError>()),
      );
      expect(rest, isEmpty);
    });

    test('своя сессия — запрос уходит с p_user_id', () async {
      restReply = (req) => _json(req, 1);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      expect(await remote.insertReviewLogs(userA, [syncLog('i1', s0)]), 1);
      final body = jsonDecode(rest.single.body) as Map<String, dynamic>;
      expect(rest.single.url.path, '/rest/v1/rpc/insert_review_logs');
      expect(body['p_user_id'], userA);
      expect((body['p_logs'] as List).single, isNot(contains('user_id')));
    });
  });

  group('_checkOwner: строка другого пользователя в ответе', () {
    Map<String, Object?> stateRow(String user, int seq) => {
      ...stateToJson(syncState('i1', s0)),
      'user_id': user,
      'sync_seq': seq,
    };

    test('pull состояний — AuthError', () async {
      restReply = (req) => _json(req, [stateRow(userB, 1)]);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      await expectLater(
        remote.pullItemStates(userA, afterSeq: 0, limit: 10),
        throwsA(isA<AuthError>()),
      );
    });

    test('ответ upsert — AuthError', () async {
      restReply = (req) => _json(req, [stateRow(userB, 1)]);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      await expectLater(
        remote.upsertItemStates(userA, [syncState('i1', s0)]),
        throwsA(isA<AuthError>()),
      );
    });

    test('pull логов — AuthError', () async {
      restReply = (req) => _json(req, [
        {...logToJson(syncLog('i1', s0)), 'user_id': userB, 'sync_seq': 1},
      ]);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      await expectLater(
        remote.pullReviewLogs(userA, afterSeq: 0, limit: 10),
        throwsA(isA<AuthError>()),
      );
    });

    test('pull по возрастанию sync_seq и только своего user_id', () async {
      final remote = SupabaseSyncRemote(await clientAs(userA));
      await remote.pullItemStates(userA, afterSeq: 7, limit: 10);
      final q = rest.single.url.queryParameters;
      expect(q['order'], startsWith('sync_seq.asc'));
      expect(q['sync_seq'], 'gt.7');
      expect(q['user_id'], 'eq.$userA');
      expect(q['limit'], '10');
    });

    test('неразбираемая строка состояния (-infinity) пропускается, курсор '
        'её проходит', () async {
      restReply = (req) => _json(req, [
        stateRow(userA, 1),
        {...stateRow(userA, 2), 'updated_at': '-infinity'},
        {...stateRow(userA, 3), 'due': '0044-03-15T12:00:00+00:00 BC'},
      ]);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      final page = await remote.pullItemStates(userA, afterSeq: 0, limit: 10);
      expect((page.rows.length, page.fetched, page.lastSeq), (1, 3, 3));
    });
  });

  group('ответы с ошибкой → AppError', () {
    Future<Object?> errorFor(Map<String, Object?> body, int status) async {
      restReply = (req) => _json(req, body, status);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      try {
        await remote.insertReviewLogs(userA, [syncLog('i1', s0)]);
      } on Object catch (e) {
        return e;
      }
      return null;
    }

    test('22P05 (\\u0000 в тексте) и PGRST102 (тело не разобрано) — '
        'SyncRejectedError', () async {
      expect(
        await errorFor({'code': '22P05', 'message': 'unsupported'}, 400),
        isA<SyncRejectedError>(),
      );
      expect(
        await errorFor({'code': 'PGRST102', 'message': 'Invalid body'}, 400),
        isA<SyncRejectedError>(),
      );
    });

    test('55P03 (lock_timeout) — NetworkError, повтор с паузой', () async {
      expect(
        await errorFor({'code': '55P03', 'message': 'lock timeout'}, 500),
        isA<NetworkError>(),
      );
    });
  });
}
