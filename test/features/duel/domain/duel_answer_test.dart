// Ответ дуэли (T23, ADR-36): тело RPC и записи outbox, разбор, размер по
// правилам сервера (CHECK `duel_answers`, `octet_length(answer::text)`).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer_validator.dart';
import 'package:mater_studorium/features/duel/domain/duel_limits.dart';

import '../../../helpers/duel_fixtures.dart';

DuelAnswerPayload _answer({
  String duelId = kDuelId,
  String questionId = 'duel-deck.1.q1',
  Map<String, Object?> answer = const {
    'selected': ['a'],
  },
  bool isCorrect = true,
  int durationMs = 1500,
}) => DuelAnswerPayload(
  duelId: duelId,
  questionId: questionId,
  answer: answer,
  isCorrect: isCorrect,
  durationMs: durationMs,
);

void main() {
  group('DuelAnswerPayload', () {
    test('toJson и tryParse: круг сохраняет все поля', () {
      final a = _answer();
      final back = DuelAnswerPayload.tryParse(
        jsonDecode(jsonEncode(a.toJson())),
      )!;
      expect(back.duelId, kDuelId);
      expect(back.questionId, 'duel-deck.1.q1');
      expect(back.answer, {
        'selected': ['a'],
      });
      expect(back.isCorrect, isTrue);
      expect(back.durationMs, 1500);
    });

    test('tryParse: не та форма — null (запись «ядовитая»)', () {
      for (final bad in <Object?>[
        null,
        'строка',
        <Object?>[],
        <String, Object?>{},
        {'duel_id': 1},
        {...(_answer().toJson()), 'answer': 'не объект'},
        {...(_answer().toJson()), 'is_correct': 'да'},
        {...(_answer().toJson()), 'duration_ms': 1.5},
        {...(_answer().toJson())}..remove('question_id'),
      ]) {
        expect(DuelAnswerPayload.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('пропуск: неверно, время 0, ответ {"skipped": true}', () {
      final s = DuelAnswerPayload.skipped(duelId: kDuelId, questionId: 'q.1');
      expect(s.isCorrect, isFalse);
      expect(s.durationMs, 0);
      expect(s.answer, {'skipped': true});
      expect(isValidDuelAnswerPayload(s), isTrue);
    });
  });

  group('DuelAnswerRecord', () {
    test('selectedOptionIds: выбранные варианты mcq', () {
      expect(record('q', selected: ['a', 'c']).selectedOptionIds, ['a', 'c']);
    });

    test('чужая форма ответа не роняет: пустой список', () {
      for (final answer in <Object?>[
        null,
        'x',
        <Object?>[],
        {'selected': 'a'},
        {'other': 1},
      ]) {
        final r = DuelAnswerRecord(
          questionId: 'q',
          answer: answer,
          isCorrect: true,
          durationMs: 1,
        );
        expect(r.selectedOptionIds, isEmpty, reason: '$answer');
        expect(r.wasSkipped, isFalse);
      }
    });

    test('в списке выбранных остаются только строки', () {
      final r = const DuelAnswerRecord(
        questionId: 'q',
        answer: {
          'selected': ['a', 1, null, 'b'],
        },
        isCorrect: false,
        durationMs: 1,
      );
      expect(r.selectedOptionIds, ['a', 'b']);
    });

    test('wasSkipped только при skipped == true', () {
      DuelAnswerRecord r(Object? a) => DuelAnswerRecord(
        questionId: 'q',
        answer: a,
        isCorrect: false,
        durationMs: 0,
      );
      expect(r({'skipped': true}).wasSkipped, isTrue);
      expect(r({'skipped': false}).wasSkipped, isFalse);
      expect(r({'skipped': 'да'}).wasSkipped, isFalse);
    });
  });

  group('jsonbTextBytes: размер как у сервера', () {
    test('jsonb ставит пробел после «:» и «,»', () {
      expect(jsonbTextBytes({'a': 1}), utf8.encode('{"a": 1}').length);
      expect(jsonbTextBytes([1, 2]), utf8.encode('[1, 2]').length);
      expect(
        jsonbTextBytes({
          'selected': ['a', 'b'],
        }),
        utf8.encode('{"selected": ["a", "b"]}').length,
      );
    });

    test('граница pgTAP: 503 знака в значении — ровно 512 байт', () {
      expect(jsonbTextBytes({'x': 'a' * 503}), 512);
      expect(jsonbTextBytes({'x': 'a' * 504}), 513);
    });

    test('считаются байты UTF-8, а не знаки', () {
      expect(jsonbTextBytes({'x': 'я' * 300}), 7 + 600 + 2);
    });

    test('кавычки и обратные слэши экранируются, как в jsonb', () {
      expect(jsonbTextBytes('a"b\\'), utf8.encode(r'"a\"b\\"').length);
    });

    test('короче компактного jsonEncode не бывает', () {
      final v = {
        'selected': ['a', 'b', 'c'],
        'n': 1,
      };
      expect(jsonbTextBytes(v), greaterThan(utf8.encode(jsonEncode(v)).length));
    });
  });

  group('isValidDuelAnswerPayload', () {
    test('обычный ответ mcq', () {
      expect(isValidDuelAnswerPayload(_answer()), isTrue);
    });

    test('худший mcq: 8 вариантов по 32 знака укладываются в 512 байт', () {
      final ids = [for (var i = 0; i < 8; i++) '${'x' * 31}$i'];
      final a = _answer(answer: {'selected': ids});
      expect(jsonbTextBytes(a.answer), lessThan(kDuelAnswerMaxBytes));
      expect(isValidDuelAnswerPayload(a), isTrue);
    });

    test('ответ 512 байт проходит, 513 — нет', () {
      expect(
        isValidDuelAnswerPayload(_answer(answer: {'x': 'a' * 503})),
        isTrue,
      );
      expect(
        isValidDuelAnswerPayload(_answer(answer: {'x': 'a' * 504})),
        isFalse,
      );
    });

    test('время: 0 и сутки проходят, -1 и сутки + 1 мс — нет', () {
      expect(isValidDuelAnswerPayload(_answer(durationMs: 0)), isTrue);
      expect(
        isValidDuelAnswerPayload(_answer(durationMs: kDuelMaxDurationMs)),
        isTrue,
      );
      expect(isValidDuelAnswerPayload(_answer(durationMs: -1)), isFalse);
      expect(
        isValidDuelAnswerPayload(_answer(durationMs: kDuelMaxDurationMs + 1)),
        isFalse,
      );
    });

    test('id вопроса: формат колоды и не длиннее 128', () {
      expect(
        isValidDuelAnswerPayload(_answer(questionId: 'a${'b' * 127}')),
        isTrue,
      );
      expect(
        isValidDuelAnswerPayload(_answer(questionId: 'a${'b' * 128}')),
        isFalse,
      );
      for (final bad in ['', 'Q 1', 'q..1', '.q', 'q.', 'Привет']) {
        expect(
          isValidDuelAnswerPayload(_answer(questionId: bad)),
          isFalse,
          reason: bad,
        );
      }
    });

    test('id дуэли: только uuid', () {
      expect(isValidDuelAnswerPayload(_answer(duelId: 'duel-1')), isFalse);
      expect(isValidDuelAnswerPayload(_answer(duelId: '')), isFalse);
    });
  });
}
