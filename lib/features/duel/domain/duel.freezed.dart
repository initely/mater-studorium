// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'duel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Duel {

 String get id;/// Код приглашения; сервер отдаёт его только создателю.
 String? get code; String get deckId;/// Версия колоды, из которой выбраны вопросы.
 int get deckVersion;/// Ровно 5 id вопросов, зафиксированных при создании.
 List<String> get questionIds; DuelStatus get status;/// UTC.
 DateTime get createdAt;/// UTC; `createdAt` + 72 часа.
 DateTime get expiresAt; bool get isCreator;/// Соперник уже вошёл (у соперника — всегда `true`: «другой» — создатель).
 bool get otherJoined;/// Имя другого участника; `null`, если его нет или он не задал имя.
 String? get otherName;/// Когда я ответил на все вопросы (UTC); `null`, пока не ответил.
 DateTime? get myDoneAt;/// Когда на все вопросы ответил другой участник (UTC).
 DateTime? get otherDoneAt;
/// Create a copy of Duel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DuelCopyWith<Duel> get copyWith => _$DuelCopyWithImpl<Duel>(this as Duel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Duel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Duel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.deckId, _this.deckId) || other.deckId == _this.deckId)&&(identical(other.deckVersion, _this.deckVersion) || other.deckVersion == _this.deckVersion)&&const DeepCollectionEquality().equals(other.questionIds, _this.questionIds)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.isCreator, _this.isCreator) || other.isCreator == _this.isCreator)&&(identical(other.otherJoined, _this.otherJoined) || other.otherJoined == _this.otherJoined)&&(identical(other.otherName, _this.otherName) || other.otherName == _this.otherName)&&(identical(other.myDoneAt, _this.myDoneAt) || other.myDoneAt == _this.myDoneAt)&&(identical(other.otherDoneAt, _this.otherDoneAt) || other.otherDoneAt == _this.otherDoneAt));
}


@override
int get hashCode {
  final _this = this as Duel;
  return Object.hash(runtimeType,_this.id,_this.code,_this.deckId,_this.deckVersion,const DeepCollectionEquality().hash(_this.questionIds),_this.status,_this.createdAt,_this.expiresAt,_this.isCreator,_this.otherJoined,_this.otherName,_this.myDoneAt,_this.otherDoneAt);
}

@override
String toString() {
  final _this = this as Duel;
  return 'Duel(id: ${_this.id}, code: ${_this.code}, deckId: ${_this.deckId}, deckVersion: ${_this.deckVersion}, questionIds: ${_this.questionIds}, status: ${_this.status}, createdAt: ${_this.createdAt}, expiresAt: ${_this.expiresAt}, isCreator: ${_this.isCreator}, otherJoined: ${_this.otherJoined}, otherName: ${_this.otherName}, myDoneAt: ${_this.myDoneAt}, otherDoneAt: ${_this.otherDoneAt})';
}


}

