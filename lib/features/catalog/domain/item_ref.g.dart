// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ItemRef _$ItemRefFromJson(Map<String, dynamic> json) => _ItemRef(
  sourceId: json['source_id'] as String,
  quote: json['quote'] as String,
  quoteUnverifiable: json['quote_unverifiable'] as bool? ?? false,
  sourceTitle: json['source_title'] as String,
  url: json['url'] as String,
  license: json['license'] as String,
);

Map<String, dynamic> _$ItemRefToJson(_ItemRef instance) => <String, dynamic>{
  'source_id': instance.sourceId,
  'quote': instance.quote,
  'quote_unverifiable': instance.quoteUnverifiable,
  'source_title': instance.sourceTitle,
  'url': instance.url,
  'license': instance.license,
};
