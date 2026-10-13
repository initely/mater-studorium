import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/core/errors/app_error.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/duel/domain/duel_question_picker.dart';

DuelCandidate _c(String q, String item) =>
    DuelCandidate(questionId: q, itemId: item);

void main() {
  test('в дуэли 5 вопросов; в MVP-a допустим только mcq (константа)', () {
    expect(kDuelQuestionCount, 5);
    expect(kDuelQuestionTypes, {QuestionType.mcq});
  });

  test('берёт ровно 5 разных вопросов', () {
    final picked = pickDuelQuestions([
      for (var i = 1; i <= 12; i++) _c('q.$i', 'item.$i'),
    ], Random(1));
    expect(picked, hasLength(5));
    expect(picked.toSet(), hasLength(5));
  });

  test('по возможности из разных знаний', () {
    // Три варианта у каждого из пяти знаний: в выбор попадает по одному.
    final candidates = [
      for (var item = 1; item <= 5; item++)
        for (var v = 1; v <= 3; v++) _c('q.$item.$v', 'item.$item'),
    ];
    for (var seed = 0; seed < 20; seed++) {
      final picked = pickDuelQuestions(candidates, Random(seed));
      final items = picked.map((q) => q.split('.')[1]).toSet();
      expect(items, hasLength(5), reason: 'seed $seed: $picked');
    }
  });

  test('знаний меньше пяти — добирает вторыми вариантами', () {
    final candidates = [
      _c('a.1', 'a'),
      _c('a.2', 'a'),
      _c('b.1', 'b'),
      _c('b.2', 'b'),
      _c('c.1', 'c'),
      _c('c.2', 'c'),
    ];
    final picked = pickDuelQuestions(candidates, Random(3));
    expect(picked, hasLength(5));
    expect(picked.toSet(), hasLength(5));
    expect(picked.map((q) => q.split('.').first).toSet(), {'a', 'b', 'c'});
  });

  test('меньше пяти вопросов — DuelNotEnoughQuestionsError', () {
    expect(
      () => pickDuelQuestions([
        for (var i = 1; i <= 4; i++) _c('q.$i', 'i.$i'),
      ], Random(1)),
      throwsA(
        isA<DuelNotEnoughQuestionsError>().having(
          (e) => e.available,
          'available',
          4,
        ),
      ),
    );
    expect(
      () => pickDuelQuestions(const [], Random(1)),
      throwsA(isA<DuelNotEnoughQuestionsError>()),
    );
  });

  test('ровно пять вопросов — берутся все, порядок случайный', () {
    final candidates = [for (var i = 1; i <= 5; i++) _c('q.$i', 'i.$i')];
    final orders = {
      for (var seed = 0; seed < 30; seed++)
        pickDuelQuestions(candidates, Random(seed)).join(','),
    };
    expect(orders.length, greaterThan(1));
    for (final order in orders) {
      expect(order.split(',').toSet(), {'q.1', 'q.2', 'q.3', 'q.4', 'q.5'});
    }
  });

  test('с одним seed выбор повторяется', () {
    final candidates = [for (var i = 1; i <= 20; i++) _c('q.$i', 'i.$i')];
    expect(
      pickDuelQuestions(candidates, Random(7)),
      pickDuelQuestions(candidates, Random(7)),
    );
  });
}
