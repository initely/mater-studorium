// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

McqPayload _$McqPayloadFromJson(Map<String, dynamic> json) => McqPayload(
  options: (json['options'] as List<dynamic>)
      .map((e) => McqOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  correct: (json['correct'] as List<dynamic>).map((e) => e as String).toList(),
  multiple: json['multiple'] as bool,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$McqPayloadToJson(McqPayload instance) =>
    <String, dynamic>{
      'options': instance.options.map((e) => e.toJson()).toList(),
      'correct': instance.correct,
      'multiple': instance.multiple,
      'type': instance.$type,
    };

FlipPayload _$FlipPayloadFromJson(Map<String, dynamic> json) =>
    FlipPayload(back: json['back'] as String, $type: json['type'] as String?);

Map<String, dynamic> _$FlipPayloadToJson(FlipPayload instance) =>
    <String, dynamic>{'back': instance.back, 'type': instance.$type};

OpenPayload _$OpenPayloadFromJson(Map<String, dynamic> json) => OpenPayload(
  referenceAnswer: json['reference_answer'] as String,
  rubric: (json['rubric'] as List<dynamic>)
      .map((e) => RubricPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$OpenPayloadToJson(OpenPayload instance) =>
    <String, dynamic>{
      'reference_answer': instance.referenceAnswer,
      'rubric': instance.rubric.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

ClozePayload _$ClozePayloadFromJson(Map<String, dynamic> json) => ClozePayload(
  blanks: (json['blanks'] as List<dynamic>)
      .map((e) => ClozeBlank.fromJson(e as Map<String, dynamic>))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ClozePayloadToJson(ClozePayload instance) =>
    <String, dynamic>{
      'blanks': instance.blanks.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

OrderPayload _$OrderPayloadFromJson(Map<String, dynamic> json) => OrderPayload(
  steps: (json['steps'] as List<dynamic>)
      .map((e) => OrderStep.fromJson(e as Map<String, dynamic>))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$OrderPayloadToJson(OrderPayload instance) =>
    <String, dynamic>{
      'steps': instance.steps.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

FindErrorPayload _$FindErrorPayloadFromJson(Map<String, dynamic> json) =>
    FindErrorPayload(
      mode: $enumDecode(_$FindErrorModeEnumMap, json['mode']),
      language: json['language'] as String?,
      lines: (json['lines'] as List<dynamic>).map((e) => e as String).toList(),
      errorLines: (json['error_lines'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      lineExplanations: (json['line_explanations'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(int.parse(k), e as String),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$FindErrorPayloadToJson(FindErrorPayload instance) =>
    <String, dynamic>{
      'mode': _$FindErrorModeEnumMap[instance.mode]!,
      'language': ?instance.language,
      'lines': instance.lines,
      'error_lines': instance.errorLines,
      'line_explanations': instance.lineExplanations.map(
        (k, e) => MapEntry(k.toString(), e),
      ),
      'type': instance.$type,
    };

const _$FindErrorModeEnumMap = {
  FindErrorMode.code: 'code',
  FindErrorMode.text: 'text',
};
