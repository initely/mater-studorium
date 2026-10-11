import 'package:flutter/widgets.dart';

import '../../catalog/domain/question_payload.dart';
import '../../catalog/domain/question_type.dart';
import '../question_module.dart';
import '../question_request.dart';
import 'mcq_question.dart';

/// Формат `mcq`: выбор одного или нескольких вариантов, локальная проверка
/// `gradeMcq` (ТЗ M4, §4.3).
class McqModule implements QuestionModule {
  const McqModule();

  @override
  QuestionType get type => QuestionType.mcq;

  @override
  Widget build(BuildContext context, QuestionRequest request) => McqQuestion(
    prompt: request.question.prompt,
    payload: request.question.payload as McqPayload,
    shuffleSeed: request.shuffleSeed,
    onAnswered: request.onAnswered,
  );
}
