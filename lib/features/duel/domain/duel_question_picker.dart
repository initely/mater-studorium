import 'dart:math';

import '../../../core/errors/app_error.dart';
import '../../catalog/domain/question_type.dart';

/// Сколько вопросов в дуэли (ТЗ M10).
const kDuelQuestionCount = 5;

/// Форматы, которые можно взять в дуэль: автопроверяемые (ТЗ M10). Единственное
/// место со списком: `mcq` и форматы MVP-b (T30) `cloze`, `order`,
/// `find_error`. Сервер тип вопроса не проверяет (ADR-35).
const kDuelQuestionTypes = {
  QuestionType.mcq,
  QuestionType.cloze,
  QuestionType.order,
  QuestionType.findError,
};

/// Вопрос колоды, который можно взять в дуэль.
class DuelCandidate {
  const DuelCandidate({required this.questionId, required this.itemId});

  final String questionId;
  final String itemId;
}

/// Выбирает [kDuelQuestionCount] случайных вопросов, по возможности из разных
/// знаний (дуэль не должна спрашивать одно и то же дважды). Если знаний
/// меньше, чем нужно, добирает вторыми вариантами. Порядок — случайный.
///
/// Бросает [DuelNotEnoughQuestionsError], если вопросов меньше
/// [kDuelQuestionCount].
List<String> pickDuelQuestions(List<DuelCandidate> candidates, Random random) {
  if (candidates.length < kDuelQuestionCount) {
    throw DuelNotEnoughQuestionsError(candidates.length);
  }
  final shuffled = [...candidates]..shuffle(random);
  final picked = <DuelCandidate>[];
  final seenItems = <String>{};
  for (final c in shuffled) {
    if (picked.length == kDuelQuestionCount) break;
    if (seenItems.add(c.itemId)) picked.add(c);
  }
  for (final c in shuffled) {
    if (picked.length == kDuelQuestionCount) break;
    if (!picked.contains(c)) picked.add(c);
  }
  return [for (final c in picked) c.questionId]..shuffle(random);
}
