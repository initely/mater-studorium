// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReviewLog {

/// uuid, создаётся на клиенте: повторная отправка идемпотентна.
 String get id; String get deckId; int get deckVersion; String get itemId; String get questionId; QuestionType get questionType; Rating get rating; GradeSource get gradeSource; double? get llmScore; String? get answerText; int get durationMs;/// UTC.
 DateTime get reviewedAt;
/// Create a copy of ReviewLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewLogCopyWith<ReviewLog> get copyWith => _$ReviewLogCopyWithImpl<ReviewLog>(this as ReviewLog, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReviewLog;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewLog&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.deckId, _this.deckId) || other.deckId == _this.deckId)&&(identical(other.deckVersion, _this.deckVersion) || other.deckVersion == _this.deckVersion)&&(identical(other.itemId, _this.itemId) || other.itemId == _this.itemId)&&(identical(other.questionId, _this.questionId) || other.questionId == _this.questionId)&&(identical(other.questionType, _this.questionType) || other.questionType == _this.questionType)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.gradeSource, _this.gradeSource) || other.gradeSource == _this.gradeSource)&&(identical(other.llmScore, _this.llmScore) || other.llmScore == _this.llmScore)&&(identical(other.answerText, _this.answerText) || other.answerText == _this.answerText)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.reviewedAt, _this.reviewedAt) || other.reviewedAt == _this.reviewedAt));
}


@override
int get hashCode {
  final _this = this as ReviewLog;
  return Object.hash(runtimeType,_this.id,_this.deckId,_this.deckVersion,_this.itemId,_this.questionId,_this.questionType,_this.rating,_this.gradeSource,_this.llmScore,_this.answerText,_this.durationMs,_this.reviewedAt);
}

@override
String toString() {
  final _this = this as ReviewLog;
  return 'ReviewLog(id: ${_this.id}, deckId: ${_this.deckId}, deckVersion: ${_this.deckVersion}, itemId: ${_this.itemId}, questionId: ${_this.questionId}, questionType: ${_this.questionType}, rating: ${_this.rating}, gradeSource: ${_this.gradeSource}, llmScore: ${_this.llmScore}, answerText: ${_this.answerText}, durationMs: ${_this.durationMs}, reviewedAt: ${_this.reviewedAt})';
}


}

