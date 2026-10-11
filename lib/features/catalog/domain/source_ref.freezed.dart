// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SourceRef {

 String get sourceId;/// Дословная цитата со страницы источника; её ищет `check_links`.
 String get quote;/// Страница недоступна скрипту (paywall и т.п.): `check_links` проверяет
/// только ответ 200.
 bool get quoteUnverifiable;
/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceRefCopyWith<SourceRef> get copyWith => _$SourceRefCopyWithImpl<SourceRef>(this as SourceRef, _$identity);

  /// Serializes this SourceRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SourceRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceRef&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.quote, _this.quote) || other.quote == _this.quote)&&(identical(other.quoteUnverifiable, _this.quoteUnverifiable) || other.quoteUnverifiable == _this.quoteUnverifiable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SourceRef;
  return Object.hash(runtimeType,_this.sourceId,_this.quote,_this.quoteUnverifiable);
}

@override
String toString() {
  final _this = this as SourceRef;
  return 'SourceRef(sourceId: ${_this.sourceId}, quote: ${_this.quote}, quoteUnverifiable: ${_this.quoteUnverifiable})';
}


}

/// @nodoc
abstract mixin class $SourceRefCopyWith<$Res>  {
  factory $SourceRefCopyWith(SourceRef value, $Res Function(SourceRef) _then) = _$SourceRefCopyWithImpl;
@useResult
$Res call({
 String sourceId, String quote, bool quoteUnverifiable
});




}
/// @nodoc
class _$SourceRefCopyWithImpl<$Res>
    implements $SourceRefCopyWith<$Res> {
  _$SourceRefCopyWithImpl(this._self, this._then);

  final SourceRef _self;
  final $Res Function(SourceRef) _then;

/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? quote = null,Object? quoteUnverifiable = null,}) {
  return _then(SourceRef(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,quote: null == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as String,quoteUnverifiable: null == quoteUnverifiable ? _self.quoteUnverifiable : quoteUnverifiable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceRef].
extension SourceRefPatterns on SourceRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceRef value)  $default,){
final _that = this;
switch (_that) {
case _SourceRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceRef value)?  $default,){
final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceId,  String quote,  bool quoteUnverifiable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
return $default(_that.sourceId,_that.quote,_that.quoteUnverifiable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceId,  String quote,  bool quoteUnverifiable)  $default,) {final _that = this;
switch (_that) {
case _SourceRef():
return $default(_that.sourceId,_that.quote,_that.quoteUnverifiable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceId,  String quote,  bool quoteUnverifiable)?  $default,) {final _that = this;
switch (_that) {
case _SourceRef() when $default != null:
return $default(_that.sourceId,_that.quote,_that.quoteUnverifiable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SourceRef implements SourceRef {
  const _SourceRef({required this.sourceId, required this.quote, this.quoteUnverifiable = false});
  factory _SourceRef.fromJson(Map<String, dynamic> json) => _$SourceRefFromJson(json);

@override final  String sourceId;
/// Дословная цитата со страницы источника; её ищет `check_links`.
@override final  String quote;
/// Страница недоступна скрипту (paywall и т.п.): `check_links` проверяет
/// только ответ 200.
@override@JsonKey() final  bool quoteUnverifiable;

/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceRefCopyWith<_SourceRef> get copyWith => __$SourceRefCopyWithImpl<_SourceRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SourceRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceRef&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.quoteUnverifiable, quoteUnverifiable) || other.quoteUnverifiable == quoteUnverifiable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,quote,quoteUnverifiable);
}

@override
String toString() {
    return 'SourceRef(sourceId: $sourceId, quote: $quote, quoteUnverifiable: $quoteUnverifiable)';
}


}

/// @nodoc
abstract mixin class _$SourceRefCopyWith<$Res> implements $SourceRefCopyWith<$Res> {
  factory _$SourceRefCopyWith(_SourceRef value, $Res Function(_SourceRef) _then) = __$SourceRefCopyWithImpl;
@override @useResult
$Res call({
 String sourceId, String quote, bool quoteUnverifiable
});




}
/// @nodoc
class __$SourceRefCopyWithImpl<$Res>
    implements _$SourceRefCopyWith<$Res> {
  __$SourceRefCopyWithImpl(this._self, this._then);

  final _SourceRef _self;
  final $Res Function(_SourceRef) _then;

/// Create a copy of SourceRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? quote = null,Object? quoteUnverifiable = null,}) {
  return _then(_SourceRef(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,quote: null == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as String,quoteUnverifiable: null == quoteUnverifiable ? _self.quoteUnverifiable : quoteUnverifiable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
