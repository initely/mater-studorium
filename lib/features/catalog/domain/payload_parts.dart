import 'package:freezed_annotation/freezed_annotation.dart';

part 'payload_parts.freezed.dart';
part 'payload_parts.g.dart';

/// Вариант ответа `mcq`.
@freezed
abstract class McqOption with _$McqOption {
  const factory McqOption({required String id, required String text}) =
      _McqOption;

  factory McqOption.fromJson(Map<String, dynamic> json) =>
      _$McqOptionFromJson(json);
}

/// Пункт рубрики `open` (ТЗ §4.2).
@freezed
abstract class RubricPoint with _$RubricPoint {
  const factory RubricPoint({
    required String id,
    required String text,

    /// Вес 1–3 во взвешенном среднем балла.
    required int weight,

    /// `miss` по обязательному пункту ограничивает вердикт значением
    /// `partial`.
    required bool required,
  }) = _RubricPoint;

  factory RubricPoint.fromJson(Map<String, dynamic> json) =>
      _$RubricPointFromJson(json);
}

/// Пропуск `cloze`, в тексте вопроса обозначен `{{id}}`.
@freezed
abstract class ClozeBlank with _$ClozeBlank {
  const factory ClozeBlank({
    required String id,

    /// Допустимые ответы; первый показывается как правильный.
    required List<String> accepted,
  }) = _ClozeBlank;

  factory ClozeBlank.fromJson(Map<String, dynamic> json) =>
      _$ClozeBlankFromJson(json);
}

/// Шаг `order`. Эталонный порядок — порядок в JSON.
@freezed
abstract class OrderStep with _$OrderStep {
  const factory OrderStep({required String id, required String text}) =
      _OrderStep;

  factory OrderStep.fromJson(Map<String, dynamic> json) =>
      _$OrderStepFromJson(json);
}

/// Что показывает `find_error`: код (моноширинно, с подсветкой) или текст.
enum FindErrorMode { code, text }
