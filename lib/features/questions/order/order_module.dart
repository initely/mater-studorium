import 'package:flutter/widgets.dart';

import '../../catalog/domain/question_payload.dart';
import '../../catalog/domain/question_type.dart';
import '../question_module.dart';
import '../question_request.dart';
import 'order_question.dart';

/// Формат `order`: расстановка шагов, локальная проверка `gradeOrder`
/// (ТЗ M4, §4.3).
class OrderModule implements QuestionModule {
  const OrderModule();

  @override
  QuestionType get type => QuestionType.order;

  @override
  Widget build(BuildContext context, QuestionRequest request) => OrderQuestion(
    prompt: request.question.prompt,
    payload: request.question.payload as OrderPayload,
    shuffleSeed: request.shuffleSeed,
    onAnswered: request.onAnswered,
  );
}
