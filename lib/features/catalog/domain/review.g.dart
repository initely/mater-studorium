// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Review _$ReviewFromJson(Map<String, dynamic> json) => _Review(
  status: $enumDecode(_$ReviewStatusEnumMap, json['status']),
  by: json['by'] as String?,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$ReviewToJson(_Review instance) => <String, dynamic>{
  'status': _$ReviewStatusEnumMap[instance.status]!,
  'by': ?instance.by,
  'notes': ?instance.notes,
};

const _$ReviewStatusEnumMap = {
  ReviewStatus.draft: 'draft',
  ReviewStatus.needsFix: 'needs_fix',
  ReviewStatus.approved: 'approved',
};
