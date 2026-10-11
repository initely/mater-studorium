import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mater_studorium/features/catalog/domain/deck.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/catalog/domain/review.dart';

import '../../../helpers/deck_fixtures.dart';

/// toJson через encode/decode — как при записи в файл.
Map<String, dynamic> _wire(Deck deck) =>
    jsonDecode(jsonEncode(deck.toJson())) as Map<String, dynamic>;

void main() {
  group('round-trip', () {
    test('sample.json → модели → JSON без потерь', () {
      final original = readJsonFile(sampleDeckPath);
      final deck = Deck.fromJson(original);

      expect(_wire(deck), equals(original));
      expect(Deck.fromJson(_wire(deck)), deck);
    });

    test('good.json: необязательные поля получают умолчания', () {
      final deck = Deck.fromJson(readJsonFile(goodDeckPath));
      final itemB = deck.items[1];

      expect(itemB.tags, isEmpty);
      expect(deck.items[2].refs.first.quoteUnverifiable, isFalse);
      expect(itemB.refs.first.quoteUnverifiable, isTrue);
      expect(itemB.review.notes, isNull);
      expect(Deck.fromJson(_wire(deck)), deck);
    });
  });

  test('sample.json покрывает все 6 типов, type совпадает с payload', () {
    final deck = Deck.fromJson(readJsonFile(sampleDeckPath));
    final questions = [for (final i in deck.items) ...i.questions];

    expect(deck.schemaVersion, kDeckSchemaVersion);
    expect(deck.items, hasLength(3));
    expect(questions.map((q) => q.type).toSet(), QuestionType.values.toSet());
    for (final q in questions) {
      expect(q.payload.type, q.type, reason: q.id);
    }
  });

  test('payload разбирается в типизированные варианты', () {
    final deck = Deck.fromJson(readJsonFile(goodDeckPath));
    final [mcq, open] = deck.items[0].questions;
    final [cloze, order] = deck.items[1].questions;
    final [flip, findError] = deck.items[2].questions;

    expect(
      mcq.payload,
      isA<McqPayload>()
          .having((p) => p.correct, 'correct', ['a', 'c'])
          .having((p) => p.multiple, 'multiple', isTrue),
    );
    expect(open.explanationShort, 'Переопределённый разбор.');
    expect(
      open.payload,
      isA<OpenPayload>().having(
        (p) => p.rubric.first,
        'rubric[0]',
        const RubricPoint(id: 'p1', text: 'Пункт 1', weight: 3, required: true),
      ),
    );
    expect(
      cloze.payload,
      isA<ClozePayload>().having((p) => p.blanks.map((b) => b.id), 'ids', [
        'x',
        'y_2',
      ]),
    );
    expect(order.payload, isA<OrderPayload>());
    expect(flip.payload, const FlipPayload(back: 'Оборот.'));
    expect(
      findError.payload,
      isA<FindErrorPayload>()
          .having((p) => p.mode, 'mode', FindErrorMode.text)
          .having((p) => p.errorLines, 'errorLines', [2, 4])
          .having((p) => p.lineExplanations[4], 'line 4', 'Потому что 4.'),
    );
    expect(deck.items[0].review.status, ReviewStatus.approved);
  });

  group('Question JSON', () {
    test('type на уровне вопроса, в payload его нет', () {
      final question = Question(
        id: 't.q',
        type: QuestionType.findError,
        prompt: 'P',
        payload: const QuestionPayload.findError(
          mode: FindErrorMode.code,
          lines: ['a', 'b'],
          errorLines: [1],
          lineExplanations: {1: 'x'},
        ),
      );
      final json = question.toJson();

      expect(json['type'], 'find_error');
      expect(json['payload'], {
        'mode': 'code',
        'lines': ['a', 'b'],
        'error_lines': [1],
        'line_explanations': {'1': 'x'},
      });
      expect(Question.fromJson(json), question);
    });

    test('отдельный payload самоописывающий: содержит type', () {
      const payload = QuestionPayload.flip(back: 'B');
      final json = payload.toJson();

      expect(json, {'back': 'B', 'type': 'flip'});
      expect(QuestionPayload.fromJson(json), payload);
    });

    test('неизвестный type не разбирается', () {
      expect(
        () => Question.fromJson({
          'id': 't.q',
          'type': 'essay',
          'prompt': 'P',
          'payload': <String, dynamic>{},
        }),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => QuestionPayload.fromJson({'type': 'essay'}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('type и вариант payload обязаны совпадать', () {
      expect(
        () => Question(
          id: 't.q',
          type: QuestionType.mcq,
          prompt: 'P',
          payload: const QuestionPayload.flip(back: 'B'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('payload не того типа не разбирается', () {
      expect(
        () => Question.fromJson({
          'id': 't.q',
          'type': 'mcq',
          'prompt': 'P',
          'payload': {'back': 'B'},
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  test('колода без обязательного поля не разбирается', () {
    // Клиент (T10) ловит ошибку и оставляет старую версию (AC2.3).
    final json = readJsonFile(goodDeckPath)..remove('items');
    expect(() => Deck.fromJson(json), throwsA(isA<TypeError>()));
  });
}
