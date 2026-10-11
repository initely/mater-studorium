// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deck_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeckItem _$DeckItemFromJson(Map<String, dynamic> json) => _DeckItem(
  id: json['id'] as String,
  title: json['title'] as String,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  fact: json['fact'] as String,
  explanationShort: json['explanation_short'] as String,
  explanationLong: json['explanation_long'] as String,
  refs: (json['refs'] as List<dynamic>)
      .map((e) => SourceRef.fromJson(e as Map<String, dynamic>))
      .toList(),
  review: Review.fromJson(json['review'] as Map<String, dynamic>),
  questions: (json['questions'] as List<dynamic>)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DeckItemToJson(_DeckItem instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'tags': instance.tags,
  'fact': instance.fact,
  'explanation_short': instance.explanationShort,
  'explanation_long': instance.explanationLong,
  'refs': instance.refs.map((e) => e.toJson()).toList(),
  'review': instance.review.toJson(),
  'questions': instance.questions.map((e) => e.toJson()).toList(),
};
