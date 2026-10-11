// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'deck_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeckItem {

 String get id; String get title; List<String> get tags; String get fact;/// «Коротко»: 2–3 предложения.
 String get explanationShort;/// «Подробнее»: markdown до ~300 слов.
 String get explanationLong; List<SourceRef> get refs; Review get review; List<Question> get questions;
/// Create a copy of DeckItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeckItemCopyWith<DeckItem> get copyWith => _$DeckItemCopyWithImpl<DeckItem>(this as DeckItem, _$identity);

  /// Serializes this DeckItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeckItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeckItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.fact, _this.fact) || other.fact == _this.fact)&&(identical(other.explanationShort, _this.explanationShort) || other.explanationShort == _this.explanationShort)&&(identical(other.explanationLong, _this.explanationLong) || other.explanationLong == _this.explanationLong)&&const DeepCollectionEquality().equals(other.refs, _this.refs)&&(identical(other.review, _this.review) || other.review == _this.review)&&const DeepCollectionEquality().equals(other.questions, _this.questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeckItem;
  return Object.hash(runtimeType,_this.id,_this.title,const DeepCollectionEquality().hash(_this.tags),_this.fact,_this.explanationShort,_this.explanationLong,const DeepCollectionEquality().hash(_this.refs),_this.review,const DeepCollectionEquality().hash(_this.questions));
}

@override
String toString() {
  final _this = this as DeckItem;
  return 'DeckItem(id: ${_this.id}, title: ${_this.title}, tags: ${_this.tags}, fact: ${_this.fact}, explanationShort: ${_this.explanationShort}, explanationLong: ${_this.explanationLong}, refs: ${_this.refs}, review: ${_this.review}, questions: ${_this.questions})';
}


}

/// @nodoc
abstract mixin class $DeckItemCopyWith<$Res>  {
  factory $DeckItemCopyWith(DeckItem value, $Res Function(DeckItem) _then) = _$DeckItemCopyWithImpl;
@useResult
$Res call({
 String id, String title, List<String> tags, String fact, String explanationShort, String explanationLong, List<SourceRef> refs, Review review, List<Question> questions
});


$ReviewCopyWith<$Res> get review;

}
/// @nodoc
class _$DeckItemCopyWithImpl<$Res>
    implements $DeckItemCopyWith<$Res> {
  _$DeckItemCopyWithImpl(this._self, this._then);

  final DeckItem _self;
  final $Res Function(DeckItem) _then;

/// Create a copy of DeckItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? tags = null,Object? fact = null,Object? explanationShort = null,Object? explanationLong = null,Object? refs = null,Object? review = null,Object? questions = null,}) {
  return _then(DeckItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,fact: null == fact ? _self.fact : fact // ignore: cast_nullable_to_non_nullable
as String,explanationShort: null == explanationShort ? _self.explanationShort : explanationShort // ignore: cast_nullable_to_non_nullable
as String,explanationLong: null == explanationLong ? _self.explanationLong : explanationLong // ignore: cast_nullable_to_non_nullable
as String,refs: null == refs ? _self.refs : refs // ignore: cast_nullable_to_non_nullable
as List<SourceRef>,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as Review,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<Question>,
  ));
}
/// Create a copy of DeckItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReviewCopyWith<$Res> get review {
  
  return $ReviewCopyWith<$Res>(_self.review, (value) {
    return _then(_self.copyWith(review: value));
  });
}
}


