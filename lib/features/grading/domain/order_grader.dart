import 'dart:math';

import '../../catalog/domain/payload_parts.dart';
import '../../catalog/domain/question_payload.dart';
import '../../srs/domain/answer_outcome.dart';

/// Шаги `order` в перемешанном порядке (ТЗ §4.3). Порядок определяется только
/// [seed], как у `shuffledOptions`; результат гарантированно не совпадает
/// с эталоном (порядком в JSON), если шагов хотя бы два.
List<OrderStep> shuffledSteps(List<OrderStep> steps, int seed) {
  final shuffled = [...steps]..shuffle(Random(seed));
  if (steps.length > 1 && _sameOrder(shuffled, steps)) {
    // Сдвиг на один даёт порядок, отличный от эталона при ≥ 2 разных шагах.
    shuffled.add(shuffled.removeAt(0));
  }
  return shuffled;
}

bool _sameOrder(List<OrderStep> a, List<OrderStep> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

/// Разбор одного шага для подсветки после ответа.
class OrderStepGrade {
  const OrderStepGrade({
    required this.id,
    required this.position,
    required this.correctPosition,
  });

  final String id;

  /// Где пользователь поставил шаг (с 1).
  final int position;

  /// Где шаг должен стоять (с 1).
  final int correctPosition;

  bool get isCorrect => position == correctPosition;
}

/// Результат проверки `order` (ТЗ §4.3).
class OrderGrade {
  const OrderGrade({required this.outcome, required this.steps});

  /// `autoCorrect` — полное совпадение; `orderAdjacentSwap` — ровно одна
  /// перестановка соседних шагов; иначе `autoIncorrect`.
  final AnswerOutcome outcome;

  /// По порядку, в котором пользователь расставил шаги.
  final List<OrderStepGrade> steps;

  bool get isCorrect => outcome == AnswerOutcome.autoCorrect;
}

/// Проверяет порядок: [orderedIds] — id шагов так, как их расставил
/// пользователь. Набор id, не совпадающий с шагами вопроса (пропуск, лишний
/// или повтор), даёт `autoIncorrect`.
OrderGrade gradeOrder(OrderPayload payload, List<String> orderedIds) {
  final reference = [for (final s in payload.steps) s.id];
  final referenceIndex = {
    for (var i = 0; i < reference.length; i++) reference[i]: i + 1,
  };
  final validSet =
      orderedIds.length == reference.length &&
      orderedIds.toSet().length == reference.length &&
      orderedIds.every(referenceIndex.containsKey);
  final steps = [
    for (var i = 0; i < orderedIds.length; i++)
      OrderStepGrade(
        id: orderedIds[i],
        position: i + 1,
        correctPosition: referenceIndex[orderedIds[i]] ?? 0,
      ),
  ];
  if (!validSet) {
    return OrderGrade(outcome: AnswerOutcome.autoIncorrect, steps: steps);
  }
  final wrong = [
    for (var i = 0; i < steps.length; i++)
      if (!steps[i].isCorrect) i,
  ];
  final AnswerOutcome outcome;
  if (wrong.isEmpty) {
    outcome = AnswerOutcome.autoCorrect;
  } else if (wrong.length == 2 &&
      wrong[1] == wrong[0] + 1 &&
      orderedIds[wrong[0]] == reference[wrong[1]] &&
      orderedIds[wrong[1]] == reference[wrong[0]]) {
    outcome = AnswerOutcome.orderAdjacentSwap;
  } else {
    outcome = AnswerOutcome.autoIncorrect;
  }
  return OrderGrade(outcome: outcome, steps: steps);
}
