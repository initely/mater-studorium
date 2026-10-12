// SupabaseGradingRepository на настоящем SupabaseClient с подменённым HTTP
// (package:http/testing): что уходит в сеть и как разобраны ответы и ошибки
// по таблице README `grade-open-answer`.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/grading/data/supabase_grading_repository.dart';
import 'package:mater_studorium/features/grading/domain/grading_repository.dart';
import 'package:mater_studorium/features/grading/domain/open_grade.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

Map<String, Object?> _okBody() => {
  'verdict': 'partial',
  'score': 0.5,
  'points': [
    {'id': 'p1', 'status': 'hit'},
    {'id': 'p2', 'status': 'miss'},
  ],
  'missed': [
    {'id': 'p2', 'text': 'Пункт два', 'status': 'miss', 'required': true},
  ],
  'feedback': 'Мало деталей.',
  'suggested_rating': 2,
  'source': 'llm',
  'cached': false,
  'remaining_quota': 27,
  'quota_reset_at': '2026-10-13T00:00:00.000Z',
};

Map<String, Object?> _error(String code, {String? resetAt}) => {
  'error': {'code': code, 'message': 'dev text', 'reset_at': ?resetAt},
};

const _request = GradeRequest(
  deckId: 'sample',
  deckVersion: 1,
  questionId: 'infosec.xss.reflected.q2',
  answerText: 'Скрипт из запроса попадает в ответ без экранирования',
  inputMode: AnswerInputMode.text,
);

