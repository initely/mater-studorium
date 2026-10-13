// Итог дуэли (ТЗ M10): больше верных, при равенстве меньшее время; строки
// экрана результата; слоты набора вопросов; стадии дуэли; формат времени.
import 'package:flutter_test/flutter_test.dart';
import 'package:mater_studorium/features/catalog/domain/question_payload.dart';
import 'package:mater_studorium/features/catalog/domain/question_type.dart';
import 'package:mater_studorium/features/duel/domain/duel_answer.dart';
import 'package:mater_studorium/features/duel/domain/duel_content.dart';
import 'package:mater_studorium/features/duel/domain/duel_result.dart';
import 'package:mater_studorium/features/duel/domain/duel_stage.dart';
import 'package:mater_studorium/features/duel/domain/duel_status.dart';
import 'package:mater_studorium/features/duel/presentation/format_duel_time.dart';

import '../../../helpers/duel_fixtures.dart';
import '../../../helpers/fake_duel_repository.dart';

final _ids = duelQuestionIds();

List<DuelAnswerRecord> _answers(List<bool> correct, {int ms = 1000}) => [
  for (var i = 0; i < correct.length; i++)
    record(_ids[i], correct: correct[i], ms: ms),
];

void main() {
  group('computeDuelResult', () {
    DuelOutcome outcome(
      List<DuelAnswerRecord> mine,
      List<DuelAnswerRecord> other,
    ) => computeDuelResult(questionIds: _ids, mine: mine, other: other).outcome;

    test('больше верных — победа, меньше — поражение', () {
      final three = _answers([true, true, true, false, false]);
      final two = _answers([true, true, false, false, false]);
      expect(outcome(three, two), DuelOutcome.won);
      expect(outcome(two, three), DuelOutcome.lost);
    });

    test('верных поровну: меньшее суммарное время побеждает', () {
      final fast = _answers([true, true, false, false, false], ms: 1000);
      final slow = _answers([true, true, false, false, false], ms: 1500);
      expect(outcome(fast, slow), DuelOutcome.won);
      expect(outcome(slow, fast), DuelOutcome.lost);
    });

    test('верных больше, но время хуже: всё равно победа (время вторично)', () {
      final moreButSlow = _answers([true, true, true, true, true], ms: 9000);
      final fewButFast = _answers([true, false, false, false, false], ms: 10);
      expect(outcome(moreButSlow, fewButFast), DuelOutcome.won);
    });

    test('поровну верных и времени — ничья', () {
      final a = _answers([true, false, true, false, true]);
      expect(outcome(a, a), DuelOutcome.draw);
    });

    test('счёт и время считаются по набору', () {
      final r = computeDuelResult(
        questionIds: _ids,
        mine: _answers([true, true, false, false, false], ms: 700),
        other: _answers([true, false, false, false, false], ms: 900),
      );
      expect((r.mine.correct, r.mine.totalMs), (2, 3500));
      expect((r.other.correct, r.other.totalMs), (1, 4500));
    });

    test('ответы на вопросы вне набора и дубли не считаются', () {
      final r = computeDuelResult(
        questionIds: _ids,
        mine: [
          record(_ids[0], ms: 100),
          record(_ids[0], ms: 100000),
          record('чужой.q', ms: 5000),
        ],
        other: const [],
      );
      expect((r.mine.correct, r.mine.totalMs), (1, 100));
    });

    test('нет ответа на вопрос: неверно, времени ноль', () {
      final r = computeDuelResult(
        questionIds: _ids,
        mine: _answers([true, true, true, true, true]),
        other: _answers([true]),
      );
      expect(r.other.correct, 1);
      expect(r.outcome, DuelOutcome.won);
    });
  });

  group('buildDuelResult', () {
    test('строки по порядку набора: вопрос, свой и чужой ответ', () {
      final data = buildDuelResult(
        duel: playDuel(status: DuelStatus.finished),
        content: contentOf(missing: {_ids[2]}),
        answers: DuelAnswers(
          mine: _answers([true, false, true, true, true]),
          other: _answers([false, false, false, false, true]),
        ),
      );
      expect([for (final r in data.rows) r.questionId], _ids);
      expect(data.rows[0].content!.question.id, _ids[0]);
      expect(data.rows[2].content, isNull, reason: 'вопрос недоступен');
      expect(data.rows[1].mine!.isCorrect, isFalse);
      expect(data.rows[4].other!.isCorrect, isTrue);
      expect(data.result.outcome, DuelOutcome.won);
    });

    test('колоды нет: строки без содержимого', () {
      final data = buildDuelResult(
        duel: playDuel(status: DuelStatus.finished),
        content: null,
        answers: const DuelAnswers(mine: [], other: []),
      );
      expect(data.rows.every((r) => r.content == null), isTrue);
      expect(data.rows.every((r) => r.mine == null), isTrue);
    });
  });

  group('resolveDuelSlots (ADR-36)', () {
    final supported = {QuestionType.mcq};

    test('все вопросы есть и автопроверяемые: все годны', () {
      final slots = resolveDuelSlots(
        _ids,
        contentOf(),
        supportedTypes: supported,
      );
      expect(slots.every((s) => s.isPlayable), isTrue);
      expect([for (final s in slots) s.questionId], _ids);
    });

    test('вопроса нет в локальной колоде: недоступен', () {
      final slots = resolveDuelSlots(
        [..._ids.take(4), 'нет.такого'],
        contentOf(),
        supportedTypes: supported,
      );
      expect(slots.map((s) => s.isPlayable), [true, true, true, true, false]);
    });

    test('формат без модуля в реестре: недоступен', () {
      final slots = resolveDuelSlots(
        _ids,
        contentOf(),
        supportedTypes: const {},
      );
      expect(slots.every((s) => !s.isPlayable), isTrue);
    });

    test('не автопроверяемый формат (flip) недоступен, даже если известен', () {
      final base = contentOf();
      final flip = DuelQuestionContent(
        question: base.questions[_ids[0]]!.question.copyWith(
          type: QuestionType.flip,
          payload: const QuestionPayload.flip(back: 'оборот'),
        ),
        item: base.questions[_ids[0]]!.item,
      );
      final content = DuelContent(
        deckVersion: 2,
        questions: {...base.questions, _ids[0]: flip},
      );
      final slots = resolveDuelSlots(
        _ids,
        content,
        supportedTypes: {QuestionType.mcq, QuestionType.flip},
      );
      expect(slots[0].isPlayable, isFalse);
      expect(slots[1].isPlayable, isTrue);
    });
  });

  group('duelStageFor', () {
    final open = playDuel(status: DuelStatus.open, otherJoined: false);

    test('твой ход, пока я не ответил на все', () {
      expect(duelStageFor(open, DuelStatus.open), DuelStage.yourTurn);
      expect(duelStageFor(playDuel(), DuelStatus.active), DuelStage.yourTurn);
    });

    test('ждём: я закончил на сервере или локально', () {
      expect(
        duelStageFor(playDuel(myDoneAt: duelNow), DuelStatus.active),
        DuelStage.waiting,
      );
      expect(
        duelStageFor(open, DuelStatus.open, localDone: true),
        DuelStage.waiting,
      );
    });

    test('результат и истекла следуют статусу', () {
      expect(duelStageFor(playDuel(), DuelStatus.finished), DuelStage.result);
      expect(
        duelStageFor(playDuel(myDoneAt: duelNow), DuelStatus.expired),
        DuelStage.expired,
      );
    });
  });

  test('formatDuelTime: м:сс и ч:мм:сс', () {
    expect(formatDuelTime(0), '0:00');
    expect(formatDuelTime(999), '0:00');
    expect(formatDuelTime(7000), '0:07');
    expect(formatDuelTime(65000), '1:05');
    expect(formatDuelTime(754000), '12:34');
    expect(formatDuelTime(3600000), '1:00:00');
    expect(formatDuelTime(-5), '0:00');
  });
}
