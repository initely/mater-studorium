// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Question _$QuestionFromJson(Map<String, dynamic> json) => _Question(
  id: json['id'] as String,
  type: $enumDecode(_$QuestionTypeEnumMap, json['type']),
  prompt: json['prompt'] as String,
  explanationShort: json['explanation_short'] as String?,
  payload: QuestionPayload.fromJson(
    _readPayload(json, 'payload') as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$QuestionToJson(_Question instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$QuestionTypeEnumMap[instance.type]!,
  'prompt': instance.prompt,
  'explanation_short': ?instance.explanationShort,
  'payload': _payloadToJson(instance.payload),
};

const _$QuestionTypeEnumMap = {
  QuestionType.mcq: 'mcq',
  QuestionType.flip: 'flip',
  QuestionType.open: 'open',
  QuestionType.cloze: 'cloze',
  QuestionType.order: 'order',
  QuestionType.findError: 'find_error',
};
