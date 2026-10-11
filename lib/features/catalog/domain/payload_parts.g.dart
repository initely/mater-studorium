// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payload_parts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_McqOption _$McqOptionFromJson(Map<String, dynamic> json) =>
    _McqOption(id: json['id'] as String, text: json['text'] as String);

Map<String, dynamic> _$McqOptionToJson(_McqOption instance) =>
    <String, dynamic>{'id': instance.id, 'text': instance.text};

_RubricPoint _$RubricPointFromJson(Map<String, dynamic> json) => _RubricPoint(
  id: json['id'] as String,
  text: json['text'] as String,
  weight: (json['weight'] as num).toInt(),
  required: json['required'] as bool,
);

Map<String, dynamic> _$RubricPointToJson(_RubricPoint instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'weight': instance.weight,
      'required': instance.required,
    };

_ClozeBlank _$ClozeBlankFromJson(Map<String, dynamic> json) => _ClozeBlank(
  id: json['id'] as String,
  accepted: (json['accepted'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ClozeBlankToJson(_ClozeBlank instance) =>
    <String, dynamic>{'id': instance.id, 'accepted': instance.accepted};

_OrderStep _$OrderStepFromJson(Map<String, dynamic> json) =>
    _OrderStep(id: json['id'] as String, text: json['text'] as String);

Map<String, dynamic> _$OrderStepToJson(_OrderStep instance) =>
    <String, dynamic>{'id': instance.id, 'text': instance.text};
