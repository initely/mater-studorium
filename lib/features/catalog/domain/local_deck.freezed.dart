// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'local_deck.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LocalDeck {

 String get id; int get version; String get title; String get topic; String get lang;/// Описание из JSON колоды; пусто у колод, скачанных до schema v3.
 String get description;/// UTC.
 DateTime get downloadedAt;
/// Create a copy of LocalDeck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalDeckCopyWith<LocalDeck> get copyWith => _$LocalDeckCopyWithImpl<LocalDeck>(this as LocalDeck, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LocalDeck;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalDeck&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.topic, _this.topic) || other.topic == _this.topic)&&(identical(other.lang, _this.lang) || other.lang == _this.lang)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.downloadedAt, _this.downloadedAt) || other.downloadedAt == _this.downloadedAt));
}


@override
int get hashCode {
  final _this = this as LocalDeck;
  return Object.hash(runtimeType,_this.id,_this.version,_this.title,_this.topic,_this.lang,_this.description,_this.downloadedAt);
}

@override
String toString() {
  final _this = this as LocalDeck;
  return 'LocalDeck(id: ${_this.id}, version: ${_this.version}, title: ${_this.title}, topic: ${_this.topic}, lang: ${_this.lang}, description: ${_this.description}, downloadedAt: ${_this.downloadedAt})';
}


}

/// @nodoc
abstract mixin class $LocalDeckCopyWith<$Res>  {
  factory $LocalDeckCopyWith(LocalDeck value, $Res Function(LocalDeck) _then) = _$LocalDeckCopyWithImpl;
@useResult
$Res call({
 String id, int version, String title, String topic, String lang, String description, DateTime downloadedAt
});




}
/// @nodoc
class _$LocalDeckCopyWithImpl<$Res>
    implements $LocalDeckCopyWith<$Res> {
  _$LocalDeckCopyWithImpl(this._self, this._then);

  final LocalDeck _self;
  final $Res Function(LocalDeck) _then;

/// Create a copy of LocalDeck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? version = null,Object? title = null,Object? topic = null,Object? lang = null,Object? description = null,Object? downloadedAt = null,}) {
  return _then(LocalDeck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,downloadedAt: null == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LocalDeck].
extension LocalDeckPatterns on LocalDeck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocalDeck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocalDeck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocalDeck value)  $default,){
final _that = this;
switch (_that) {
case _LocalDeck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocalDeck value)?  $default,){
final _that = this;
switch (_that) {
case _LocalDeck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int version,  String title,  String topic,  String lang,  String description,  DateTime downloadedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocalDeck() when $default != null:
return $default(_that.id,_that.version,_that.title,_that.topic,_that.lang,_that.description,_that.downloadedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int version,  String title,  String topic,  String lang,  String description,  DateTime downloadedAt)  $default,) {final _that = this;
switch (_that) {
case _LocalDeck():
return $default(_that.id,_that.version,_that.title,_that.topic,_that.lang,_that.description,_that.downloadedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int version,  String title,  String topic,  String lang,  String description,  DateTime downloadedAt)?  $default,) {final _that = this;
switch (_that) {
case _LocalDeck() when $default != null:
return $default(_that.id,_that.version,_that.title,_that.topic,_that.lang,_that.description,_that.downloadedAt);case _:
  return null;

}
}

}

/// @nodoc


class _LocalDeck implements LocalDeck {
  const _LocalDeck({required this.id, required this.version, required this.title, required this.topic, required this.lang, this.description = '', required this.downloadedAt});
  

@override final  String id;
@override final  int version;
@override final  String title;
@override final  String topic;
@override final  String lang;
/// Описание из JSON колоды; пусто у колод, скачанных до schema v3.
@override@JsonKey() final  String description;
/// UTC.
@override final  DateTime downloadedAt;

/// Create a copy of LocalDeck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocalDeckCopyWith<_LocalDeck> get copyWith => __$LocalDeckCopyWithImpl<_LocalDeck>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalDeck&&(identical(other.id, id) || other.id == id)&&(identical(other.version, version) || other.version == version)&&(identical(other.title, title) || other.title == title)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.description, description) || other.description == description)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,version,title,topic,lang,description,downloadedAt);
}

@override
String toString() {
    return 'LocalDeck(id: $id, version: $version, title: $title, topic: $topic, lang: $lang, description: $description, downloadedAt: $downloadedAt)';
}


}

/// @nodoc
abstract mixin class _$LocalDeckCopyWith<$Res> implements $LocalDeckCopyWith<$Res> {
  factory _$LocalDeckCopyWith(_LocalDeck value, $Res Function(_LocalDeck) _then) = __$LocalDeckCopyWithImpl;
@override @useResult
$Res call({
 String id, int version, String title, String topic, String lang, String description, DateTime downloadedAt
});




}
/// @nodoc
class __$LocalDeckCopyWithImpl<$Res>
    implements _$LocalDeckCopyWith<$Res> {
  __$LocalDeckCopyWithImpl(this._self, this._then);

  final _LocalDeck _self;
  final $Res Function(_LocalDeck) _then;

/// Create a copy of LocalDeck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? version = null,Object? title = null,Object? topic = null,Object? lang = null,Object? description = null,Object? downloadedAt = null,}) {
  return _then(_LocalDeck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,topic: null == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,downloadedAt: null == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
