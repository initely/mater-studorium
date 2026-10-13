import 'duel.dart';
import 'duel_answer.dart';
import 'duel_content.dart';

/// Исход дуэли для одного из участников.
enum DuelOutcome { won, lost, draw }

/// Итог одного участника: верные ответы и суммарное время.
class DuelSideScore {
  const DuelSideScore({required this.correct, required this.totalMs});

  final int correct;
  final int totalMs;
}

/// Итог дуэли (ТЗ M10): побеждает больше верных, при равенстве меньшее
/// суммарное время; равное время — ничья.
class DuelResult {
  const DuelResult({
    required this.mine,
    required this.other,
    required this.outcome,
  });

  final DuelSideScore mine;
  final DuelSideScore other;
  final DuelOutcome outcome;
}

DuelSideScore _score(List<String> questionIds, List<DuelAnswerRecord> answers) {
  final byQuestion = <String, DuelAnswerRecord>{};
  for (final a in answers) {
    // Только вопросы набора и по одному ответу на вопрос.
    if (questionIds.contains(a.questionId)) {
      byQuestion.putIfAbsent(a.questionId, () => a);
    }
  }
  var correct = 0;
  var totalMs = 0;
  for (final a in byQuestion.values) {
    if (a.isCorrect) correct++;
    totalMs += a.durationMs;
  }
  return DuelSideScore(correct: correct, totalMs: totalMs);
}

/// Считает итог по ответам [mine] и [other] на вопросы набора [questionIds].
/// Без ответа на вопрос он неверен и времени не даёт.
DuelResult computeDuelResult({
  required List<String> questionIds,
  required List<DuelAnswerRecord> mine,
  required List<DuelAnswerRecord> other,
}) {
  final m = _score(questionIds, mine);
  final o = _score(questionIds, other);
  final outcome = m.correct != o.correct
      ? (m.correct > o.correct ? DuelOutcome.won : DuelOutcome.lost)
      : m.totalMs != o.totalMs
      ? (m.totalMs < o.totalMs ? DuelOutcome.won : DuelOutcome.lost)
      : DuelOutcome.draw;
  return DuelResult(mine: m, other: o, outcome: outcome);
}

/// Одна строка экрана результата: вопрос и оба ответа.
class DuelResultRow {
  const DuelResultRow({
    required this.questionId,
    this.content,
    this.mine,
    this.other,
  });

  final String questionId;

  /// Вопрос из локальной колоды; `null` — недоступен на этом устройстве
  /// (нет в колоде, не автопроверяемый, скрыт жалобой).
  final DuelQuestionContent? content;
  final DuelAnswerRecord? mine;
  final DuelAnswerRecord? other;
}

/// Всё для экрана результата завершённой дуэли.
class DuelResultData {
  const DuelResultData({
    required this.duel,
    required this.result,
    required this.rows,
  });

  final Duel duel;
  final DuelResult result;

  /// По вопросам набора, в порядке набора.
  final List<DuelResultRow> rows;
}

/// Собирает [DuelResultData]: [content] может быть `null` (колоды нет).
DuelResultData buildDuelResult({
  required Duel duel,
  required DuelContent? content,
  required DuelAnswers answers,
}) {
  DuelAnswerRecord? find(List<DuelAnswerRecord> list, String id) {
    for (final a in list) {
      if (a.questionId == id) return a;
    }
    return null;
  }

  return DuelResultData(
    duel: duel,
    result: computeDuelResult(
      questionIds: duel.questionIds,
      mine: answers.mine,
      other: answers.other,
    ),
    rows: [
      for (final id in duel.questionIds)
        DuelResultRow(
          questionId: id,
          content: content?.questions[id],
          mine: find(answers.mine, id),
          other: find(answers.other, id),
        ),
    ],
  );
}
