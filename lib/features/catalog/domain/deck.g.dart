// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deck.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Deck _$DeckFromJson(Map<String, dynamic> json) => _Deck(
  schemaVersion: (json['schema_version'] as num).toInt(),
  id: json['id'] as String,
  version: (json['version'] as num).toInt(),
  lang: json['lang'] as String,
  topic: json['topic'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  sources: (json['sources'] as List<dynamic>)
      .map((e) => DeckSource.fromJson(e as Map<String, dynamic>))
      .toList(),
  items: (json['items'] as List<dynamic>)
      .map((e) => DeckItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DeckToJson(_Deck instance) => <String, dynamic>{
  'schema_version': instance.schemaVersion,
  'id': instance.id,
  'version': instance.version,
  'lang': instance.lang,
  'topic': instance.topic,
  'title': instance.title,
  'description': instance.description,
  'sources': instance.sources.map((e) => e.toJson()).toList(),
  'items': instance.items.map((e) => e.toJson()).toList(),
};
