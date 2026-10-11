import 'package:flutter/widgets.dart';

import '../../catalog/domain/question_payload.dart';
import '../../catalog/domain/question_type.dart';
import '../question_module.dart';
import '../question_request.dart';
import 'flip_question.dart';

/// Формат `flip`: карточка с самооценкой (ТЗ M4). Грейдера нет: результат
/// всегда `AnswerOutcome.flip`.
class FlipModule implements QuestionModule {
  const FlipModule();

  @override
  QuestionType get type => QuestionType.flip;

  @override
  Widget build(BuildContext context, QuestionRequest request) => FlipQuestion(
    prompt: request.question.prompt,
    back: (request.question.payload as FlipPayload).back,
    onAnswered: request.onAnswered,
  );
}
