import '../../catalog/domain/question_payload.dart';
import '../../srs/domain/answer_outcome.dart';

/// Результат проверки `mcq` (ТЗ §4.3, M4): итог и разбор по вариантам для
/// подсветки.
class McqGrade {
  const McqGrade({
    required this.outcome,
    required this.correctSelected,
    required this.wrongSelected,
    required this.missed,
  });

  /// `autoCorrect` или `autoIncorrect`; частично верных ответов у `mcq` нет.
  final AnswerOutcome outcome;

  /// Выбрали, и вариант верный.
  final Set<String> correctSelected;

  /// Выбрали, но вариант неверный (в том числе id, которого нет в вопросе).
  final Set<String> wrongSelected;

  /// Верный вариант, который не выбрали.
  final Set<String> missed;

  bool get isCorrect => outcome == AnswerOutcome.autoCorrect;
}

/// Проверяет ответ на `mcq` по совпадению множеств (ТЗ M4): верно, только
/// если выбраны ровно верные варианты — ни лишних, ни пропущенных. Пустой
/// выбор всегда неверен. Порядок и повторы в [selected] и в
/// `payload.correct` не важны.
McqGrade gradeMcq(McqPayload payload, Iterable<String> selected) {
  final correct = payload.correct.toSet();
  final chosen = selected.toSet();
  final correctSelected = chosen.intersection(correct);
  final wrongSelected = chosen.difference(correct);
  final missed = correct.difference(chosen);
  final isCorrect =
      chosen.isNotEmpty && wrongSelected.isEmpty && missed.isEmpty;
  return McqGrade(
    outcome: isCorrect
        ? AnswerOutcome.autoCorrect
        : AnswerOutcome.autoIncorrect,
    correctSelected: correctSelected,
    wrongSelected: wrongSelected,
    missed: missed,
  );
}