void main() {
  late List<http.Request> calls;
  late FutureOr<http.Response> Function(http.Request) reply;

  Future<SupabaseGradingRepository> repo({
    bool signedIn = true,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    calls = [];
    final client = SupabaseClient(
      'http://fake.local',
      'anon-key',
      httpClient: MockClient((req) async {
        if (req.url.path == '/auth/v1/signup') {
          return _json(req, {
            'access_token': _jwt('user-1'),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'r',
            'user': {
              'id': 'user-1',
              'aud': 'authenticated',
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
              'created_at': '2026-10-12T00:00:00Z',
              'is_anonymous': true,
            },
          });
        }
        calls.add(req);
        return reply(req);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    if (signedIn) await client.auth.signInAnonymously();
    return SupabaseGradingRepository(client, timeout: timeout);
  }

  setUp(() => reply = (req) => _json(req, _okBody()));

  group('запрос', () {
    test(
      'POST на функцию с JWT пользователя и ровно полями контракта',
      () async {
        final r = await repo();
        final grade = await r.grade(_request);

        expect(calls, hasLength(1));
        final req = calls.single;
        expect(req.method, 'POST');
        expect(req.url.path, '/functions/v1/grade-open-answer');
        expect(req.headers['Authorization'], 'Bearer ${_jwt('user-1')}');
        expect(req.headers['Content-Type'], startsWith('application/json'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body, {
          'deck_id': 'sample',
          'deck_version': 1,
          'question_id': 'infosec.xss.reflected.q2',
          'answer_text': 'Скрипт из запроса попадает в ответ без экранирования',
          'input_mode': 'text',
        });
        // Рубрики, эталона, языка и модели в теле нет (ADR-31, п. 1).
        for (final forbidden in [
          'rubric',
          'reference_answer',
          'lang',
          'model',
          'user_id',
        ]) {
          expect(body.containsKey(forbidden), isFalse, reason: forbidden);
        }
        expect(grade.verdict, GradeVerdict.partial);
        expect(grade.missed.single.text, 'Пункт два');
        expect(grade.remainingQuota, 27);
      },
    );

    test('голосовой ввод: input_mode = voice', () async {
      final r = await repo();
      await r.grade(
        const GradeRequest(
          deckId: 'sample',
          deckVersion: 3,
          questionId: 'q',
          answerText: 'надиктовано',
          inputMode: AnswerInputMode.voice,
        ),
      );
      final body = jsonDecode(calls.single.body) as Map<String, dynamic>;
      expect(body['input_mode'], 'voice');
      expect(body['deck_version'], 3);
      expect(body.keys.toSet(), {
        'deck_id',
        'deck_version',
        'question_id',
        'answer_text',
        'input_mode',
      });
    });

    test(
      'ответ ровно на лимите (2000) уходит, длиннее — нет запроса',
      () async {
        final r = await repo();
        await r.grade(
          GradeRequest(
            deckId: 'sample',
            deckVersion: 1,
            questionId: 'q',
            answerText: 'я' * 2000,
            inputMode: AnswerInputMode.text,
          ),
        );
        expect(calls, hasLength(1));

        await expectLater(
          r.grade(
            GradeRequest(
              deckId: 'sample',
              deckVersion: 1,
              questionId: 'q',
              answerText: 'я' * 2001,
              inputMode: AnswerInputMode.text,
            ),
          ),
          throwsA(
            isA<RequestRejectedError>().having(
              (e) => e.code,
              'code',
              'answer_too_long',
            ),
          ),
        );
        expect(calls, hasLength(1));
      },
    );

    test('нет сессии — AuthError без запроса', () async {
      final r = await repo(signedIn: false);
      await expectLater(r.grade(_request), throwsA(isA<AuthError>()));
      expect(calls, isEmpty);
    });
  });

  group('любой 401 — «не вошёл», тело не разбирается', () {
    final bodies = <String, http.Response Function(http.Request)>{
      'ответ функции': (req) => _json(req, _error('unauthorized'), 401),
      'ответ шлюза Supabase': (req) => _json(req, {
        'code': 'UNAUTHORIZED_INVALID_JWT_FORMAT',
        'message': 'Invalid JWT',
      }, 401),
      'текст не JSON': (req) =>
          http.Response('Unauthorized', 401, request: req),
      'мусор в JSON': (req) => http.Response(
        '{"error": ',
        401,
        request: req,
        headers: {'content-type': 'application/json'},
      ),
      'пустое тело': (req) => http.Response('', 401, request: req),
      'тело с 429 внутри': (req) => _json(req, _error('quota_exceeded'), 401),
    };
    for (final MapEntry(:key, :value) in bodies.entries) {
      test(key, () async {
        reply = value;
        final r = await repo();
        await expectLater(r.grade(_request), throwsA(isA<AuthError>()));
      });
    }
  });

  group('429 — квота', () {
    for (final code in ['quota_exceeded', 'request_limit', 'budget_exceeded']) {
      test('$code с reset_at', () async {
        reply = (req) =>
            _json(req, _error(code, resetAt: '2026-10-13T00:00:00.000Z'), 429);
        final r = await repo();
        await expectLater(
          r.grade(_request),
          throwsA(
            isA<QuotaExceededError>().having(
              (e) => e.resetAt,
              'resetAt',
              DateTime.utc(2026, 10, 13),
            ),
          ),
        );
      });
    }

    test('без тела и с мусором в reset_at — квота без времени', () async {
      for (final response in <http.Response Function(http.Request)>[
        (req) => http.Response('', 429, request: req),
        (req) => _json(req, _error('quota_exceeded', resetAt: 'скоро'), 429),
        (req) => _json(req, {'error': 'строка'}, 429),
      ]) {
        reply = response;
        final r = await repo();
        await expectLater(
          r.grade(_request),
          throwsA(
            isA<QuotaExceededError>().having(
              (e) => e.resetAt,
              'resetAt',
              isNull,
            ),
          ),
        );
      }
    });
  });

  group('сбои сервера и сети — NetworkError (недоступно)', () {
    for (final status in [500, 502, 503, 504, 408]) {
      test('HTTP $status', () async {
        reply = (req) => _json(req, _error('model_error'), status);
        final r = await repo();
        await expectLater(r.grade(_request), throwsA(isA<NetworkError>()));
      });
    }

    test('сеть оборвалась', () async {
      reply = (req) => throw http.ClientException('connection reset', req.url);
      final r = await repo();
      await expectLater(r.grade(_request), throwsA(isA<NetworkError>()));
    });

    test('ответа нет дольше таймаута клиента', () async {
      reply = (req) => Completer<http.Response>().future;
      final r = await repo(timeout: const Duration(milliseconds: 200));
      await expectLater(r.grade(_request), throwsA(isA<NetworkError>()));
    });

    test('таймаут клиента больше серверного дедлайна 12 с', () {
      expect(kGradingClientTimeout, const Duration(seconds: 15));
      expect(kGradingClientTimeout, greaterThan(const Duration(seconds: 12)));
    });
  });

  group('ошибки запроса — RequestRejectedError', () {
    final cases = {
      400: 'unknown_field',
      404: 'deck_not_found',
      413: 'payload_too_large',
      403: 'origin_not_allowed',
    };
    for (final MapEntry(key: status, value: code) in cases.entries) {
      test('HTTP $status $code', () async {
        reply = (req) => _json(req, _error(code), status);
        final r = await repo();
        await expectLater(
          r.grade(_request),
          throwsA(
            isA<RequestRejectedError>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.code, 'code', code),
          ),
        );
      });
    }
  });

  group('невалидный ответ — UnexpectedError', () {
    final bad = <String, http.Response Function(http.Request)>{
      'JSON не по контракту': (req) => _json(req, {'verdict': 'meh'}),
      'не объект': (req) => _json(req, [1, 2]),
      'битый JSON при 200': (req) => http.Response(
        '{"verdict": "correct", ',
        200,
        request: req,
        headers: {'content-type': 'application/json'},
      ),
      'текст при 200': (req) => http.Response('ok', 200, request: req),
      'пустой ответ': (req) => http.Response('', 200, request: req),
      'score вне диапазона': (req) => _json(req, _okBody()..['score'] = 7),
    };
    for (final MapEntry(:key, :value) in bad.entries) {
      test(key, () async {
        reply = value;
        final r = await repo();
        await expectLater(r.grade(_request), throwsA(isA<UnexpectedError>()));
      });
    }

    test('текст ответа пользователя не попадает в сообщения ошибок', () async {
      reply = (req) => _json(req, {'verdict': 'meh'});
      final r = await repo();
      try {
        await r.grade(_request);
        fail('ожидалась ошибка');
      } on AppError catch (e) {
        expect(e.message, isNot(contains('экранирования')));
      }
    });
  });

  test('сырые исключения Supabase и http наружу не выходят', () async {
    final errors = [
      const FunctionsFetchException(details: 'boom'),
      const FunctionsHttpException(status: 500),
      const FunctionsRelayException(status: 502),
      TimeoutException('t'),
      http.ClientException('c'),
      StateError('что-то своё'),
    ];
    for (final e in errors) {
      expect(mapGradingError(e), isA<AppError>(), reason: '$e');
    }
  });
}
