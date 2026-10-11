import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/payload_parts.dart';
import 'package:mater_studorium/features/catalog/domain/question.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/srs/domain/item_state.dart';
import 'package:mater_studorium/features/srs/domain/rating.dart';
import 'package:mater_studorium/features/srs/domain/scheduler.dart';
import 'package:mater_studorium/features/srs/domain/srs_state.dart';
import 'package:mater_studorium/features/srs/domain/variant_picker.dart';

final t0 = DateTime.utc(2026, 10, 11, 12);

QuestionPayload payloadFor(QuestionType type) => switch (type) {
  QuestionType.flip => const QuestionPayload.flip(back: 'b'),
  QuestionType.mcq => const QuestionPayload.mcq(
    options: [
      McqOption(id: 'a', text: 'a'),
      McqOption(id: 'b', text: 'b'),
    ],
    correct: ['a'],
    multiple: false,
  ),
  QuestionType.open => const QuestionPayload.open(
    referenceAnswer: 'r',
    rubric: [
      RubricPoint(id: 'p1', text: 't', weight: 1, required: true),
      RubricPoint(id: 'p2', text: 't', weight: 1, required: false),
    ],
  ),
  QuestionType.cloze => const QuestionPayload.cloze(
    blanks: [
      ClozeBlank(id: '1', accepted: ['x']),
    ],
  ),
  QuestionType.order => const QuestionPayload.order(
    steps: [
      OrderStep(id: 's1', text: '1'),
      OrderStep(id: 's2', text: '2'),
      OrderStep(id: 's3', text: '3'),
    ],
  ),
  QuestionType.findError => const QuestionPayload.findError(
    mode: FindErrorMode.text,
    lines: ['a', 'b'],
    errorLines: [1],
    lineExplanations: {1: 'e'},
  ),
};

Question q(String id, QuestionType type) =>
    Question(id: id, type: type, prompt: 'p', payload: payloadFor(type));

final flip = q('i.flip', QuestionType.flip);
final mcq = q('i.mcq', QuestionType.mcq);
final mcq2 = q('i.mcq2', QuestionType.mcq);
final open = q('i.open', QuestionType.open);
final cloze = q('i.cloze', QuestionType.cloze);
final order = q('i.order', QuestionType.order);

ItemState seen({double stability = 10, String? lastQuestionId}) => ItemState(
  itemId: 'i',
  deckId: 'd',
  due: t0,
  stability: stability,
  difficulty: 5,
  elapsedDays: 0,
  scheduledDays: 1,
  reps: 3,
  lapses: 0,
  state: SrsState.review,
  lastReview: t0,
  lastQuestionId: lastQuestionId,
  updatedAt: t0,
);

/// Всегда выбирает первый из равных — чтобы проверять правила без случая.
class FirstRandom implements math.Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

final picker = VariantPicker(FirstRandom());

Question? pick(
  List<Question> questions, {
  ItemState? state,
  Set<String> hidden = const {},
  Map<String, DateTime> shown = const {},
  VariantPicker? using,
}) => (using ?? picker).pick(
  questions: questions,
  state: state,
  hiddenQuestionIds: hidden,
  lastShownAt: shown,
);

