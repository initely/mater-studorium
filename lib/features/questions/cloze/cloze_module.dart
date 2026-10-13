import 'package:flutter/widgets.dart';

import '../../catalog/domain/question_payload.dart';
import '../../catalog/domain/question_type.dart';
import '../question_module.dart';
import '../question_request.dart';
import 'cloze_question.dart';

/// Формат `cloze`: ввод в пропуски, локальная проверка `gradeCloze`
/// (ТЗ M4, §4.3).
class ClozeModule implements QuestionModule {
  const ClozeModule();

  @override
  QuestionType get type => QuestionType.cloze;

  @override
  Widget build(BuildContext context, QuestionRequest request) => ClozeQuestion(
    prompt: request.question.prompt,
    payload: request.question.payload as ClozePayload,
    onAnswered: request.onAnswered,
  );
}
