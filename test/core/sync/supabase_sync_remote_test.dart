// SupabaseSyncRemote на настоящем SupabaseClient с подменённым HTTP
// (package:http/testing): что уходит в сеть, а что отсекается до запроса.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/supabase_sync_remote.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/reports/domain/report.dart';
import 'package:mater_studorium/features/reports/domain/report_reason.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/duel_fixtures.dart' show kDuelId;
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

  group('жалобы и скрытые вопросы (T20, ADR-33)', () {
    final report = Report.question(
      id: 'aaaaaaaa-0000-4000-8000-000000000001',
      deckId: 'infosec',
      deckVersion: 1,
      questionId: 'xss.q1',
      reason: ReportReason.typo,
      comment: 'опечатка',
      questionText: 'Что такое XSS?',
    );

    test('submit_report: тело — p_user_id и отчёт; ответ true/false', () async {
      restReply = (req) => _json(req, true);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      expect(await remote.submitReport(userA, report), isTrue);
      expect(rest.single.url.path, '/rest/v1/rpc/submit_report');
      final body = jsonDecode(rest.single.body) as Map<String, dynamic>;
      expect(body['p_user_id'], userA);
      expect(body['p_report'], report.toJson());
      expect(body['p_report'], isNot(contains('user_id')));

      restReply = (req) => _json(req, false);
      expect(await remote.submitReport(userA, report), isFalse);
    });

    test('submit_report: ответ не bool — UnexpectedError', () async {
      restReply = (req) => _json(req, 'ok');
      final remote = SupabaseSyncRemote(await clientAs(userA));
      await expectLater(
        remote.submitReport(userA, report),
        throwsA(isA<UnexpectedError>()),
      );
    });

    test(
      'сессия другого пользователя и нет сессии — AuthError без запроса',
      () async {
        await expectLater(
          SupabaseSyncRemote(await clientAs(userB)).submitReport(userA, report),
          throwsA(isA<AuthError>()),
        );
        await expectLater(
          SupabaseSyncRemote(await clientAs(null)).pullHiddenQuestions(userA),
          throwsA(isA<AuthError>()),
        );
        await expectLater(
          SupabaseSyncRemote(await clientAs(userB)).pullHiddenQuestions(userA),
          throwsA(isA<AuthError>()),
        );
        expect(rest, isEmpty);
      },
    );

    Future<Object?> submitError(Map<String, Object?> body, int status) async {
      restReply = (req) => _json(req, body, status);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      try {
        await remote.submitReport(userA, report);
      } on Object catch (e) {
        return e;
      }
      return null;
    }

    test(
      'MS429 (дневной лимит) — QuotaExceededError, не сеть и не отказ',
      () async {
        expect(
          await submitError({'code': 'MS429', 'message': 'лимит'}, 400),
          isA<QuotaExceededError>(),
        );
      },
    );

    test('23503 (колода не найдена) и 23514 (CHECK) — SyncRejectedError; '
        '42501 — AuthError; 5xx — NetworkError', () async {
      expect(
        await submitError({'code': '23503', 'message': 'нет колоды'}, 409),
        isA<SyncRejectedError>(),
      );
      expect(
        await submitError({'code': '23514', 'message': 'check'}, 400),
        isA<SyncRejectedError>(),
      );
      expect(
        await submitError({'code': '42501', 'message': 'denied'}, 403),
        isA<AuthError>(),
      );
      expect(
        await submitError({'code': '55P03', 'message': 'lock'}, 500),
        isA<NetworkError>(),
      );
    });

    test('hidden_questions: массив строк; мусор пропускается', () async {
      restReply = (req) => _json(req, ['a.q1', 'b.q2', 5, '', null, 'a.q1']);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      expect(await remote.pullHiddenQuestions(userA), {'a.q1', 'b.q2'});
      expect(rest.single.url.path, '/rest/v1/rpc/hidden_questions');
    });

    test(
      'hidden_questions: не массив — UnexpectedError, пустой — пусто',
      () async {
        restReply = (req) => _json(req, {'a': 1});
        final remote = SupabaseSyncRemote(await clientAs(userA));
        await expectLater(
          remote.pullHiddenQuestions(userA),
          throwsA(isA<UnexpectedError>()),
        );
        restReply = (req) => _json(req, <Object>[]);
        expect(await remote.pullHiddenQuestions(userA), isEmpty);
      },
    );
  });

  group('ответы дуэли (T23, ADR-36)', () {
    const answer = DuelAnswerPayload(
      duelId: kDuelId,
      questionId: 'duel-deck.1.q1',
      answer: {
        'selected': ['a'],
      },
      isCorrect: true,
      durationMs: 1500,
    );

    test(
      'submit_duel_answer: тело RPC и результат recorded/duplicate',
      () async {
        restReply = (req) =>
            _json(req, {'result': 'recorded', 'duel': <String, Object?>{}});
        final remote = SupabaseSyncRemote(await clientAs(userA));
        expect(await remote.submitDuelAnswer(userA, answer), isTrue);
        expect(rest.single.url.path, '/rest/v1/rpc/submit_duel_answer');
        expect(jsonDecode(rest.single.body), {
          'p_user_id': userA,
          'p_duel_id': kDuelId,
          'p_question_id': 'duel-deck.1.q1',
          'p_answer': {
            'selected': ['a'],
          },
          'p_is_correct': true,
          'p_duration_ms': 1500,
        });

        restReply = (req) =>
            _json(req, {'result': 'duplicate', 'duel': <String, Object?>{}});
        expect(await remote.submitDuelAnswer(userA, answer), isFalse);
      },
    );

    test('ответ не объект или result неизвестен — UnexpectedError', () async {
      final remote = SupabaseSyncRemote(await clientAs(userA));
      for (final body in <Object>[
        true,
        <Object>[],
        {'result': 'что-то'},
        {'duel': <String, Object?>{}},
      ]) {
        restReply = (req) => _json(req, body);
        await expectLater(
          remote.submitDuelAnswer(userA, answer),
          throwsA(isA<UnexpectedError>()),
          reason: '$body',
        );
      }
    });

    test(
      'сессия другого пользователя и нет сессии — AuthError без запроса',
      () async {
        await expectLater(
          SupabaseSyncRemote(await clientAs(userB))
              .submitDuelAnswer(userA, answer),
          throwsA(isA<AuthError>()),
        );
        await expectLater(
          SupabaseSyncRemote(await clientAs(null))
              .submitDuelAnswer(userA, answer),
          throwsA(isA<AuthError>()),
        );
        expect(rest, isEmpty);
      },
    );

    Future<Object?> errorOf(String code, int status) async {
      restReply = (req) => _json(req, {'code': code, 'message': 'x'}, status);
      final remote = SupabaseSyncRemote(await clientAs(userA));
      try {
        await remote.submitDuelAnswer(userA, answer);
      } on Object catch (e) {
        return e;
      }
      return null;
    }

    test('MS410 и MS404 — DuelClosedError (повтор не поможет)', () async {
      expect(await errorOf('MS410', 400), isA<DuelClosedError>());
      expect(await errorOf('MS404', 400), isA<DuelClosedError>());
    });

    test('PGRST202 (функции нет на сервере, миграция позже клиента) — '
        'NetworkError: ждать, а не отбрасывать', () async {
      expect(await errorOf('PGRST202', 404), isA<NetworkError>());
    });

    test('22023 и 23514 — SyncRejectedError; 42501 — AuthError; '
        '55P03 и 5xx — NetworkError', () async {
      expect(await errorOf('22023', 400), isA<SyncRejectedError>());
      expect(await errorOf('23514', 400), isA<SyncRejectedError>());
      expect(await errorOf('42501', 403), isA<AuthError>());
      expect(await errorOf('55P03', 500), isA<NetworkError>());
      expect(await errorOf('500', 500), isA<NetworkError>());
    });
  });
}
