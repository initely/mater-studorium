// Чистые правила синхронизации: LWW-решение, проверка строк перед
// отправкой (те же границы, что в 0003_sync.sql), JSON и разбор ошибок
// сервера.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/core/sync/data/supabase_sync_remote.dart';
import 'package:mater_studorium/core/sync/domain/sync_store.dart';
import 'package:mater_studorium/core/sync/domain/sync_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/sync_fixtures.dart';

void main() {
  group('decideMerge', () {
    final server = syncState('i1', s0, reps: 2);

    test('локальной нет — серверная', () {
      expect(
        decideMerge(local: null, localDirty: false, server: server),
        MergeAction.takeServer,
      );
    });
    test('сервер новее — серверная, даже поверх dirty', () {
      final local = syncState('i1', s0.subtract(const Duration(seconds: 1)));
      expect(
        decideMerge(local: local, localDirty: true, server: server),
        MergeAction.takeServer,
      );
    });
    test('равное время — серверная (как на сервере)', () {
      expect(
        decideMerge(
          local: syncState('i1', s0, reps: 9),
          localDirty: true,
          server: server,
        ),
        MergeAction.takeServer,
      );
    });
    test('локальная новее: dirty остаётся, чистая помечается dirty', () {
      final local = syncState('i1', s0.add(const Duration(seconds: 1)));
      expect(
        decideMerge(local: local, localDirty: true, server: server),
        MergeAction.keepLocal,
      );
      expect(
        decideMerge(local: local, localDirty: false, server: server),
        MergeAction.keepLocalMarkDirty,
      );
    });
  });

  group('isValidStateForPush (границы как в CHECK user_item_state)', () {
    final ok = syncState('i1', s0);
    test('обычное состояние проходит', () {
      expect(isValidStateForPush(ok), isTrue);
    });
    for (final (name, bad) in [
      ('item_id вне формата', ok.copyWith(itemId: 'Bad Id')),
      ('item_id длиннее 128', ok.copyWith(itemId: 'a' * 129)),
      ('deck_id длиннее 64', ok.copyWith(deckId: 'a' * 65)),
      ('difficulty > 10', ok.copyWith(difficulty: 10.01)),
      ('difficulty NaN', ok.copyWith(difficulty: double.nan)),
      ('stability < 0', ok.copyWith(stability: -0.1)),
      ('stability бесконечна', ok.copyWith(stability: double.infinity)),
      ('lapses > reps', ok.copyWith(reps: 1, lapses: 2)),
      ('elapsed_days < 0', ok.copyWith(elapsedDays: -1)),
      ('due в 2200', ok.copyWith(due: DateTime.utc(2200))),
      ('due до 1970', ok.copyWith(due: DateTime.utc(1969, 12, 31))),
      ('updated_at в 2200', ok.copyWith(updatedAt: DateTime.utc(2200))),
      (
        'updated_at до 1970',
        ok.copyWith(updatedAt: DateTime.utc(1969, 12, 31, 23, 59, 59)),
      ),
      ('last_question_id вне формата', ok.copyWith(lastQuestionId: 'Q 1')),
    ]) {
      test('отклоняется: $name', () {
        expect(isValidStateForPush(bad), isFalse);
      });
    }
    test('границы включительно проходят', () {
      expect(
        isValidStateForPush(
          ok.copyWith(
            difficulty: 10,
            stability: 0,
            reps: 0,
            lapses: 0,
            due: DateTime.utc(1970),
            updatedAt: DateTime.utc(1970),
          ),
        ),
        isTrue,
      );
    });
  });

  group('normalizeLogForPush (границы как в CHECK review_logs)', () {
    final ok = syncLog('i1', s0);
    test('обычный лог не меняется', () {
      expect(normalizeLogForPush(ok), ok);
    });
    for (final (name, bad) in [
      ('id не uuid', ok.copyWith(id: 'log-1')),
      ('deck_version 0', ok.copyWith(deckVersion: 0)),
      ('llm_score > 1', ok.copyWith(llmScore: 1.01)),
      ('llm_score NaN', ok.copyWith(llmScore: double.nan)),
      ('question_id вне формата', ok.copyWith(questionId: 'Q')),
      ('reviewed_at в 2200', ok.copyWith(reviewedAt: DateTime.utc(2200))),
    ]) {
      test('отклоняется: $name', () {
        expect(normalizeLogForPush(bad), isNull);
      });
    }
    test('длительность зажимается в [0, сутки]', () {
      expect(normalizeLogForPush(ok.copyWith(durationMs: -5))!.durationMs, 0);
      expect(
        normalizeLogForPush(ok.copyWith(durationMs: 1 << 40))!.durationMs,
        kMaxDurationMs,
      );
    });
    test('текст ответа обрезается до 4000, суррогатная пара не рвётся', () {
      final emoji = '😀'; // две UTF-16 единицы
      final text = '${'a' * 3999}$emoji${'b' * 10}';
      final cut = normalizeLogForPush(ok.copyWith(answerText: text))!;
      expect(cut.answerText, 'a' * 3999);
      final plain = normalizeLogForPush(ok.copyWith(answerText: 'x' * 4500))!;
      expect(plain.answerText!.length, kMaxAnswerTextLength);
    });
  });

  group('sanitizeAnswerText (ревью T17, S1)', () {
    test('энкодер UTF-8 Dart заменяет непарный суррогат на U+FFFD (на этом '
        'держится очистка)', () {
      expect(utf8.decode(utf8.encode('\uD800')), '�');
      expect(utf8.decode(utf8.encode('\uDC00x')), '�x');
      expect(utf8.decode(utf8.encode('😀')), '😀', reason: 'пара не трогается');
    });
    test('\\u0000 убирается, непарные суррогаты — U+FFFD, обычный текст как '
        'есть', () {
      expect(sanitizeAnswerText('a\u0000b\u0000'), 'ab');
      expect(sanitizeAnswerText('x\uD800y\uDC00'), 'x�y�');
      expect(sanitizeAnswerText('Привет 😀'), 'Привет 😀');
      expect(sanitizeAnswerText(null), isNull);
    });
    test('normalizeLogForPush очищает текст; JSON без NUL и без экранированных '
        'суррогатов', () {
      final log = normalizeLogForPush(
        syncLog('i1', s0).copyWith(answerText: 'a\u0000\uD83Db'),
      )!;
      expect(log.answerText, 'a�b');
      final json = jsonEncode(logToJson(log));
      expect(json.contains(r'\u0000'), isFalse);
      expect(json.toLowerCase().contains(r'\ud8'), isFalse);
    });
  });

  group('JSON для RPC', () {
    test('состояние: туда и обратно без потерь, без user_id', () {
      final s = syncState('i1', s0, reps: 3).copyWith(lastReview: null);
      final json = stateToJson(s);
      expect(json.containsKey('user_id'), isFalse);
      expect(json['updated_at'], '2026-10-12T10:00:00.000Z');
      expect(stateFromJson({...json, 'user_id': userA, 'sync_seq': 1}), s);
    });
    test('лог: туда и обратно без потерь, без user_id', () {
      final l = syncLog('i1', s0).copyWith(llmScore: 0.5, answerText: 'да');
      final json = logToJson(l);
      expect(json.containsKey('user_id'), isFalse);
      expect(logFromJson(json), l);
    });
    test('серверное время со смещением пояса разбирается в UTC', () {
      final s = stateFromJson({
        ...stateToJson(syncState('i1', s0)),
        'updated_at': '2026-10-12T13:00:00+03:00',
      });
      expect(s.updatedAt, s0);
      expect(s.updatedAt.isUtc, isTrue);
    });
    test('строка неожиданной формы — UnexpectedError', () {
      expect(
        () => stateFromJson({'item_id': 1}),
        throwsA(isA<UnexpectedError>()),
      );
    });
  });

  group('mapSyncRemoteError', () {
    PostgrestException pg(String code) =>
        PostgrestException(message: 'm', code: code);

    test('сеть и таймаут — NetworkError', () {
      expect(mapSyncRemoteError(TimeoutException('t')), isA<NetworkError>());
      expect(
        mapSyncRemoteError(http.ClientException('x')),
        isA<NetworkError>(),
      );
      expect(mapSyncRemoteError(pg('503')), isA<NetworkError>());
      expect(mapSyncRemoteError(pg('429')), isA<NetworkError>());
      expect(
        mapSyncRemoteError(pg('55P03')),
        isA<NetworkError>(),
        reason: 'lock_timeout: временное',
      );
    });
    test('доступ — AuthError', () {
      for (final code in ['42501', '401', '403', 'PGRST301']) {
        expect(mapSyncRemoteError(pg(code)), isA<AuthError>(), reason: code);
      }
    });
    test('неверный пакет — SyncRejectedError', () {
      for (final code in [
        '23514',
        '23502',
        '22P02',
        '22023',
        '22P05',
        '54000',
        'PGRST102',
        '400',
        '413',
      ]) {
        expect(
          mapSyncRemoteError(pg(code)),
          isA<SyncRejectedError>(),
          reason: code,
        );
      }
    });
    test('прочее — UnexpectedError', () {
      expect(mapSyncRemoteError(pg('PGRST202')), isA<UnexpectedError>());
      expect(mapSyncRemoteError(StateError('x')), isA<UnexpectedError>());
    });
  });
}
