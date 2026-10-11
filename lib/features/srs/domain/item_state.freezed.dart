// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'item_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ItemState {

 String get itemId; String get deckId; DateTime get due; double get stability; double get difficulty; int get elapsedDays; int get scheduledDays; int get reps; int get lapses; SrsState get state; DateTime? get lastReview; String? get lastQuestionId;/// Для LWW-слияния при синхронизации.
 DateTime get updatedAt;
/// Create a copy of ItemState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ItemStateCopyWith<ItemState> get copyWith => _$ItemStateCopyWithImpl<ItemState>(this as ItemState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ItemState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ItemState&&(identical(other.itemId, _this.itemId) || other.itemId == _this.itemId)&&(identical(other.deckId, _this.deckId) || other.deckId == _this.deckId)&&(identical(other.due, _this.due) || other.due == _this.due)&&(identical(other.stability, _this.stability) || other.stability == _this.stability)&&(identical(other.difficulty, _this.difficulty) || other.difficulty == _this.difficulty)&&(identical(other.elapsedDays, _this.elapsedDays) || other.elapsedDays == _this.elapsedDays)&&(identical(other.scheduledDays, _this.scheduledDays) || other.scheduledDays == _this.scheduledDays)&&(identical(other.reps, _this.reps) || other.reps == _this.reps)&&(identical(other.lapses, _this.lapses) || other.lapses == _this.lapses)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.lastReview, _this.lastReview) || other.lastReview == _this.lastReview)&&(identical(other.lastQuestionId, _this.lastQuestionId) || other.lastQuestionId == _this.lastQuestionId)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as ItemState;
  return Object.hash(runtimeType,_this.itemId,_this.deckId,_this.due,_this.stability,_this.difficulty,_this.elapsedDays,_this.scheduledDays,_this.reps,_this.lapses,_this.state,_this.lastReview,_this.lastQuestionId,_this.updatedAt);
}

