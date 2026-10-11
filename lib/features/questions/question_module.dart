import 'package:flutter/widgets.dart';

import '../catalog/domain/question_type.dart';
import 'question_request.dart';

/// Один формат вопроса в реестре (ТЗ M4, CLAUDE.md, правило 3).
///
/// Модуль связывает тип с виджетом и своим грейдером: виджет сам принимает
/// ввод, проверяет его (локальный грейдер из `grading/domain/` или, для
/// `open`, вызов Edge Function) и отдаёт сессии `QuestionResult`. Виджет
/// рисует и текст вопроса (`question.prompt`): у `cloze` он встроен
/// в поля ввода. Состояние ввода держит сам виджет и сохраняет его при
/// повороте экрана; пересоздаётся он, только когда сессия перешла к
/// следующему вопросу.
abstract interface class QuestionModule {
  QuestionType get type;

  Widget build(BuildContext context, QuestionRequest request);
}
