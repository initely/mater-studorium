import '../../catalog/domain/question_payload.dart';
import '../../srs/domain/answer_outcome.dart';

/// Сколько строк можно выделить в `find_error` (ТЗ §4.3: `error_lines` — 1–2).
const int kFindErrorMaxSelection = 2;

/// Результат проверки `find_error` (ТЗ §4.3): итог и разбор по строкам для
/// подсветки. Номера строк с 1.
class FindErrorGrade {
  const FindErrorGrade({
    required this.outcome,
    required this.found,
    required this.wrong,
    required this.missed,
  });

  /// `autoCorrect` или `autoIncorrect`; частично верных ответов нет.
  final AnswerOutcome outcome;

  /// Выделили, и строка ошибочная.
  final Set<int> found;

  /// Выделили, но ошибки в строке нет.
  final Set<int> wrong;

  /// Ошибочная строка, которую не выделили.
  final Set<int> missed;

  bool get isCorrect => outcome == AnswerOutcome.autoCorrect;
}

/// Проверяет ответ по совпадению множеств (ТЗ §4.3): верно, только если
/// выделены ровно ошибочные строки. Пустой выбор всегда неверен. Порядок
/// и повторы в [selected] не важны.
FindErrorGrade gradeFindError(
  FindErrorPayload payload,
  Iterable<int> selected,
) {
  final errors = payload.errorLines.toSet();
  final chosen = selected.toSet();
  final found = chosen.intersection(errors);
  final wrong = chosen.difference(errors);
  final missed = errors.difference(chosen);
  final isCorrect = chosen.isNotEmpty && wrong.isEmpty && missed.isEmpty;
  return FindErrorGrade(
    outcome: isCorrect
        ? AnswerOutcome.autoCorrect
        : AnswerOutcome.autoIncorrect,
    found: found,
    wrong: wrong,
    missed: missed,
  );
}