/// @nodoc
abstract mixin class $DuelCopyWith<$Res>  {
  factory $DuelCopyWith(Duel value, $Res Function(Duel) _then) = _$DuelCopyWithImpl;
@useResult
$Res call({
 String id, String? code, String deckId, int deckVersion, List<String> questionIds, DuelStatus status, DateTime createdAt, DateTime expiresAt, bool isCreator, bool otherJoined, String? otherName, DateTime? myDoneAt, DateTime? otherDoneAt
});




}
/// @nodoc
class _$DuelCopyWithImpl<$Res>
    implements $DuelCopyWith<$Res> {
  _$DuelCopyWithImpl(this._self, this._then);

  final Duel _self;
  final $Res Function(Duel) _then;

/// Create a copy of Duel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = freezed,Object? deckId = null,Object? deckVersion = null,Object? questionIds = null,Object? status = null,Object? createdAt = null,Object? expiresAt = null,Object? isCreator = null,Object? otherJoined = null,Object? otherName = freezed,Object? myDoneAt = freezed,Object? otherDoneAt = freezed,}) {
  return _then(Duel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,deckVersion: null == deckVersion ? _self.deckVersion : deckVersion // ignore: cast_nullable_to_non_nullable
as int,questionIds: null == questionIds ? _self.questionIds : questionIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DuelStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,isCreator: null == isCreator ? _self.isCreator : isCreator // ignore: cast_nullable_to_non_nullable
as bool,otherJoined: null == otherJoined ? _self.otherJoined : otherJoined // ignore: cast_nullable_to_non_nullable
as bool,otherName: freezed == otherName ? _self.otherName : otherName // ignore: cast_nullable_to_non_nullable
as String?,myDoneAt: freezed == myDoneAt ? _self.myDoneAt : myDoneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,otherDoneAt: freezed == otherDoneAt ? _self.otherDoneAt : otherDoneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Duel].
extension DuelPatterns on Duel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Duel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Duel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Duel value)  $default,){
final _that = this;
switch (_that) {
case _Duel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Duel value)?  $default,){
final _that = this;
switch (_that) {
case _Duel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? code,  String deckId,  int deckVersion,  List<String> questionIds,  DuelStatus status,  DateTime createdAt,  DateTime expiresAt,  bool isCreator,  bool otherJoined,  String? otherName,  DateTime? myDoneAt,  DateTime? otherDoneAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Duel() when $default != null:
return $default(_that.id,_that.code,_that.deckId,_that.deckVersion,_that.questionIds,_that.status,_that.createdAt,_that.expiresAt,_that.isCreator,_that.otherJoined,_that.otherName,_that.myDoneAt,_that.otherDoneAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? code,  String deckId,  int deckVersion,  List<String> questionIds,  DuelStatus status,  DateTime createdAt,  DateTime expiresAt,  bool isCreator,  bool otherJoined,  String? otherName,  DateTime? myDoneAt,  DateTime? otherDoneAt)  $default,) {final _that = this;
switch (_that) {
case _Duel():
return $default(_that.id,_that.code,_that.deckId,_that.deckVersion,_that.questionIds,_that.status,_that.createdAt,_that.expiresAt,_that.isCreator,_that.otherJoined,_that.otherName,_that.myDoneAt,_that.otherDoneAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? code,  String deckId,  int deckVersion,  List<String> questionIds,  DuelStatus status,  DateTime createdAt,  DateTime expiresAt,  bool isCreator,  bool otherJoined,  String? otherName,  DateTime? myDoneAt,  DateTime? otherDoneAt)?  $default,) {final _that = this;
switch (_that) {
case _Duel() when $default != null:
return $default(_that.id,_that.code,_that.deckId,_that.deckVersion,_that.questionIds,_that.status,_that.createdAt,_that.expiresAt,_that.isCreator,_that.otherJoined,_that.otherName,_that.myDoneAt,_that.otherDoneAt);case _:
  return null;

}
}

}

/// @nodoc


class _Duel extends Duel {
  const _Duel({required this.id, this.code, required this.deckId, required this.deckVersion, required  List<String> questionIds, required this.status, required this.createdAt, required this.expiresAt, required this.isCreator, required this.otherJoined, this.otherName, this.myDoneAt, this.otherDoneAt}): _questionIds = questionIds,super._();
  

@override final  String id;
/// Код приглашения; сервер отдаёт его только создателю.
@override final  String? code;
@override final  String deckId;
/// Версия колоды, из которой выбраны вопросы.
@override final  int deckVersion;
/// Ровно 5 id вопросов, зафиксированных при создании.
 final  List<String> _questionIds;
/// Ровно 5 id вопросов, зафиксированных при создании.
@override List<String> get questionIds {
  if (_questionIds is EqualUnmodifiableListView) return _questionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questionIds);
}

@override final  DuelStatus status;
/// UTC.
@override final  DateTime createdAt;
/// UTC; `createdAt` + 72 часа.
@override final  DateTime expiresAt;
@override final  bool isCreator;
/// Соперник уже вошёл (у соперника — всегда `true`: «другой» — создатель).
@override final  bool otherJoined;
/// Имя другого участника; `null`, если его нет или он не задал имя.
@override final  String? otherName;
/// Когда я ответил на все вопросы (UTC); `null`, пока не ответил.
@override final  DateTime? myDoneAt;
/// Когда на все вопросы ответил другой участник (UTC).
@override final  DateTime? otherDoneAt;

/// Create a copy of Duel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DuelCopyWith<_Duel> get copyWith => __$DuelCopyWithImpl<_Duel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Duel&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.deckId, deckId) || other.deckId == deckId)&&(identical(other.deckVersion, deckVersion) || other.deckVersion == deckVersion)&&const DeepCollectionEquality().equals(other.questionIds, _questionIds)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.isCreator, isCreator) || other.isCreator == isCreator)&&(identical(other.otherJoined, otherJoined) || other.otherJoined == otherJoined)&&(identical(other.otherName, otherName) || other.otherName == otherName)&&(identical(other.myDoneAt, myDoneAt) || other.myDoneAt == myDoneAt)&&(identical(other.otherDoneAt, otherDoneAt) || other.otherDoneAt == otherDoneAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,code,deckId,deckVersion,const DeepCollectionEquality().hash(_questionIds),status,createdAt,expiresAt,isCreator,otherJoined,otherName,myDoneAt,otherDoneAt);
}

