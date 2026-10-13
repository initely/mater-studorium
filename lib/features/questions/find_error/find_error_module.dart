import 'package:flutter/widgets.dart';

import '../../catalog/domain/question_payload.dart';
import '../../catalog/domain/question_type.dart';
import '../question_module.dart';
import '../question_request.dart';
import 'find_error_question.dart';

/// Формат `find_error`: тап по ошибочным строкам, локальная проверка
/// `gradeFindError` (ТЗ M4, §4.3).
class FindErrorModule implements QuestionModule {
  const FindErrorModule();

  @override
  QuestionType get type => QuestionType.findError;

  @override
  Widget build(BuildContext context, QuestionRequest request) =>
      FindErrorQuestion(
        prompt: request.question.prompt,
        payload: request.question.payload as FindErrorPayload,
        onAnswered: request.onAnswered,
      );
}
