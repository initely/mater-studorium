import 'package:flutter/widgets.dart';

import '../../catalog/domain/question_payload.dart';
import '../../catalog/domain/question_type.dart';
import '../question_module.dart';
import '../question_request.dart';
import 'open_question.dart';

/// Формат `open`: текст или диктовка, оценка Edge Function по рубрике колоды,
/// фолбэк на самооценку с эталоном (ТЗ M4, M5, §4.2).
class OpenModule implements QuestionModule {
  const OpenModule();

  @override
  QuestionType get type => QuestionType.open;

  @override
  Widget build(BuildContext context, QuestionRequest request) {
    final payload = request.question.payload as OpenPayload;
    return OpenQuestion(
      prompt: request.question.prompt,
      questionId: request.question.id,
      referenceAnswer: payload.referenceAnswer,
      rubric: payload.rubric,
      deckId: request.deckId,
      deckVersion: request.deckVersion,
      onAnswered: request.onAnswered,
    );
  }
}
