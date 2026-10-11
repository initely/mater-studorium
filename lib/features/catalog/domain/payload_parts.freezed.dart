// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payload_parts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McqOption {

 String get id; String get text;
/// Create a copy of McqOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McqOptionCopyWith<McqOption> get copyWith => _$McqOptionCopyWithImpl<McqOption>(this as McqOption, _$identity);

  /// Serializes this McqOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McqOption;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McqOption&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McqOption;
  return Object.hash(runtimeType,_this.id,_this.text);
}

@override
String toString() {
  final _this = this as McqOption;
  return 'McqOption(id: ${_this.id}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $McqOptionCopyWith<$Res>  {
  factory $McqOptionCopyWith(McqOption value, $Res Function(McqOption) _then) = _$McqOptionCopyWithImpl;
@useResult
$Res call({
 String id, String text
});




}
/// @nodoc
class _$McqOptionCopyWithImpl<$Res>
    implements $McqOptionCopyWith<$Res> {
  _$McqOptionCopyWithImpl(this._self, this._then);

  final McqOption _self;
  final $Res Function(McqOption) _then;

/// Create a copy of McqOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,}) {
  return _then(McqOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [McqOption].
extension McqOptionPatterns on McqOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _McqOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _McqOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _McqOption value)  $default,){
final _that = this;
switch (_that) {
case _McqOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _McqOption value)?  $default,){
final _that = this;
switch (_that) {
case _McqOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _McqOption() when $default != null:
return $default(_that.id,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text)  $default,) {final _that = this;
switch (_that) {
case _McqOption():
return $default(_that.id,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text)?  $default,) {final _that = this;
switch (_that) {
case _McqOption() when $default != null:
return $default(_that.id,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _McqOption implements McqOption {
  const _McqOption({required this.id, required this.text});
  factory _McqOption.fromJson(Map<String, dynamic> json) => _$McqOptionFromJson(json);

@override final  String id;
@override final  String text;

/// Create a copy of McqOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$McqOptionCopyWith<_McqOption> get copyWith => __$McqOptionCopyWithImpl<_McqOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McqOptionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McqOption&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text);
}

@override
String toString() {
    return 'McqOption(id: $id, text: $text)';
}


}

/// @nodoc
abstract mixin class _$McqOptionCopyWith<$Res> implements $McqOptionCopyWith<$Res> {
  factory _$McqOptionCopyWith(_McqOption value, $Res Function(_McqOption) _then) = __$McqOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String text
});




}
/// @nodoc
class __$McqOptionCopyWithImpl<$Res>
    implements _$McqOptionCopyWith<$Res> {
  __$McqOptionCopyWithImpl(this._self, this._then);

  final _McqOption _self;
  final $Res Function(_McqOption) _then;

/// Create a copy of McqOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,}) {
  return _then(_McqOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RubricPoint {

 String get id; String get text;/// Вес 1–3 во взвешенном среднем балла.
 int get weight;/// `miss` по обязательному пункту ограничивает вердикт значением
/// `partial`.
 bool get required;
/// Create a copy of RubricPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RubricPointCopyWith<RubricPoint> get copyWith => _$RubricPointCopyWithImpl<RubricPoint>(this as RubricPoint, _$identity);

  /// Serializes this RubricPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RubricPoint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RubricPoint&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.weight, _this.weight) || other.weight == _this.weight)&&(identical(other.required, _this.required) || other.required == _this.required));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RubricPoint;
  return Object.hash(runtimeType,_this.id,_this.text,_this.weight,_this.required);
}

@override
String toString() {
  final _this = this as RubricPoint;
  return 'RubricPoint(id: ${_this.id}, text: ${_this.text}, weight: ${_this.weight}, required: ${_this.required})';
}


}

/// @nodoc
abstract mixin class $RubricPointCopyWith<$Res>  {
  factory $RubricPointCopyWith(RubricPoint value, $Res Function(RubricPoint) _then) = _$RubricPointCopyWithImpl;
@useResult
$Res call({
 String id, String text, int weight, bool required
});




}
/// @nodoc
class _$RubricPointCopyWithImpl<$Res>
    implements $RubricPointCopyWith<$Res> {
  _$RubricPointCopyWithImpl(this._self, this._then);

  final RubricPoint _self;
  final $Res Function(RubricPoint) _then;

/// Create a copy of RubricPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? weight = null,Object? required = null,}) {
  return _then(RubricPoint(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as int,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RubricPoint].
extension RubricPointPatterns on RubricPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RubricPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RubricPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RubricPoint value)  $default,){
final _that = this;
switch (_that) {
case _RubricPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RubricPoint value)?  $default,){
final _that = this;
switch (_that) {
case _RubricPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  int weight,  bool required)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RubricPoint() when $default != null:
return $default(_that.id,_that.text,_that.weight,_that.required);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  int weight,  bool required)  $default,) {final _that = this;
switch (_that) {
case _RubricPoint():
return $default(_that.id,_that.text,_that.weight,_that.required);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  int weight,  bool required)?  $default,) {final _that = this;
switch (_that) {
case _RubricPoint() when $default != null:
return $default(_that.id,_that.text,_that.weight,_that.required);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RubricPoint implements RubricPoint {
  const _RubricPoint({required this.id, required this.text, required this.weight, required this.required});
  factory _RubricPoint.fromJson(Map<String, dynamic> json) => _$RubricPointFromJson(json);

@override final  String id;
@override final  String text;
/// Вес 1–3 во взвешенном среднем балла.
@override final  int weight;
/// `miss` по обязательному пункту ограничивает вердикт значением
/// `partial`.
@override final  bool required;

/// Create a copy of RubricPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RubricPointCopyWith<_RubricPoint> get copyWith => __$RubricPointCopyWithImpl<_RubricPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RubricPointToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RubricPoint&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.required, required) || other.required == required));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text,weight,required);
}

@override
String toString() {
    return 'RubricPoint(id: $id, text: $text, weight: $weight, required: $required)';
}


}

/// @nodoc
abstract mixin class _$RubricPointCopyWith<$Res> implements $RubricPointCopyWith<$Res> {
  factory _$RubricPointCopyWith(_RubricPoint value, $Res Function(_RubricPoint) _then) = __$RubricPointCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, int weight, bool required
});




}
/// @nodoc
class __$RubricPointCopyWithImpl<$Res>
    implements _$RubricPointCopyWith<$Res> {
  __$RubricPointCopyWithImpl(this._self, this._then);

  final _RubricPoint _self;
  final $Res Function(_RubricPoint) _then;

/// Create a copy of RubricPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? weight = null,Object? required = null,}) {
  return _then(_RubricPoint(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as int,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ClozeBlank {

 String get id;/// Допустимые ответы; первый показывается как правильный.
 List<String> get accepted;
/// Create a copy of ClozeBlank
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClozeBlankCopyWith<ClozeBlank> get copyWith => _$ClozeBlankCopyWithImpl<ClozeBlank>(this as ClozeBlank, _$identity);

  /// Serializes this ClozeBlank to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ClozeBlank;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClozeBlank&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.accepted, _this.accepted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClozeBlank;
  return Object.hash(runtimeType,_this.id,const DeepCollectionEquality().hash(_this.accepted));
}

@override
String toString() {
  final _this = this as ClozeBlank;
  return 'ClozeBlank(id: ${_this.id}, accepted: ${_this.accepted})';
}


}

/// @nodoc
abstract mixin class $ClozeBlankCopyWith<$Res>  {
  factory $ClozeBlankCopyWith(ClozeBlank value, $Res Function(ClozeBlank) _then) = _$ClozeBlankCopyWithImpl;
@useResult
$Res call({
 String id, List<String> accepted
});




}
/// @nodoc
class _$ClozeBlankCopyWithImpl<$Res>
    implements $ClozeBlankCopyWith<$Res> {
  _$ClozeBlankCopyWithImpl(this._self, this._then);

  final ClozeBlank _self;
  final $Res Function(ClozeBlank) _then;

/// Create a copy of ClozeBlank
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? accepted = null,}) {
  return _then(ClozeBlank(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ClozeBlank].
extension ClozeBlankPatterns on ClozeBlank {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClozeBlank value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClozeBlank() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClozeBlank value)  $default,){
final _that = this;
switch (_that) {
case _ClozeBlank():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClozeBlank value)?  $default,){
final _that = this;
switch (_that) {
case _ClozeBlank() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  List<String> accepted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClozeBlank() when $default != null:
return $default(_that.id,_that.accepted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  List<String> accepted)  $default,) {final _that = this;
switch (_that) {
case _ClozeBlank():
return $default(_that.id,_that.accepted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  List<String> accepted)?  $default,) {final _that = this;
switch (_that) {
case _ClozeBlank() when $default != null:
return $default(_that.id,_that.accepted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClozeBlank implements ClozeBlank {
  const _ClozeBlank({required this.id, required  List<String> accepted}): _accepted = accepted;
  factory _ClozeBlank.fromJson(Map<String, dynamic> json) => _$ClozeBlankFromJson(json);

@override final  String id;
/// Допустимые ответы; первый показывается как правильный.
 final  List<String> _accepted;
/// Допустимые ответы; первый показывается как правильный.
@override List<String> get accepted {
  if (_accepted is EqualUnmodifiableListView) return _accepted;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accepted);
}


/// Create a copy of ClozeBlank
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClozeBlankCopyWith<_ClozeBlank> get copyWith => __$ClozeBlankCopyWithImpl<_ClozeBlank>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClozeBlankToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClozeBlank&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.accepted, _accepted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_accepted));
}

@override
String toString() {
    return 'ClozeBlank(id: $id, accepted: $accepted)';
}


}

/// @nodoc
abstract mixin class _$ClozeBlankCopyWith<$Res> implements $ClozeBlankCopyWith<$Res> {
  factory _$ClozeBlankCopyWith(_ClozeBlank value, $Res Function(_ClozeBlank) _then) = __$ClozeBlankCopyWithImpl;
@override @useResult
$Res call({
 String id, List<String> accepted
});




}
/// @nodoc
class __$ClozeBlankCopyWithImpl<$Res>
    implements _$ClozeBlankCopyWith<$Res> {
  __$ClozeBlankCopyWithImpl(this._self, this._then);

  final _ClozeBlank _self;
  final $Res Function(_ClozeBlank) _then;

/// Create a copy of ClozeBlank
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? accepted = null,}) {
  return _then(_ClozeBlank(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accepted: null == accepted ? _self._accepted : accepted // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$OrderStep {

 String get id; String get text;
/// Create a copy of OrderStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderStepCopyWith<OrderStep> get copyWith => _$OrderStepCopyWithImpl<OrderStep>(this as OrderStep, _$identity);

  /// Serializes this OrderStep to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OrderStep;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderStep&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OrderStep;
  return Object.hash(runtimeType,_this.id,_this.text);
}

@override
String toString() {
  final _this = this as OrderStep;
  return 'OrderStep(id: ${_this.id}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $OrderStepCopyWith<$Res>  {
  factory $OrderStepCopyWith(OrderStep value, $Res Function(OrderStep) _then) = _$OrderStepCopyWithImpl;
@useResult
$Res call({
 String id, String text
});




}
/// @nodoc
class _$OrderStepCopyWithImpl<$Res>
    implements $OrderStepCopyWith<$Res> {
  _$OrderStepCopyWithImpl(this._self, this._then);

  final OrderStep _self;
  final $Res Function(OrderStep) _then;

/// Create a copy of OrderStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,}) {
  return _then(OrderStep(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderStep].
extension OrderStepPatterns on OrderStep {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderStep() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderStep value)  $default,){
final _that = this;
switch (_that) {
case _OrderStep():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderStep value)?  $default,){
final _that = this;
switch (_that) {
case _OrderStep() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderStep() when $default != null:
return $default(_that.id,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text)  $default,) {final _that = this;
switch (_that) {
case _OrderStep():
return $default(_that.id,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text)?  $default,) {final _that = this;
switch (_that) {
case _OrderStep() when $default != null:
return $default(_that.id,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderStep implements OrderStep {
  const _OrderStep({required this.id, required this.text});
  factory _OrderStep.fromJson(Map<String, dynamic> json) => _$OrderStepFromJson(json);

@override final  String id;
@override final  String text;

/// Create a copy of OrderStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderStepCopyWith<_OrderStep> get copyWith => __$OrderStepCopyWithImpl<_OrderStep>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderStepToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderStep&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,text);
}

@override
String toString() {
    return 'OrderStep(id: $id, text: $text)';
}


}

/// @nodoc
abstract mixin class _$OrderStepCopyWith<$Res> implements $OrderStepCopyWith<$Res> {
  factory _$OrderStepCopyWith(_OrderStep value, $Res Function(_OrderStep) _then) = __$OrderStepCopyWithImpl;
@override @useResult
$Res call({
 String id, String text
});




}
/// @nodoc
class __$OrderStepCopyWithImpl<$Res>
    implements _$OrderStepCopyWith<$Res> {
  __$OrderStepCopyWithImpl(this._self, this._then);

  final _OrderStep _self;
  final $Res Function(_OrderStep) _then;

/// Create a copy of OrderStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,}) {
  return _then(_OrderStep(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