/// @nodoc
abstract mixin class $ReviewLogCopyWith<$Res>  {
  factory $ReviewLogCopyWith(ReviewLog value, $Res Function(ReviewLog) _then) = _$ReviewLogCopyWithImpl;
@useResult
$Res call({
 String id, String deckId, int deckVersion, String itemId, String questionId, QuestionType questionType, Rating rating, GradeSource gradeSource, double? llmScore, String? answerText, int durationMs, DateTime reviewedAt
});




}
/// @nodoc
class _$ReviewLogCopyWithImpl<$Res>
    implements $ReviewLogCopyWith<$Res> {
  _$ReviewLogCopyWithImpl(this._self, this._then);

  final ReviewLog _self;
  final $Res Function(ReviewLog) _then;

/// Create a copy of ReviewLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deckId = null,Object? deckVersion = null,Object? itemId = null,Object? questionId = null,Object? questionType = null,Object? rating = null,Object? gradeSource = null,Object? llmScore = freezed,Object? answerText = freezed,Object? durationMs = null,Object? reviewedAt = null,}) {
  return _then(ReviewLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,deckVersion: null == deckVersion ? _self.deckVersion : deckVersion // ignore: cast_nullable_to_non_nullable
as int,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,questionType: null == questionType ? _self.questionType : questionType // ignore: cast_nullable_to_non_nullable
as QuestionType,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as Rating,gradeSource: null == gradeSource ? _self.gradeSource : gradeSource // ignore: cast_nullable_to_non_nullable
as GradeSource,llmScore: freezed == llmScore ? _self.llmScore : llmScore // ignore: cast_nullable_to_non_nullable
as double?,answerText: freezed == answerText ? _self.answerText : answerText // ignore: cast_nullable_to_non_nullable
as String?,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,reviewedAt: null == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewLog].
extension ReviewLogPatterns on ReviewLog {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewLog() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewLog value)  $default,){
final _that = this;
switch (_that) {
case _ReviewLog():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewLog value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewLog() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deckId,  int deckVersion,  String itemId,  String questionId,  QuestionType questionType,  Rating rating,  GradeSource gradeSource,  double? llmScore,  String? answerText,  int durationMs,  DateTime reviewedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewLog() when $default != null:
return $default(_that.id,_that.deckId,_that.deckVersion,_that.itemId,_that.questionId,_that.questionType,_that.rating,_that.gradeSource,_that.llmScore,_that.answerText,_that.durationMs,_that.reviewedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deckId,  int deckVersion,  String itemId,  String questionId,  QuestionType questionType,  Rating rating,  GradeSource gradeSource,  double? llmScore,  String? answerText,  int durationMs,  DateTime reviewedAt)  $default,) {final _that = this;
switch (_that) {
case _ReviewLog():
return $default(_that.id,_that.deckId,_that.deckVersion,_that.itemId,_that.questionId,_that.questionType,_that.rating,_that.gradeSource,_that.llmScore,_that.answerText,_that.durationMs,_that.reviewedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deckId,  int deckVersion,  String itemId,  String questionId,  QuestionType questionType,  Rating rating,  GradeSource gradeSource,  double? llmScore,  String? answerText,  int durationMs,  DateTime reviewedAt)?  $default,) {final _that = this;
switch (_that) {
case _ReviewLog() when $default != null:
return $default(_that.id,_that.deckId,_that.deckVersion,_that.itemId,_that.questionId,_that.questionType,_that.rating,_that.gradeSource,_that.llmScore,_that.answerText,_that.durationMs,_that.reviewedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ReviewLog implements ReviewLog {
  const _ReviewLog({required this.id, required this.deckId, required this.deckVersion, required this.itemId, required this.questionId, required this.questionType, required this.rating, required this.gradeSource, this.llmScore, this.answerText, required this.durationMs, required this.reviewedAt});
  

/// uuid, создаётся на клиенте: повторная отправка идемпотентна.
@override final  String id;
@override final  String deckId;
@override final  int deckVersion;
@override final  String itemId;
@override final  String questionId;
@override final  QuestionType questionType;
@override final  Rating rating;
@override final  GradeSource gradeSource;
@override final  double? llmScore;
@override final  String? answerText;
@override final  int durationMs;
/// UTC.
@override final  DateTime reviewedAt;

/// Create a copy of ReviewLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewLogCopyWith<_ReviewLog> get copyWith => __$ReviewLogCopyWithImpl<_ReviewLog>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewLog&&(identical(other.id, id) || other.id == id)&&(identical(other.deckId, deckId) || other.deckId == deckId)&&(identical(other.deckVersion, deckVersion) || other.deckVersion == deckVersion)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.questionId, questionId) || other.questionId == questionId)&&(identical(other.questionType, questionType) || other.questionType == questionType)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.gradeSource, gradeSource) || other.gradeSource == gradeSource)&&(identical(other.llmScore, llmScore) || other.llmScore == llmScore)&&(identical(other.answerText, answerText) || other.answerText == answerText)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,deckId,deckVersion,itemId,questionId,questionType,rating,gradeSource,llmScore,answerText,durationMs,reviewedAt);
}

@override
String toString() {
    return 'ReviewLog(id: $id, deckId: $deckId, deckVersion: $deckVersion, itemId: $itemId, questionId: $questionId, questionType: $questionType, rating: $rating, gradeSource: $gradeSource, llmScore: $llmScore, answerText: $answerText, durationMs: $durationMs, reviewedAt: $reviewedAt)';
}


}

/// @nodoc
abstract mixin class _$ReviewLogCopyWith<$Res> implements $ReviewLogCopyWith<$Res> {
  factory _$ReviewLogCopyWith(_ReviewLog value, $Res Function(_ReviewLog) _then) = __$ReviewLogCopyWithImpl;
@override @useResult
$Res call({
 String id, String deckId, int deckVersion, String itemId, String questionId, QuestionType questionType, Rating rating, GradeSource gradeSource, double? llmScore, String? answerText, int durationMs, DateTime reviewedAt
});




}
/// @nodoc
class __$ReviewLogCopyWithImpl<$Res>
    implements _$ReviewLogCopyWith<$Res> {
  __$ReviewLogCopyWithImpl(this._self, this._then);

  final _ReviewLog _self;
  final $Res Function(_ReviewLog) _then;

/// Create a copy of ReviewLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deckId = null,Object? deckVersion = null,Object? itemId = null,Object? questionId = null,Object? questionType = null,Object? rating = null,Object? gradeSource = null,Object? llmScore = freezed,Object? answerText = freezed,Object? durationMs = null,Object? reviewedAt = null,}) {
  return _then(_ReviewLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,deckVersion: null == deckVersion ? _self.deckVersion : deckVersion // ignore: cast_nullable_to_non_nullable
as int,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,questionId: null == questionId ? _self.questionId : questionId // ignore: cast_nullable_to_non_nullable
as String,questionType: null == questionType ? _self.questionType : questionType // ignore: cast_nullable_to_non_nullable
as QuestionType,rating: null == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as Rating,gradeSource: null == gradeSource ? _self.gradeSource : gradeSource // ignore: cast_nullable_to_non_nullable
as GradeSource,llmScore: freezed == llmScore ? _self.llmScore : llmScore // ignore: cast_nullable_to_non_nullable
as double?,answerText: freezed == answerText ? _self.answerText : answerText // ignore: cast_nullable_to_non_nullable
as String?,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,reviewedAt: null == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
