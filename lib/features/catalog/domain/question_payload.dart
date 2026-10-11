import 'package:freezed_annotation/freezed_annotation.dart';

import 'payload_parts.dart';
import 'question_type.dart';

part 'question_payload.freezed.dart';
part 'question_payload.g.dart';

/// Плейсхолдер пропуска в тексте `cloze`: `{{id}}`.
final clozePlaceholder = RegExp(r'\{\{([A-Za-z0-9_-]+)\}\}');

/// Данные вопроса, нужные виджету и грейдеру его типа (ТЗ M4, §4.2, §4.3).
///
/// Sealed-объединение с дискриминатором `type` (значения как в
/// [QuestionType]). Внутри колоды `type` хранится на уровне `Question`,
/// см. `question.dart`; отдельно сериализованный payload (например,
/// в локальной БД) содержит `type` сам.
@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
sealed class QuestionPayload with _$QuestionPayload {
  const QuestionPayload._();

  /// Выбор из вариантов; проверка — совпадение множеств [correct].
  const factory QuestionPayload.mcq({
    required List<McqOption> options,
    required List<String> correct,

    /// `false` — ровно один верный вариант.
    required bool multiple,
  }) = McqPayload;

  /// Карточка: `prompt` — лицевая сторона, [back] — оборот.
  const factory QuestionPayload.flip({required String back}) = FlipPayload;

  /// Открытый ответ, оценка — Edge Function `grade-open-answer`.
  const factory QuestionPayload.open({
    /// Эталон в 1–3 предложения.
    required String referenceAnswer,

    /// 2–5 пунктов, хотя бы один обязательный.
    required List<RubricPoint> rubric,
  }) = OpenPayload;

  /// Пропуски `{{id}}` в `prompt`.
  const factory QuestionPayload.cloze({required List<ClozeBlank> blanks}) =
      ClozePayload;

  /// Шаги в эталонном порядке; клиент перемешивает.
  const factory QuestionPayload.order({required List<OrderStep> steps}) =
      OrderPayload;

  /// Найти 1–2 ошибочные строки. Номера строк 1-based.
  const factory QuestionPayload.findError({
    required FindErrorMode mode,

    /// Язык подсветки для [FindErrorMode.code].
    String? language,
    required List<String> lines,
    required List<int> errorLines,

    /// Пояснения по номеру строки, есть для каждой строки из [errorLines].
    required Map<int, String> lineExplanations,
  }) = FindErrorPayload;

  factory QuestionPayload.fromJson(Map<String, dynamic> json) =>
      _$QuestionPayloadFromJson(json);

  QuestionType get type => switch (this) {
    McqPayload() => QuestionType.mcq,
    FlipPayload() => QuestionType.flip,
    OpenPayload() => QuestionType.open,
    ClozePayload() => QuestionType.cloze,
    OrderPayload() => QuestionType.order,
    FindErrorPayload() => QuestionType.findError,
  };
}
