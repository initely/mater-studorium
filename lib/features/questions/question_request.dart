import 'package:flutter/foundation.dart';

import '../catalog/domain/question.dart';
import 'question_result.dart';

/// Всё, что сессия отдаёт виджету формата.
class QuestionRequest {
  const QuestionRequest({
    required this.question,
    required this.shuffleSeed,
    required this.onAnswered,
    this.deckId = '',
    this.deckVersion = 0,
  });

  /// Вопрос; тип [Question.payload] соответствует типу модуля.
  final Question question;

  /// Зерно перемешивания (варианты `mcq`, шаги `order`): одно и то же для
  /// вопроса в течение сессии, поэтому поворот экрана и перестройка
  /// не меняют порядок. Сессия считает его от `question.id` и даты старта
  /// (`stableSeed`).
  final int shuffleSeed;

  /// Колода вопроса и её версия на устройстве. Нужны форматам, которые
  /// обращаются к серверу по вопросу (`open`: `grade-open-answer` берёт
  /// рубрику из колоды этой версии, ADR-31); остальным не нужны.
  final String deckId;
  final int deckVersion;

  /// Вызывается ровно один раз, когда ответ принят и проверен (у `flip` — когда
  /// показан оборот). Дальше сессия показывает вердикт и панель оценки.
  final ValueChanged<QuestionResult> onAnswered;
}