/// Adds pattern-matching-related methods to [DeckItem].
extension DeckItemPatterns on DeckItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeckItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeckItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeckItem value)  $default,){
final _that = this;
switch (_that) {
case _DeckItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeckItem value)?  $default,){
final _that = this;
switch (_that) {
case _DeckItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  List<String> tags,  String fact,  String explanationShort,  String explanationLong,  List<SourceRef> refs,  Review review,  List<Question> questions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeckItem() when $default != null:
return $default(_that.id,_that.title,_that.tags,_that.fact,_that.explanationShort,_that.explanationLong,_that.refs,_that.review,_that.questions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  List<String> tags,  String fact,  String explanationShort,  String explanationLong,  List<SourceRef> refs,  Review review,  List<Question> questions)  $default,) {final _that = this;
switch (_that) {
case _DeckItem():
return $default(_that.id,_that.title,_that.tags,_that.fact,_that.explanationShort,_that.explanationLong,_that.refs,_that.review,_that.questions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  List<String> tags,  String fact,  String explanationShort,  String explanationLong,  List<SourceRef> refs,  Review review,  List<Question> questions)?  $default,) {final _that = this;
switch (_that) {
case _DeckItem() when $default != null:
return $default(_that.id,_that.title,_that.tags,_that.fact,_that.explanationShort,_that.explanationLong,_that.refs,_that.review,_that.questions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeckItem implements DeckItem {
  const _DeckItem({required this.id, required this.title,  List<String> tags = const <String>[], required this.fact, required this.explanationShort, required this.explanationLong, required  List<SourceRef> refs, required this.review, required  List<Question> questions}): _tags = tags,_refs = refs,_questions = questions;
  factory _DeckItem.fromJson(Map<String, dynamic> json) => _$DeckItemFromJson(json);

@override final  String id;
@override final  String title;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  String fact;
/// «Коротко»: 2–3 предложения.
@override final  String explanationShort;
/// «Подробнее»: markdown до ~300 слов.
@override final  String explanationLong;
 final  List<SourceRef> _refs;
@override List<SourceRef> get refs {
  if (_refs is EqualUnmodifiableListView) return _refs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_refs);
}

@override final  Review review;
 final  List<Question> _questions;
@override List<Question> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


/// Create a copy of DeckItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeckItemCopyWith<_DeckItem> get copyWith => __$DeckItemCopyWithImpl<_DeckItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeckItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeckItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.fact, fact) || other.fact == fact)&&(identical(other.explanationShort, explanationShort) || other.explanationShort == explanationShort)&&(identical(other.explanationLong, explanationLong) || other.explanationLong == explanationLong)&&const DeepCollectionEquality().equals(other.refs, _refs)&&(identical(other.review, review) || other.review == review)&&const DeepCollectionEquality().equals(other.questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,const DeepCollectionEquality().hash(_tags),fact,explanationShort,explanationLong,const DeepCollectionEquality().hash(_refs),review,const DeepCollectionEquality().hash(_questions));
}

@override
String toString() {
    return 'DeckItem(id: $id, title: $title, tags: $tags, fact: $fact, explanationShort: $explanationShort, explanationLong: $explanationLong, refs: $refs, review: $review, questions: $questions)';
}


}

/// @nodoc
abstract mixin class _$DeckItemCopyWith<$Res> implements $DeckItemCopyWith<$Res> {
  factory _$DeckItemCopyWith(_DeckItem value, $Res Function(_DeckItem) _then) = __$DeckItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, List<String> tags, String fact, String explanationShort, String explanationLong, List<SourceRef> refs, Review review, List<Question> questions
});


@override $ReviewCopyWith<$Res> get review;

}
/// @nodoc
class __$DeckItemCopyWithImpl<$Res>
    implements _$DeckItemCopyWith<$Res> {
  __$DeckItemCopyWithImpl(this._self, this._then);

  final _DeckItem _self;
  final $Res Function(_DeckItem) _then;

/// Create a copy of DeckItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? tags = null,Object? fact = null,Object? explanationShort = null,Object? explanationLong = null,Object? refs = null,Object? review = null,Object? questions = null,}) {
  return _then(_DeckItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,fact: null == fact ? _self.fact : fact // ignore: cast_nullable_to_non_nullable
as String,explanationShort: null == explanationShort ? _self.explanationShort : explanationShort // ignore: cast_nullable_to_non_nullable
as String,explanationLong: null == explanationLong ? _self.explanationLong : explanationLong // ignore: cast_nullable_to_non_nullable
as String,refs: null == refs ? _self._refs : refs // ignore: cast_nullable_to_non_nullable
as List<SourceRef>,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as Review,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<Question>,
  ));
}

/// Create a copy of DeckItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReviewCopyWith<$Res> get review {
  
  return $ReviewCopyWith<$Res>(_self.review, (value) {
    return _then(_self.copyWith(review: value));
  });
}
}

// dart format on