void main() {
  group('скрытые и единственный вариант', () {
    test('нет вопросов или все скрыты — null, без исключения', () {
      expect(pick([]), isNull);
      expect(pick([flip, mcq], hidden: {flip.id, mcq.id}), isNull);
    });

    test('вариант один — берём его, даже open при S < 3', () {
      expect(pick([open]), open);
      expect(pick([open], state: seen(stability: 0.5)), open);
      expect(pick([flip, open], hidden: {flip.id}), open);
    });

    test('скрытый не выбирается никогда', () {
      expect(pick([flip, mcq, cloze], hidden: {flip.id}), mcq);
      final s = seen(lastQuestionId: mcq.id);
      expect(pick([flip, mcq, cloze], state: s, hidden: {flip.id}), cloze);
    });
  });

  group('первый показ: flip → mcq → любой', () {
    test('есть flip — flip', () {
      expect(pick([open, mcq, flip]), flip);
    });

    test('нет flip — mcq', () {
      expect(pick([cloze, open, mcq]), mcq);
    });

    test('ни flip, ни mcq — любой, кроме open', () {
      expect(pick([open, cloze, order]), cloze);
      expect(pick([open, order, cloze]), order);
    });

    test('только open — фолбэк на open', () {
      expect(pick([open, q('i.open2', QuestionType.open)]), open);
    });

    test('state = newCard — тоже первый показ', () {
      final s = Scheduler.initialState(itemId: 'i', deckId: 'd', now: t0);
      expect(pick([mcq, flip], state: s), flip);
    });

    test('несколько flip — выбор через переданный Random', () {
      final flip2 = q('i.flip2', QuestionType.flip);
      final picks = {
        for (var seed = 0; seed < 20; seed++)
          pick([flip, flip2, mcq], using: VariantPicker(math.Random(seed))),
      };
      expect(picks, {flip, flip2});
    });
  });

  group('без open при S < 3 дней', () {
    test('S < 3 — open пропускается, даже если давно не показан', () {
      final s = seen(stability: 2.99, lastQuestionId: flip.id);
      expect(pick([flip, open, mcq], state: s, shown: {mcq.id: t0}), mcq);
    });

    test('S ≥ 3 — open разрешён', () {
      final s = seen(stability: 3, lastQuestionId: flip.id);
      expect(pick([flip, open, mcq], state: s, shown: {mcq.id: t0}), open);
    });

    test('S < 3 и кроме open только прошлый тип — прошлый тип, не open', () {
      final s = seen(stability: 1, lastQuestionId: flip.id);
      expect(pick([flip, open], state: s), flip);
    });
  });

  group('повторный показ: другой тип, давно не показанный', () {
    test('тип отличается от прошлого показа', () {
      final s = seen(lastQuestionId: mcq.id);
      expect(pick([mcq, mcq2, flip], state: s), flip);
    });

    test('из подходящих — ни разу не показанный', () {
      final s = seen(lastQuestionId: flip.id);
      final shown = {flip.id: t0, mcq.id: t0.subtract(const Duration(days: 9))};
      expect(pick([flip, mcq, cloze], state: s, shown: shown), cloze);
    });

    test('все показаны — самый давний', () {
      final s = seen(lastQuestionId: flip.id);
      final shown = {
        flip.id: t0,
        mcq.id: t0.subtract(const Duration(days: 2)),
        cloze.id: t0.subtract(const Duration(days: 9)),
        order.id: t0.subtract(const Duration(days: 5)),
      };
      expect(pick([flip, mcq, cloze, order], state: s, shown: shown), cloze);
    });

    test('равные даты — разбивает Random', () {
      final s = seen(lastQuestionId: flip.id);
      final day = t0.subtract(const Duration(days: 3));
      final shown = {flip.id: t0, mcq.id: day, cloze.id: day};
      final picks = {
        for (var seed = 0; seed < 20; seed++)
          pick(
            [flip, mcq, cloze],
            state: s,
            shown: shown,
            using: VariantPicker(math.Random(seed)),
          ),
      };
      expect(picks, {mcq, cloze});
    });

    test('все одного типа с прошлым — фолбэк: самый давний того же типа', () {
      final s = seen(lastQuestionId: mcq.id);
      final shown = {mcq.id: t0, mcq2.id: t0.subtract(const Duration(days: 1))};
      expect(pick([mcq, mcq2], state: s, shown: shown), mcq2);
    });

    test('прошлый вопрос удалён из колоды — ограничения по типу нет', () {
      final s = seen(lastQuestionId: 'i.gone');
      final shown = {flip.id: t0.subtract(const Duration(days: 1)), mcq.id: t0};
      expect(pick([mcq, flip], state: s, shown: shown), flip);
    });

    test('прошлый вопрос скрыт — его тип всё равно избегается', () {
      final s = seen(lastQuestionId: mcq.id);
      expect(pick([mcq, mcq2, flip], state: s, hidden: {mcq.id}), flip);
    });
  });

  test('AC7.2: знание показывается разными вариантами по очереди', () {
    // Знание с тремя вариантами проходит 6 повторений: каждый раз
    // планируется само знание, а вопрос выбирается из его вариантов.
    const scheduler = Scheduler();
    final questions = [flip, mcq, open];
    var state = Scheduler.initialState(itemId: 'i', deckId: 'd', now: t0);
    var now = t0;
    final shown = <String, DateTime>{};
    final types = <QuestionType>[];
    for (var i = 0; i < 6; i++) {
      final chosen = pick(questions, state: state, shown: shown)!;
      types.add(chosen.type);
      shown[chosen.id] = now;
      state = scheduler
          .review(state, Rating.good, now)
          .copyWith(lastQuestionId: chosen.id);
      expect(state.itemId, 'i');
      now = state.due;
    }
    expect(types.first, QuestionType.flip);
    for (var i = 1; i < types.length; i++) {
      expect(types[i], isNot(types[i - 1]), reason: '$types');
    }
    expect(types.toSet(), {
      QuestionType.flip,
      QuestionType.mcq,
      QuestionType.open,
    });
  });
}
