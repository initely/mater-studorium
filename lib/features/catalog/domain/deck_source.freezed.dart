// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'deck_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeckSource {

 String get id; String get title; String get url;/// Лицензия источника, например `CC BY-SA 4.0`. Обязательна (R8).
 String get license;
/// Create a copy of DeckSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeckSourceCopyWith<DeckSource> get copyWith => _$DeckSourceCopyWithImpl<DeckSource>(this as DeckSource, _$identity);

  /// Serializes this DeckSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeckSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeckSource&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.license, _this.license) || other.license == _this.license));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeckSource;
  return Object.hash(runtimeType,_this.id,_this.title,_this.url,_this.license);
}

@override
String toString() {
  final _this = this as DeckSource;
  return 'DeckSource(id: ${_this.id}, title: ${_this.title}, url: ${_this.url}, license: ${_this.license})';
}


}

/// @nodoc
abstract mixin class $DeckSourceCopyWith<$Res>  {
  factory $DeckSourceCopyWith(DeckSource value, $Res Function(DeckSource) _then) = _$DeckSourceCopyWithImpl;
@useResult
$Res call({
 String id, String title, String url, String license
});




}
/// @nodoc
class _$DeckSourceCopyWithImpl<$Res>
    implements $DeckSourceCopyWith<$Res> {
  _$DeckSourceCopyWithImpl(this._self, this._then);

  final DeckSource _self;
  final $Res Function(DeckSource) _then;

/// Create a copy of DeckSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? url = null,Object? license = null,}) {
  return _then(DeckSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,license: null == license ? _self.license : license // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeckSource].
extension DeckSourcePatterns on DeckSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeckSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeckSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeckSource value)  $default,){
final _that = this;
switch (_that) {
case _DeckSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeckSource value)?  $default,){
final _that = this;
switch (_that) {
case _DeckSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String url,  String license)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeckSource() when $default != null:
return $default(_that.id,_that.title,_that.url,_that.license);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String url,  String license)  $default,) {final _that = this;
switch (_that) {
case _DeckSource():
return $default(_that.id,_that.title,_that.url,_that.license);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String url,  String license)?  $default,) {final _that = this;
switch (_that) {
case _DeckSource() when $default != null:
return $default(_that.id,_that.title,_that.url,_that.license);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeckSource implements DeckSource {
  const _DeckSource({required this.id, required this.title, required this.url, required this.license});
  factory _DeckSource.fromJson(Map<String, dynamic> json) => _$DeckSourceFromJson(json);

@override final  String id;
@override final  String title;
@override final  String url;
/// Лицензия источника, например `CC BY-SA 4.0`. Обязательна (R8).
@override final  String license;

/// Create a copy of DeckSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeckSourceCopyWith<_DeckSource> get copyWith => __$DeckSourceCopyWithImpl<_DeckSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeckSourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeckSource&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.license, license) || other.license == license));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,url,license);
}

@override
String toString() {
    return 'DeckSource(id: $id, title: $title, url: $url, license: $license)';
}


}

/// @nodoc
abstract mixin class _$DeckSourceCopyWith<$Res> implements $DeckSourceCopyWith<$Res> {
  factory _$DeckSourceCopyWith(_DeckSource value, $Res Function(_DeckSource) _then) = __$DeckSourceCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String url, String license
});




}
/// @nodoc
class __$DeckSourceCopyWithImpl<$Res>
    implements _$DeckSourceCopyWith<$Res> {
  __$DeckSourceCopyWithImpl(this._self, this._then);

  final _DeckSource _self;
  final $Res Function(_DeckSource) _then;

/// Create a copy of DeckSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? url = null,Object? license = null,}) {
  return _then(_DeckSource(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,license: null == license ? _self.license : license // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
