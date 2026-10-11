// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'item_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ItemRef {

 String get sourceId; String get quote; bool get quoteUnverifiable; String get sourceTitle; String get url; String get license;
/// Create a copy of ItemRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ItemRefCopyWith<ItemRef> get copyWith => _$ItemRefCopyWithImpl<ItemRef>(this as ItemRef, _$identity);

  /// Serializes this ItemRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ItemRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ItemRef&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.quote, _this.quote) || other.quote == _this.quote)&&(identical(other.quoteUnverifiable, _this.quoteUnverifiable) || other.quoteUnverifiable == _this.quoteUnverifiable)&&(identical(other.sourceTitle, _this.sourceTitle) || other.sourceTitle == _this.sourceTitle)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.license, _this.license) || other.license == _this.license));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ItemRef;
  return Object.hash(runtimeType,_this.sourceId,_this.quote,_this.quoteUnverifiable,_this.sourceTitle,_this.url,_this.license);
}

@override
String toString() {
  final _this = this as ItemRef;
  return 'ItemRef(sourceId: ${_this.sourceId}, quote: ${_this.quote}, quoteUnverifiable: ${_this.quoteUnverifiable}, sourceTitle: ${_this.sourceTitle}, url: ${_this.url}, license: ${_this.license})';
}


}

/// @nodoc
abstract mixin class $ItemRefCopyWith<$Res>  {
  factory $ItemRefCopyWith(ItemRef value, $Res Function(ItemRef) _then) = _$ItemRefCopyWithImpl;
@useResult
$Res call({
 String sourceId, String quote, bool quoteUnverifiable, String sourceTitle, String url, String license
});




}
/// @nodoc
class _$ItemRefCopyWithImpl<$Res>
    implements $ItemRefCopyWith<$Res> {
  _$ItemRefCopyWithImpl(this._self, this._then);

  final ItemRef _self;
  final $Res Function(ItemRef) _then;

/// Create a copy of ItemRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? quote = null,Object? quoteUnverifiable = null,Object? sourceTitle = null,Object? url = null,Object? license = null,}) {
  return _then(ItemRef(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,quote: null == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as String,quoteUnverifiable: null == quoteUnverifiable ? _self.quoteUnverifiable : quoteUnverifiable // ignore: cast_nullable_to_non_nullable
as bool,sourceTitle: null == sourceTitle ? _self.sourceTitle : sourceTitle // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,license: null == license ? _self.license : license // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ItemRef].
extension ItemRefPatterns on ItemRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ItemRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ItemRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ItemRef value)  $default,){
final _that = this;
switch (_that) {
case _ItemRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ItemRef value)?  $default,){
final _that = this;
switch (_that) {
case _ItemRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceId,  String quote,  bool quoteUnverifiable,  String sourceTitle,  String url,  String license)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ItemRef() when $default != null:
return $default(_that.sourceId,_that.quote,_that.quoteUnverifiable,_that.sourceTitle,_that.url,_that.license);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceId,  String quote,  bool quoteUnverifiable,  String sourceTitle,  String url,  String license)  $default,) {final _that = this;
switch (_that) {
case _ItemRef():
return $default(_that.sourceId,_that.quote,_that.quoteUnverifiable,_that.sourceTitle,_that.url,_that.license);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceId,  String quote,  bool quoteUnverifiable,  String sourceTitle,  String url,  String license)?  $default,) {final _that = this;
switch (_that) {
case _ItemRef() when $default != null:
return $default(_that.sourceId,_that.quote,_that.quoteUnverifiable,_that.sourceTitle,_that.url,_that.license);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ItemRef implements ItemRef {
  const _ItemRef({required this.sourceId, required this.quote, this.quoteUnverifiable = false, required this.sourceTitle, required this.url, required this.license});
  factory _ItemRef.fromJson(Map<String, dynamic> json) => _$ItemRefFromJson(json);

@override final  String sourceId;
@override final  String quote;
@override@JsonKey() final  bool quoteUnverifiable;
@override final  String sourceTitle;
@override final  String url;
@override final  String license;

/// Create a copy of ItemRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ItemRefCopyWith<_ItemRef> get copyWith => __$ItemRefCopyWithImpl<_ItemRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ItemRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ItemRef&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.quoteUnverifiable, quoteUnverifiable) || other.quoteUnverifiable == quoteUnverifiable)&&(identical(other.sourceTitle, sourceTitle) || other.sourceTitle == sourceTitle)&&(identical(other.url, url) || other.url == url)&&(identical(other.license, license) || other.license == license));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,quote,quoteUnverifiable,sourceTitle,url,license);
}

@override
String toString() {
    return 'ItemRef(sourceId: $sourceId, quote: $quote, quoteUnverifiable: $quoteUnverifiable, sourceTitle: $sourceTitle, url: $url, license: $license)';
}


}

/// @nodoc
abstract mixin class _$ItemRefCopyWith<$Res> implements $ItemRefCopyWith<$Res> {
  factory _$ItemRefCopyWith(_ItemRef value, $Res Function(_ItemRef) _then) = __$ItemRefCopyWithImpl;
@override @useResult
$Res call({
 String sourceId, String quote, bool quoteUnverifiable, String sourceTitle, String url, String license
});




}
/// @nodoc
class __$ItemRefCopyWithImpl<$Res>
    implements _$ItemRefCopyWith<$Res> {
  __$ItemRefCopyWithImpl(this._self, this._then);

  final _ItemRef _self;
  final $Res Function(_ItemRef) _then;

/// Create a copy of ItemRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? quote = null,Object? quoteUnverifiable = null,Object? sourceTitle = null,Object? url = null,Object? license = null,}) {
  return _then(_ItemRef(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,quote: null == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as String,quoteUnverifiable: null == quoteUnverifiable ? _self.quoteUnverifiable : quoteUnverifiable // ignore: cast_nullable_to_non_nullable
as bool,sourceTitle: null == sourceTitle ? _self.sourceTitle : sourceTitle // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,license: null == license ? _self.license : license // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
