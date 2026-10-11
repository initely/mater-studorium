// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'local_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LocalItem {

 String get id; String get deckId; String get title; String get fact; String get explanationShort; String get explanationLong; List<ItemRef> get refs;/// Знания нет в последней скачанной версии колоды; прогресс сохранён,
/// в очередь не попадает.
 bool get retired;
/// Create a copy of LocalItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalItemCopyWith<LocalItem> get copyWith => _$LocalItemCopyWithImpl<LocalItem>(this as LocalItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LocalItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.deckId, _this.deckId) || other.deckId == _this.deckId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.fact, _this.fact) || other.fact == _this.fact)&&(identical(other.explanationShort, _this.explanationShort) || other.explanationShort == _this.explanationShort)&&(identical(other.explanationLong, _this.explanationLong) || other.explanationLong == _this.explanationLong)&&const DeepCollectionEquality().equals(other.refs, _this.refs)&&(identical(other.retired, _this.retired) || other.retired == _this.retired));
}


@override
int get hashCode {
  final _this = this as LocalItem;
  return Object.hash(runtimeType,_this.id,_this.deckId,_this.title,_this.fact,_this.explanationShort,_this.explanationLong,const DeepCollectionEquality().hash(_this.refs),_this.retired);
}

@override
String toString() {
  final _this = this as LocalItem;
  return 'LocalItem(id: ${_this.id}, deckId: ${_this.deckId}, title: ${_this.title}, fact: ${_this.fact}, explanationShort: ${_this.explanationShort}, explanationLong: ${_this.explanationLong}, refs: ${_this.refs}, retired: ${_this.retired})';
}


}

/// @nodoc
abstract mixin class $LocalItemCopyWith<$Res>  {
  factory $LocalItemCopyWith(LocalItem value, $Res Function(LocalItem) _then) = _$LocalItemCopyWithImpl;
@useResult
$Res call({
 String id, String deckId, String title, String fact, String explanationShort, String explanationLong, List<ItemRef> refs, bool retired
});




}
/// @nodoc
class _$LocalItemCopyWithImpl<$Res>
    implements $LocalItemCopyWith<$Res> {
  _$LocalItemCopyWithImpl(this._self, this._then);

  final LocalItem _self;
  final $Res Function(LocalItem) _then;

/// Create a copy of LocalItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deckId = null,Object? title = null,Object? fact = null,Object? explanationShort = null,Object? explanationLong = null,Object? refs = null,Object? retired = null,}) {
  return _then(LocalItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fact: null == fact ? _self.fact : fact // ignore: cast_nullable_to_non_nullable
as String,explanationShort: null == explanationShort ? _self.explanationShort : explanationShort // ignore: cast_nullable_to_non_nullable
as String,explanationLong: null == explanationLong ? _self.explanationLong : explanationLong // ignore: cast_nullable_to_non_nullable
as String,refs: null == refs ? _self.refs : refs // ignore: cast_nullable_to_non_nullable
as List<ItemRef>,retired: null == retired ? _self.retired : retired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LocalItem].
extension LocalItemPatterns on LocalItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocalItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocalItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocalItem value)  $default,){
final _that = this;
switch (_that) {
case _LocalItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocalItem value)?  $default,){
final _that = this;
switch (_that) {
case _LocalItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deckId,  String title,  String fact,  String explanationShort,  String explanationLong,  List<ItemRef> refs,  bool retired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocalItem() when $default != null:
return $default(_that.id,_that.deckId,_that.title,_that.fact,_that.explanationShort,_that.explanationLong,_that.refs,_that.retired);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deckId,  String title,  String fact,  String explanationShort,  String explanationLong,  List<ItemRef> refs,  bool retired)  $default,) {final _that = this;
switch (_that) {
case _LocalItem():
return $default(_that.id,_that.deckId,_that.title,_that.fact,_that.explanationShort,_that.explanationLong,_that.refs,_that.retired);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deckId,  String title,  String fact,  String explanationShort,  String explanationLong,  List<ItemRef> refs,  bool retired)?  $default,) {final _that = this;
switch (_that) {
case _LocalItem() when $default != null:
return $default(_that.id,_that.deckId,_that.title,_that.fact,_that.explanationShort,_that.explanationLong,_that.refs,_that.retired);case _:
  return null;

}
}

}

/// @nodoc


class _LocalItem implements LocalItem {
  const _LocalItem({required this.id, required this.deckId, required this.title, required this.fact, required this.explanationShort, required this.explanationLong, required  List<ItemRef> refs, required this.retired}): _refs = refs;
  

@override final  String id;
@override final  String deckId;
@override final  String title;
@override final  String fact;
@override final  String explanationShort;
@override final  String explanationLong;
 final  List<ItemRef> _refs;
@override List<ItemRef> get refs {
  if (_refs is EqualUnmodifiableListView) return _refs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_refs);
}

/// Знания нет в последней скачанной версии колоды; прогресс сохранён,
/// в очередь не попадает.
@override final  bool retired;

/// Create a copy of LocalItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocalItemCopyWith<_LocalItem> get copyWith => __$LocalItemCopyWithImpl<_LocalItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalItem&&(identical(other.id, id) || other.id == id)&&(identical(other.deckId, deckId) || other.deckId == deckId)&&(identical(other.title, title) || other.title == title)&&(identical(other.fact, fact) || other.fact == fact)&&(identical(other.explanationShort, explanationShort) || other.explanationShort == explanationShort)&&(identical(other.explanationLong, explanationLong) || other.explanationLong == explanationLong)&&const DeepCollectionEquality().equals(other.refs, _refs)&&(identical(other.retired, retired) || other.retired == retired));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,deckId,title,fact,explanationShort,explanationLong,const DeepCollectionEquality().hash(_refs),retired);
}

@override
String toString() {
    return 'LocalItem(id: $id, deckId: $deckId, title: $title, fact: $fact, explanationShort: $explanationShort, explanationLong: $explanationLong, refs: $refs, retired: $retired)';
}


}

/// @nodoc
abstract mixin class _$LocalItemCopyWith<$Res> implements $LocalItemCopyWith<$Res> {
  factory _$LocalItemCopyWith(_LocalItem value, $Res Function(_LocalItem) _then) = __$LocalItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String deckId, String title, String fact, String explanationShort, String explanationLong, List<ItemRef> refs, bool retired
});




}
/// @nodoc
class __$LocalItemCopyWithImpl<$Res>
    implements _$LocalItemCopyWith<$Res> {
  __$LocalItemCopyWithImpl(this._self, this._then);

  final _LocalItem _self;
  final $Res Function(_LocalItem) _then;

/// Create a copy of LocalItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deckId = null,Object? title = null,Object? fact = null,Object? explanationShort = null,Object? explanationLong = null,Object? refs = null,Object? retired = null,}) {
  return _then(_LocalItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fact: null == fact ? _self.fact : fact // ignore: cast_nullable_to_non_nullable
as String,explanationShort: null == explanationShort ? _self.explanationShort : explanationShort // ignore: cast_nullable_to_non_nullable
as String,explanationLong: null == explanationLong ? _self.explanationLong : explanationLong // ignore: cast_nullable_to_non_nullable
as String,refs: null == refs ? _self._refs : refs // ignore: cast_nullable_to_non_nullable
as List<ItemRef>,retired: null == retired ? _self.retired : retired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
