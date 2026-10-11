// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SourceRef _$SourceRefFromJson(Map<String, dynamic> json) => _SourceRef(
  sourceId: json['source_id'] as String,
  quote: json['quote'] as String,
  quoteUnverifiable: json['quote_unverifiable'] as bool? ?? false,
);

Map<String, dynamic> _$SourceRefToJson(_SourceRef instance) =>
    <String, dynamic>{
      'source_id': instance.sourceId,
      'quote': instance.quote,
      'quote_unverifiable': instance.quoteUnverifiable,
    };
