// SupabaseDuelRepository на настоящем SupabaseClient с подменённым HTTP
// (package:http/testing): что уходит в сеть и как ответы сервера превращаются
// в типизированные ошибки (AC10.2).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/duel/data/supabase_duel_repository.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/sync_fixtures.dart' show userA, userB;

String _jwt(String sub) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': sub, 'role': 'authenticated', 'exp': 4102444800})}.sig';
}

http.Response _json(http.Request req, Object? body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      request: req,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Ответ RPC в виде `jsonb` дуэли (как у `private.duel_json`).
Map<String, Object?> _duelJson({
  String id = 'd1',
  String? code = 'K7Q2MX',
  String status = 'open',
  bool isCreator = true,
  bool otherJoined = false,
  String? otherName,
}) => {
  'id': id,
  'code': code,
  'deck_id': 'infosec',
  'deck_version': 2,
  'question_ids': ['q.1', 'q.2', 'q.3', 'q.4', 'q.5'],
  'status': status,
  'created_at': '2026-10-13T12:00:00.123456+00:00',
  'expires_at': '2026-10-16T12:00:00.123456+00:00',
  'is_creator': isCreator,
  'other_joined': otherJoined,
  'other_name': otherName,
  'my_done_at': null,
  'other_done_at': '2026-10-13T13:00:00+00:00',
};

http.Response _pgError(
  http.Request req,
  String code, {
  String? hint,
  int status = 400,
}) => _json(req, {
  'code': code,
  'message': 'ошибка $code',
  'details': null,
  'hint': hint,
}, status);

void main() {
  late List<http.Request> sent;
  late http.Response Function(http.Request) reply;

  Future<SupabaseClient> clientAs(String? sessionUser) async {
    sent = [];
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
        sent.add(req);
        return reply(req);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    if (sessionUser != null) await client.auth.signInAnonymously();
    return client;
  }

  Future<SupabaseDuelRepository> repo({String? user = userA}) async =>
      SupabaseDuelRepository(await clientAs(user));

  setUp(() => reply = (req) => _json(req, null));

  group('create', () {
    test('уходит RPC create_duel с p_user_id и набором вопросов', () async {
      reply = (req) => _json(req, _duelJson());
      final duel = await (await repo()).create(
        duelId: 'd1',
        deckId: 'infosec',
        deckVersion: 2,
        questionIds: const ['q.1', 'q.2', 'q.3', 'q.4', 'q.5'],
      );
      expect(sent.single.url.path, '/rest/v1/rpc/create_duel');
      expect(jsonDecode(sent.single.body), {
        'p_user_id': userA,
        'p_duel_id': 'd1',
        'p_deck_id': 'infosec',
        'p_deck_version': 2,
        'p_question_ids': ['q.1', 'q.2', 'q.3', 'q.4', 'q.5'],
      });
      expect(duel.id, 'd1');
      expect(duel.code, 'K7Q2MX');
      expect(duel.status, DuelStatus.open);
      expect(duel.isCreator, isTrue);
      expect(duel.createdAt, DateTime.utc(2026, 10, 13, 12, 0, 0, 123, 456));
      expect(duel.createdAt.isUtc, isTrue);
      expect(duel.expiresAt.difference(duel.createdAt).inHours, 72);
      expect(duel.otherDoneAt, DateTime.utc(2026, 10, 13, 13));
      expect(duel.myDoneAt, isNull);
      expect(duel.questionIds, hasLength(5));
    });

    test(
      '23503 (колоды нет, не публичная, версия выше) — DeckNotFoundError',
      () async {
        reply = (req) => _pgError(req, '23503');
        await expectLater(
          (await repo()).create(
            duelId: 'd1',
            deckId: 'infosec',
            deckVersion: 9,
            questionIds: const ['q.1', 'q.2', 'q.3', 'q.4', 'q.5'],
          ),
          throwsA(
            isA<DeckNotFoundError>().having(
              (e) => e.deckId,
              'deckId',
              'infosec',
            ),
          ),
        );
      },
    );

    for (final (hint, kind) in [
      ('active_limit', DuelLimitKind.activeDuels),
      ('daily_limit', DuelLimitKind.dailyCreate),
    ]) {
      test('MS429 $hint — DuelLimitError($kind)', () async {
        reply = (req) => _pgError(req, 'MS429', hint: hint);
        await expectLater(
          (await repo()).create(
            duelId: 'd1',
            deckId: 'infosec',
            deckVersion: 2,
            questionIds: const ['q.1', 'q.2', 'q.3', 'q.4', 'q.5'],
          ),
          throwsA(isA<DuelLimitError>().having((e) => e.kind, 'kind', kind)),
        );
      });
    }
  });

  group('join', () {
    test('joined: дуэль с именем создателя, код не приходит', () async {
      reply = (req) => _json(req, {
        'result': 'joined',
        'duel': _duelJson(
          code: null,
          status: 'active',
          isCreator: false,
          otherJoined: true,
          otherName: 'Алиса',
        ),
      });
      final duel = await (await repo(user: userB)).join('K7Q2MX');
      expect(sent.single.url.path, '/rest/v1/rpc/join_duel');
      expect(jsonDecode(sent.single.body), {
        'p_user_id': userB,
        'p_code': 'K7Q2MX',
      });
      expect(duel.isCreator, isFalse);
      expect(duel.code, isNull);
      expect(duel.otherName, 'Алиса');
      expect(duel.status, DuelStatus.active);
    });

    test('own_duel: своя дуэль возвращается без ошибки', () async {
      reply = (req) => _json(req, {'result': 'own_duel', 'duel': _duelJson()});
      expect((await (await repo()).join('K7Q2MX')).isCreator, isTrue);
    });

    test(
      'not_found (нет такого кода или просрочен) — DuelCodeNotFoundError',
      () async {
        reply = (req) => _json(req, {'result': 'not_found'});
        await expectLater(
          (await repo()).join('K7Q2MX'),
          throwsA(isA<DuelCodeNotFoundError>()),
        );
      },
    );

    test('full — DuelFullError', () async {
      reply = (req) => _json(req, {'result': 'full'});
      await expectLater(
        (await repo()).join('K7Q2MX'),
        throwsA(isA<DuelFullError>()),
      );
    });

    test('MS429 join_attempts — DuelLimitError(joinAttempts)', () async {
      reply = (req) => _pgError(req, 'MS429', hint: 'join_attempts');
      await expectLater(
        (await repo()).join('K7Q2MX'),
        throwsA(
          isA<DuelLimitError>().having(
            (e) => e.kind,
            'kind',
            DuelLimitKind.joinAttempts,
          ),
        ),
      );
    });

    test('неизвестный result и мусорный ответ — UnexpectedError', () async {
      reply = (req) => _json(req, {'result': 'wat'});
      await expectLater(
        (await repo()).join('K7Q2MX'),
        throwsA(isA<UnexpectedError>()),
      );
      reply = (req) => _json(req, [1, 2]);
      await expectLater(
        (await repo()).join('K7Q2MX'),
        throwsA(isA<UnexpectedError>()),
      );
    });
  });

  group('get и mine', () {
    test('get: null, если дуэли нет или это чужая', () async {
      reply = (req) => _json(req, null);
      expect(await (await repo()).get('d1'), isNull);
      expect(sent.single.url.path, '/rest/v1/rpc/get_duel');
      expect(jsonDecode(sent.single.body), {'p_duel_id': 'd1'});
    });

    test('get: дуэль разбирается', () async {
      reply = (req) => _json(req, _duelJson(otherName: 'Боб'));
      expect((await (await repo()).get('d1'))!.otherName, 'Боб');
    });

    test('mine: список дуэлей', () async {
      reply = (req) => _json(req, [_duelJson(id: 'a'), _duelJson(id: 'b')]);
      final duels = await (await repo()).mine();
      expect(duels.map((d) => d.id), ['a', 'b']);
      expect(sent.single.url.path, '/rest/v1/rpc/my_duels');
    });

    test('mine: не массив — UnexpectedError', () async {
      reply = (req) => _json(req, {'x': 1});
      await expectLater((await repo()).mine(), throwsA(isA<UnexpectedError>()));
    });

    test(
      'дуэль неожиданной формы — UnexpectedError, не сырое исключение',
      () async {
        reply = (req) => _json(req, {'id': 'd1'});
        await expectLater(
          (await repo()).get('d1'),
          throwsA(isA<UnexpectedError>()),
        );
        reply = (req) => _json(req, _duelJson(status: 'weird'));
        await expectLater(
          (await repo()).get('d1'),
          throwsA(isA<UnexpectedError>()),
        );
      },
    );
  });

  group('имя', () {
    test('displayName читает свой профиль', () async {
      reply = (req) => _json(req, {'display_name': 'Алиса'});
      expect(await (await repo()).displayName(), 'Алиса');
      expect(sent.single.url.path, '/rest/v1/profiles');
      expect(sent.single.url.queryParameters['id'], 'eq.$userA');
    });

    test('displayName: профиля или имени нет — null', () async {
      reply = (req) => _json(req, {'display_name': null});
      expect(await (await repo()).displayName(), isNull);
    });

    test('setDisplayName обновляет только свою строку', () async {
      reply = (req) => http.Response('', 204, request: req);
      await (await repo()).setDisplayName('Алиса');
      expect(sent.single.method, 'PATCH');
      expect(sent.single.url.queryParameters['id'], 'eq.$userA');
      expect(jsonDecode(sent.single.body), {'display_name': 'Алиса'});
    });

    test('сервер отклонил имя (23514) — RequestRejectedError', () async {
      reply = (req) => _pgError(req, '23514');
      await expectLater(
        (await repo()).setDisplayName('x'),
        throwsA(isA<RequestRejectedError>()),
      );
    });
  });

  group('сессия: без запроса в сеть', () {
    test('нет сессии — AuthError', () async {
      final r = await repo(user: null);
      await expectLater(r.mine(), throwsA(isA<AuthError>()));
      await expectLater(r.join('K7Q2MX'), throwsA(isA<AuthError>()));
      expect(sent, isEmpty);
    });
  });

  group('mapDuelError', () {
    PostgrestException pg(String code, {String? hint}) =>
        PostgrestException(message: 'm', code: code, hint: hint);

    test('сеть и таймаут — NetworkError', () {
      expect(mapDuelError(http.ClientException('x')), isA<NetworkError>());
      expect(mapDuelError(TimeoutException('t')), isA<NetworkError>());
    });

    test('lock_timeout, 5xx, MS503 — повторяемые', () {
      expect(mapDuelError(pg('55P03')), isA<NetworkError>());
      expect(mapDuelError(pg('503')), isA<NetworkError>());
      expect(mapDuelError(pg('MS503')), isA<NetworkError>());
    });

    test('42501 (нет входа или чужой p_user_id) — AuthError', () {
      expect(mapDuelError(pg('42501')), isA<AuthError>());
    });

    test('ошибки значений 22xxx, 23xxx — RequestRejectedError с кодом', () {
      for (final code in ['22023', '23514', '23505']) {
        expect(
          mapDuelError(pg(code)),
          isA<RequestRejectedError>().having((e) => e.code, 'code', code),
        );
      }
    });

    test('MS429 с неизвестным hint — безобидный лимит активных', () {
      expect(
        mapDuelError(pg('MS429', hint: 'новый')),
        isA<DuelLimitError>().having(
          (e) => e.kind,
          'kind',
          DuelLimitKind.activeDuels,
        ),
      );
    });

    test('AppError проходит как есть, прочее — UnexpectedError', () {
      const e = DuelFullError();
      expect(mapDuelError(e), same(e));
      expect(mapDuelError(StateError('x')), isA<UnexpectedError>());
    });
  });
}