@override
String toString() {
  final _this = this as ItemState;
  return 'ItemState(itemId: ${_this.itemId}, deckId: ${_this.deckId}, due: ${_this.due}, stability: ${_this.stability}, difficulty: ${_this.difficulty}, elapsedDays: ${_this.elapsedDays}, scheduledDays: ${_this.scheduledDays}, reps: ${_this.reps}, lapses: ${_this.lapses}, state: ${_this.state}, lastReview: ${_this.lastReview}, lastQuestionId: ${_this.lastQuestionId}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ItemStateCopyWith<$Res>  {
  factory $ItemStateCopyWith(ItemState value, $Res Function(ItemState) _then) = _$ItemStateCopyWithImpl;
@useResult
$Res call({
 String itemId, String deckId, DateTime due, double stability, double difficulty, int elapsedDays, int scheduledDays, int reps, int lapses, SrsState state, DateTime? lastReview, String? lastQuestionId, DateTime updatedAt
});




}
/// @nodoc
class _$ItemStateCopyWithImpl<$Res>
    implements $ItemStateCopyWith<$Res> {
  _$ItemStateCopyWithImpl(this._self, this._then);

  final ItemState _self;
  final $Res Function(ItemState) _then;

/// Create a copy of ItemState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? itemId = null,Object? deckId = null,Object? due = null,Object? stability = null,Object? difficulty = null,Object? elapsedDays = null,Object? scheduledDays = null,Object? reps = null,Object? lapses = null,Object? state = null,Object? lastReview = freezed,Object? lastQuestionId = freezed,Object? updatedAt = null,}) {
  return _then(ItemState(
itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,due: null == due ? _self.due : due // ignore: cast_nullable_to_non_nullable
as DateTime,stability: null == stability ? _self.stability : stability // ignore: cast_nullable_to_non_nullable
as double,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,elapsedDays: null == elapsedDays ? _self.elapsedDays : elapsedDays // ignore: cast_nullable_to_non_nullable
as int,scheduledDays: null == scheduledDays ? _self.scheduledDays : scheduledDays // ignore: cast_nullable_to_non_nullable
as int,reps: null == reps ? _self.reps : reps // ignore: cast_nullable_to_non_nullable
as int,lapses: null == lapses ? _self.lapses : lapses // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SrsState,lastReview: freezed == lastReview ? _self.lastReview : lastReview // ignore: cast_nullable_to_non_nullable
as DateTime?,lastQuestionId: freezed == lastQuestionId ? _self.lastQuestionId : lastQuestionId // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ItemState].
extension ItemStatePatterns on ItemState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ItemState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ItemState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ItemState value)  $default,){
final _that = this;
switch (_that) {
case _ItemState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ItemState value)?  $default,){
final _that = this;
switch (_that) {
case _ItemState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String itemId,  String deckId,  DateTime due,  double stability,  double difficulty,  int elapsedDays,  int scheduledDays,  int reps,  int lapses,  SrsState state,  DateTime? lastReview,  String? lastQuestionId,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ItemState() when $default != null:
return $default(_that.itemId,_that.deckId,_that.due,_that.stability,_that.difficulty,_that.elapsedDays,_that.scheduledDays,_that.reps,_that.lapses,_that.state,_that.lastReview,_that.lastQuestionId,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String itemId,  String deckId,  DateTime due,  double stability,  double difficulty,  int elapsedDays,  int scheduledDays,  int reps,  int lapses,  SrsState state,  DateTime? lastReview,  String? lastQuestionId,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ItemState():
return $default(_that.itemId,_that.deckId,_that.due,_that.stability,_that.difficulty,_that.elapsedDays,_that.scheduledDays,_that.reps,_that.lapses,_that.state,_that.lastReview,_that.lastQuestionId,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String itemId,  String deckId,  DateTime due,  double stability,  double difficulty,  int elapsedDays,  int scheduledDays,  int reps,  int lapses,  SrsState state,  DateTime? lastReview,  String? lastQuestionId,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ItemState() when $default != null:
return $default(_that.itemId,_that.deckId,_that.due,_that.stability,_that.difficulty,_that.elapsedDays,_that.scheduledDays,_that.reps,_that.lapses,_that.state,_that.lastReview,_that.lastQuestionId,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ItemState implements ItemState {
  const _ItemState({required this.itemId, required this.deckId, required this.due, required this.stability, required this.difficulty, required this.elapsedDays, required this.scheduledDays, required this.reps, required this.lapses, required this.state, this.lastReview, this.lastQuestionId, required this.updatedAt});
  

@override final  String itemId;
@override final  String deckId;
@override final  DateTime due;
@override final  double stability;
@override final  double difficulty;
@override final  int elapsedDays;
@override final  int scheduledDays;
@override final  int reps;
@override final  int lapses;
@override final  SrsState state;
@override final  DateTime? lastReview;
@override final  String? lastQuestionId;
/// Для LWW-слияния при синхронизации.
@override final  DateTime updatedAt;

/// Create a copy of ItemState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ItemStateCopyWith<_ItemState> get copyWith => __$ItemStateCopyWithImpl<_ItemState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ItemState&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.deckId, deckId) || other.deckId == deckId)&&(identical(other.due, due) || other.due == due)&&(identical(other.stability, stability) || other.stability == stability)&&(identical(other.difficulty, difficulty) || other.difficulty == difficulty)&&(identical(other.elapsedDays, elapsedDays) || other.elapsedDays == elapsedDays)&&(identical(other.scheduledDays, scheduledDays) || other.scheduledDays == scheduledDays)&&(identical(other.reps, reps) || other.reps == reps)&&(identical(other.lapses, lapses) || other.lapses == lapses)&&(identical(other.state, state) || other.state == state)&&(identical(other.lastReview, lastReview) || other.lastReview == lastReview)&&(identical(other.lastQuestionId, lastQuestionId) || other.lastQuestionId == lastQuestionId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,itemId,deckId,due,stability,difficulty,elapsedDays,scheduledDays,reps,lapses,state,lastReview,lastQuestionId,updatedAt);
}

@override
String toString() {
    return 'ItemState(itemId: $itemId, deckId: $deckId, due: $due, stability: $stability, difficulty: $difficulty, elapsedDays: $elapsedDays, scheduledDays: $scheduledDays, reps: $reps, lapses: $lapses, state: $state, lastReview: $lastReview, lastQuestionId: $lastQuestionId, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ItemStateCopyWith<$Res> implements $ItemStateCopyWith<$Res> {
  factory _$ItemStateCopyWith(_ItemState value, $Res Function(_ItemState) _then) = __$ItemStateCopyWithImpl;
@override @useResult
$Res call({
 String itemId, String deckId, DateTime due, double stability, double difficulty, int elapsedDays, int scheduledDays, int reps, int lapses, SrsState state, DateTime? lastReview, String? lastQuestionId, DateTime updatedAt
});




}
/// @nodoc
class __$ItemStateCopyWithImpl<$Res>
    implements _$ItemStateCopyWith<$Res> {
  __$ItemStateCopyWithImpl(this._self, this._then);

  final _ItemState _self;
  final $Res Function(_ItemState) _then;

/// Create a copy of ItemState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? itemId = null,Object? deckId = null,Object? due = null,Object? stability = null,Object? difficulty = null,Object? elapsedDays = null,Object? scheduledDays = null,Object? reps = null,Object? lapses = null,Object? state = null,Object? lastReview = freezed,Object? lastQuestionId = freezed,Object? updatedAt = null,}) {
  return _then(_ItemState(
itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String,deckId: null == deckId ? _self.deckId : deckId // ignore: cast_nullable_to_non_nullable
as String,due: null == due ? _self.due : due // ignore: cast_nullable_to_non_nullable
as DateTime,stability: null == stability ? _self.stability : stability // ignore: cast_nullable_to_non_nullable
as double,difficulty: null == difficulty ? _self.difficulty : difficulty // ignore: cast_nullable_to_non_nullable
as double,elapsedDays: null == elapsedDays ? _self.elapsedDays : elapsedDays // ignore: cast_nullable_to_non_nullable
as int,scheduledDays: null == scheduledDays ? _self.scheduledDays : scheduledDays // ignore: cast_nullable_to_non_nullable
as int,reps: null == reps ? _self.reps : reps // ignore: cast_nullable_to_non_nullable
as int,lapses: null == lapses ? _self.lapses : lapses // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SrsState,lastReview: freezed == lastReview ? _self.lastReview : lastReview // ignore: cast_nullable_to_non_nullable
as DateTime?,lastQuestionId: freezed == lastQuestionId ? _self.lastQuestionId : lastQuestionId // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