@override
String toString() {
    return 'Duel(id: $id, code: $code, deckId: $deckId, deckVersion: $deckVersion, questionIds: $questionIds, status: $status, createdAt: $createdAt, expiresAt: $expiresAt, isCreator: $isCreator, otherJoined: $otherJoined, otherName: $otherName, myDoneAt: $myDoneAt, otherDoneAt: $otherDoneAt)';
}


}

/// @nodoc
abstract mixin class _$DuelCopyWith<$Res> implements $DuelCopyWith<$Res> {
  factory _$DuelCopyWith(_Duel value, $Res Function(_Duel) _then) = __$DuelCopyWithImpl;
@override @useResult
$Res call({
 String id, String? code, String deckId, int deckVersion, List<String> questionIds, DuelStatus status, DateTime createdAt, DateTime expiresAt, bool isCreator, bool otherJoined, String? otherName, DateTime? myDoneAt, DateTime? otherDoneAt
});




}
/// @nodoc
class __$DuelCopyWithImpl<$Res>
    implements _$DuelCopyWith<$Res> {
  __$DuelCopyWithImpl(this._self, this._then);

  final _Duel _self;
  final $Res Function(_Duel) _then;

/// Create a copy of Duel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = freezed,Object? deckId = null,Object? deckVersion = null,Object? questionIds = null,Object? status = null,Object? createdAt = null,Object? expiresAt = null,Object? isCreator = null,Object? otherJoined = null,Object? otherName = freezed,Object? myDoneAt = freezed,Object? otherDoneAt = freezed,}) {
  return _then(_Duel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,deckVersion: null == deckVersion ? _self.deckVersion : deckVersion // ignore: cast_nullable_to_non_nullable
as int,questionIds: null == questionIds ? _self._questionIds : questionIds // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DuelStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,isCreator: null == isCreator ? _self.isCreator : isCreator // ignore: cast_nullable_to_non_nullable
as bool,otherJoined: null == otherJoined ? _self.otherJoined : otherJoined // ignore: cast_nullable_to_non_nullable
as bool,otherName: freezed == otherName ? _self.otherName : otherName // ignore: cast_nullable_to_non_nullable
as String?,myDoneAt: freezed == myDoneAt ? _self.myDoneAt : myDoneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,otherDoneAt: freezed == otherDoneAt ? _self.otherDoneAt : otherDoneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
