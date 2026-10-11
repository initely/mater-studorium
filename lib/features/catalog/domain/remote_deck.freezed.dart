// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remote_deck.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RemoteDeck {

 String get id; String get title; String get topic; String get lang; int get version; int get itemCount;/// Путь файла внутри bucket `decks`: `<id>/v<version>.json`.
 String get storagePath;
/// Create a copy of RemoteDeck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDeckCopyWith<RemoteDeck> get copyWith => _$RemoteDeckCopyWithImpl<RemoteDeck>(this as RemoteDeck, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RemoteDeck;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDeck&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.topic, _this.topic) || other.topic == _this.topic)&&(identical(other.lang, _this.lang) || other.lang == _this.lang)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.itemCount, _this.itemCount) || other.itemCount == _this.itemCount)&&(identical(other.storagePath, _this.storagePath) || other.storagePath == _this.storagePath));
}


@override
int get hashCode {
  final _this = this as RemoteDeck;
  return Object.hash(runtimeType,_this.id,_this.title,_this.topic,_this.lang,_this.version,_this.itemCount,_this.storagePath);
}

@override
String toString() {
  final _this = this as RemoteDeck;
  return 'RemoteDeck(id: ${_this.id}, title: ${_this.title}, topic: ${_this.topic}, lang: ${_this.lang}, version: ${_this.version}, itemCount: ${_this.itemCount}, storagePath: ${_this.storagePath})';
}


}

/// @nodoc
abstract mixin class $RemoteDeckCopyWith<$Res>  {
  factory $RemoteDeckCopyWith(RemoteDeck value, $Res Function(RemoteDeck) _then) = _$RemoteDeckCopyWithImpl;
@useResult
$Res call({
 String id, String title, String topic, String lang, int version, int itemCount, String storagePath
});




}
/// @nodoc
class _$RemoteDeckCopyWithImpl<$Res>
    implements $RemoteDeckCopyWith<$Res> {
  _$RemoteDeckCopyWithImpl(this._self, this._then);

  final RemoteDeck _self;
  final $Res Function(RemoteDeck) _then;

/// Create a copy of RemoteDeck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? topic = null,Object? lang = null,Object? version = null,Object? itemCount = null,Object? storagePath = null,}) {
  return _then(RemoteDeck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RemoteDeck].
extension RemoteDeckPatterns on RemoteDeck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemoteDeck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemoteDeck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemoteDeck value)  $default,){
final _that = this;
switch (_that) {
case _RemoteDeck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemoteDeck value)?  $default,){
final _that = this;
switch (_that) {
case _RemoteDeck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String topic,  String lang,  int version,  int itemCount,  String storagePath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemoteDeck() when $default != null:
return $default(_that.id,_that.title,_that.topic,_that.lang,_that.version,_that.itemCount,_that.storagePath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String topic,  String lang,  int version,  int itemCount,  String storagePath)  $default,) {final _that = this;
switch (_that) {
case _RemoteDeck():
return $default(_that.id,_that.title,_that.topic,_that.lang,_that.version,_that.itemCount,_that.storagePath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String topic,  String lang,  int version,  int itemCount,  String storagePath)?  $default,) {final _that = this;
switch (_that) {
case _RemoteDeck() when $default != null:
return $default(_that.id,_that.title,_that.topic,_that.lang,_that.version,_that.itemCount,_that.storagePath);case _:
  return null;

}
}

}

/// @nodoc


class _RemoteDeck implements RemoteDeck {
  const _RemoteDeck({required this.id, required this.title, required this.topic, required this.lang, required this.version, required this.itemCount, required this.storagePath});
  

@override final  String id;
@override final  String title;
@override final  String topic;
@override final  String lang;
@override final  int version;
@override final  int itemCount;
/// Путь файла внутри bucket `decks`: `<id>/v<version>.json`.
@override final  String storagePath;

/// Create a copy of RemoteDeck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoteDeckCopyWith<_RemoteDeck> get copyWith => __$RemoteDeckCopyWithImpl<_RemoteDeck>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoteDeck&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.version, version) || other.version == version)&&(identical(other.itemCount, itemCount) || other.itemCount == itemCount)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,topic,lang,version,itemCount,storagePath);
}

@override
String toString() {
    return 'RemoteDeck(id: $id, title: $title, topic: $topic, lang: $lang, version: $version, itemCount: $itemCount, storagePath: $storagePath)';
}


}

/// @nodoc
abstract mixin class _$RemoteDeckCopyWith<$Res> implements $RemoteDeckCopyWith<$Res> {
  factory _$RemoteDeckCopyWith(_RemoteDeck value, $Res Function(_RemoteDeck) _then) = __$RemoteDeckCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String topic, String lang, int version, int itemCount, String storagePath
});




}
/// @nodoc
class __$RemoteDeckCopyWithImpl<$Res>
    implements _$RemoteDeckCopyWith<$Res> {
  __$RemoteDeckCopyWithImpl(this._self, this._then);

  final _RemoteDeck _self;
  final $Res Function(_RemoteDeck) _then;

/// Create a copy of RemoteDeck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? topic = null,Object? lang = null,Object? version = null,Object? itemCount = null,Object? storagePath = null,}) {
  return _then(_RemoteDeck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
