// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
QuestionPayload _$QuestionPayloadFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'mcq':
          return McqPayload.fromJson(
            json
          );
                case 'flip':
          return FlipPayload.fromJson(
            json
          );
                case 'open':
          return OpenPayload.fromJson(
            json
          );
                case 'cloze':
          return ClozePayload.fromJson(
            json
          );
                case 'order':
          return OrderPayload.fromJson(
            json
          );
                case 'find_error':
          return FindErrorPayload.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'QuestionPayload',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$QuestionPayload {



  /// Serializes this QuestionPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestionPayload);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'QuestionPayload()';
}


}

/// @nodoc
class $QuestionPayloadCopyWith<$Res>  {
$QuestionPayloadCopyWith(QuestionPayload _, $Res Function(QuestionPayload) __);
}


/// Adds pattern-matching-related methods to [QuestionPayload].
extension QuestionPayloadPatterns on QuestionPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( McqPayload value)?  mcq,TResult Function( FlipPayload value)?  flip,TResult Function( OpenPayload value)?  open,TResult Function( ClozePayload value)?  cloze,TResult Function( OrderPayload value)?  order,TResult Function( FindErrorPayload value)?  findError,required TResult orElse(),}){
final _that = this;
switch (_that) {
case McqPayload() when mcq != null:
return mcq(_that);case FlipPayload() when flip != null:
return flip(_that);case OpenPayload() when open != null:
return open(_that);case ClozePayload() when cloze != null:
return cloze(_that);case OrderPayload() when order != null:
return order(_that);case FindErrorPayload() when findError != null:
return findError(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( McqPayload value)  mcq,required TResult Function( FlipPayload value)  flip,required TResult Function( OpenPayload value)  open,required TResult Function( ClozePayload value)  cloze,required TResult Function( OrderPayload value)  order,required TResult Function( FindErrorPayload value)  findError,}){
final _that = this;
switch (_that) {
case McqPayload():
return mcq(_that);case FlipPayload():
return flip(_that);case OpenPayload():
return open(_that);case ClozePayload():
return cloze(_that);case OrderPayload():
return order(_that);case FindErrorPayload():
return findError(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( McqPayload value)?  mcq,TResult? Function( FlipPayload value)?  flip,TResult? Function( OpenPayload value)?  open,TResult? Function( ClozePayload value)?  cloze,TResult? Function( OrderPayload value)?  order,TResult? Function( FindErrorPayload value)?  findError,}){
final _that = this;
switch (_that) {
case McqPayload() when mcq != null:
return mcq(_that);case FlipPayload() when flip != null:
return flip(_that);case OpenPayload() when open != null:
return open(_that);case ClozePayload() when cloze != null:
return cloze(_that);case OrderPayload() when order != null:
return order(_that);case FindErrorPayload() when findError != null:
return findError(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<McqOption> options,  List<String> correct,  bool multiple)?  mcq,TResult Function( String back)?  flip,TResult Function( String referenceAnswer,  List<RubricPoint> rubric)?  open,TResult Function( List<ClozeBlank> blanks)?  cloze,TResult Function( List<OrderStep> steps)?  order,TResult Function( FindErrorMode mode,  String? language,  List<String> lines,  List<int> errorLines,  Map<int, String> lineExplanations)?  findError,required TResult orElse(),}) {final _that = this;
switch (_that) {
case McqPayload() when mcq != null:
return mcq(_that.options,_that.correct,_that.multiple);case FlipPayload() when flip != null:
return flip(_that.back);case OpenPayload() when open != null:
return open(_that.referenceAnswer,_that.rubric);case ClozePayload() when cloze != null:
return cloze(_that.blanks);case OrderPayload() when order != null:
return order(_that.steps);case FindErrorPayload() when findError != null:
return findError(_that.mode,_that.language,_that.lines,_that.errorLines,_that.lineExplanations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<McqOption> options,  List<String> correct,  bool multiple)  mcq,required TResult Function( String back)  flip,required TResult Function( String referenceAnswer,  List<RubricPoint> rubric)  open,required TResult Function( List<ClozeBlank> blanks)  cloze,required TResult Function( List<OrderStep> steps)  order,required TResult Function( FindErrorMode mode,  String? language,  List<String> lines,  List<int> errorLines,  Map<int, String> lineExplanations)  findError,}) {final _that = this;
switch (_that) {
case McqPayload():
return mcq(_that.options,_that.correct,_that.multiple);case FlipPayload():
return flip(_that.back);case OpenPayload():
return open(_that.referenceAnswer,_that.rubric);case ClozePayload():
return cloze(_that.blanks);case OrderPayload():
return order(_that.steps);case FindErrorPayload():
return findError(_that.mode,_that.language,_that.lines,_that.errorLines,_that.lineExplanations);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<McqOption> options,  List<String> correct,  bool multiple)?  mcq,TResult? Function( String back)?  flip,TResult? Function( String referenceAnswer,  List<RubricPoint> rubric)?  open,TResult? Function( List<ClozeBlank> blanks)?  cloze,TResult? Function( List<OrderStep> steps)?  order,TResult? Function( FindErrorMode mode,  String? language,  List<String> lines,  List<int> errorLines,  Map<int, String> lineExplanations)?  findError,}) {final _that = this;
switch (_that) {
case McqPayload() when mcq != null:
return mcq(_that.options,_that.correct,_that.multiple);case FlipPayload() when flip != null:
return flip(_that.back);case OpenPayload() when open != null:
return open(_that.referenceAnswer,_that.rubric);case ClozePayload() when cloze != null:
return cloze(_that.blanks);case OrderPayload() when order != null:
return order(_that.steps);case FindErrorPayload() when findError != null:
return findError(_that.mode,_that.language,_that.lines,_that.errorLines,_that.lineExplanations);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class McqPayload extends QuestionPayload {
  const McqPayload({required  List<McqOption> options, required  List<String> correct, required this.multiple,  String? $type}): _options = options,_correct = correct,$type = $type ?? 'mcq',super._();
  factory McqPayload.fromJson(Map<String, dynamic> json) => _$McqPayloadFromJson(json);

 final  List<McqOption> _options;
 List<McqOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

 final  List<String> _correct;
 List<String> get correct {
  if (_correct is EqualUnmodifiableListView) return _correct;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_correct);
}

/// `false` — ровно один верный вариант.
 final  bool multiple;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$McqPayloadCopyWith<McqPayload> get copyWith => _$McqPayloadCopyWithImpl<McqPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$McqPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McqPayload&&const DeepCollectionEquality().equals(other.options, _options)&&const DeepCollectionEquality().equals(other.correct, _correct)&&(identical(other.multiple, multiple) || other.multiple == multiple));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_options),const DeepCollectionEquality().hash(_correct),multiple);
}

@override
String toString() {
    return 'QuestionPayload.mcq(options: $options, correct: $correct, multiple: $multiple)';
}


}

/// @nodoc
abstract mixin class $McqPayloadCopyWith<$Res> implements $QuestionPayloadCopyWith<$Res> {
  factory $McqPayloadCopyWith(McqPayload value, $Res Function(McqPayload) _then) = _$McqPayloadCopyWithImpl;
@useResult
$Res call({
 List<McqOption> options, List<String> correct, bool multiple
});




}
/// @nodoc
class _$McqPayloadCopyWithImpl<$Res>
    implements $McqPayloadCopyWith<$Res> {
  _$McqPayloadCopyWithImpl(this._self, this._then);

  final McqPayload _self;
  final $Res Function(McqPayload) _then;

/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,Object? correct = null,Object? multiple = null,}) {
  return _then(McqPayload(
options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<McqOption>,correct: null == correct ? _self._correct : correct // ignore: cast_nullable_to_non_nullable
as List<String>,multiple: null == multiple ? _self.multiple : multiple // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FlipPayload extends QuestionPayload {
  const FlipPayload({required this.back,  String? $type}): $type = $type ?? 'flip',super._();
  factory FlipPayload.fromJson(Map<String, dynamic> json) => _$FlipPayloadFromJson(json);

 final  String back;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlipPayloadCopyWith<FlipPayload> get copyWith => _$FlipPayloadCopyWithImpl<FlipPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlipPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FlipPayload&&(identical(other.back, back) || other.back == back));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,back);
}

@override
String toString() {
    return 'QuestionPayload.flip(back: $back)';
}


}

/// @nodoc
abstract mixin class $FlipPayloadCopyWith<$Res> implements $QuestionPayloadCopyWith<$Res> {
  factory $FlipPayloadCopyWith(FlipPayload value, $Res Function(FlipPayload) _then) = _$FlipPayloadCopyWithImpl;
@useResult
$Res call({
 String back
});




}
/// @nodoc
class _$FlipPayloadCopyWithImpl<$Res>
    implements $FlipPayloadCopyWith<$Res> {
  _$FlipPayloadCopyWithImpl(this._self, this._then);

  final FlipPayload _self;
  final $Res Function(FlipPayload) _then;

/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? back = null,}) {
  return _then(FlipPayload(
back: null == back ? _self.back : back // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class OpenPayload extends QuestionPayload {
  const OpenPayload({required this.referenceAnswer, required  List<RubricPoint> rubric,  String? $type}): _rubric = rubric,$type = $type ?? 'open',super._();
  factory OpenPayload.fromJson(Map<String, dynamic> json) => _$OpenPayloadFromJson(json);

/// Эталон в 1–3 предложения.
 final  String referenceAnswer;
/// 2–5 пунктов, хотя бы один обязательный.
 final  List<RubricPoint> _rubric;
/// 2–5 пунктов, хотя бы один обязательный.
 List<RubricPoint> get rubric {
  if (_rubric is EqualUnmodifiableListView) return _rubric;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rubric);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenPayloadCopyWith<OpenPayload> get copyWith => _$OpenPayloadCopyWithImpl<OpenPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenPayload&&(identical(other.referenceAnswer, referenceAnswer) || other.referenceAnswer == referenceAnswer)&&const DeepCollectionEquality().equals(other.rubric, _rubric));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,referenceAnswer,const DeepCollectionEquality().hash(_rubric));
}

@override
String toString() {
    return 'QuestionPayload.open(referenceAnswer: $referenceAnswer, rubric: $rubric)';
}


}

/// @nodoc
abstract mixin class $OpenPayloadCopyWith<$Res> implements $QuestionPayloadCopyWith<$Res> {
  factory $OpenPayloadCopyWith(OpenPayload value, $Res Function(OpenPayload) _then) = _$OpenPayloadCopyWithImpl;
@useResult
$Res call({
 String referenceAnswer, List<RubricPoint> rubric
});




}
/// @nodoc
class _$OpenPayloadCopyWithImpl<$Res>
    implements $OpenPayloadCopyWith<$Res> {
  _$OpenPayloadCopyWithImpl(this._self, this._then);

  final OpenPayload _self;
  final $Res Function(OpenPayload) _then;

/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? referenceAnswer = null,Object? rubric = null,}) {
  return _then(OpenPayload(
referenceAnswer: null == referenceAnswer ? _self.referenceAnswer : referenceAnswer // ignore: cast_nullable_to_non_nullable
as String,rubric: null == rubric ? _self._rubric : rubric // ignore: cast_nullable_to_non_nullable
as List<RubricPoint>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ClozePayload extends QuestionPayload {
  const ClozePayload({required  List<ClozeBlank> blanks,  String? $type}): _blanks = blanks,$type = $type ?? 'cloze',super._();
  factory ClozePayload.fromJson(Map<String, dynamic> json) => _$ClozePayloadFromJson(json);

 final  List<ClozeBlank> _blanks;
 List<ClozeBlank> get blanks {
  if (_blanks is EqualUnmodifiableListView) return _blanks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blanks);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClozePayloadCopyWith<ClozePayload> get copyWith => _$ClozePayloadCopyWithImpl<ClozePayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClozePayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ClozePayload&&const DeepCollectionEquality().equals(other.blanks, _blanks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_blanks));
}

@override
String toString() {
    return 'QuestionPayload.cloze(blanks: $blanks)';
}


}

/// @nodoc
abstract mixin class $ClozePayloadCopyWith<$Res> implements $QuestionPayloadCopyWith<$Res> {
  factory $ClozePayloadCopyWith(ClozePayload value, $Res Function(ClozePayload) _then) = _$ClozePayloadCopyWithImpl;
@useResult
$Res call({
 List<ClozeBlank> blanks
});




}
/// @nodoc
class _$ClozePayloadCopyWithImpl<$Res>
    implements $ClozePayloadCopyWith<$Res> {
  _$ClozePayloadCopyWithImpl(this._self, this._then);

  final ClozePayload _self;
  final $Res Function(ClozePayload) _then;

/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? blanks = null,}) {
  return _then(ClozePayload(
blanks: null == blanks ? _self._blanks : blanks // ignore: cast_nullable_to_non_nullable
as List<ClozeBlank>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class OrderPayload extends QuestionPayload {
  const OrderPayload({required  List<OrderStep> steps,  String? $type}): _steps = steps,$type = $type ?? 'order',super._();
  factory OrderPayload.fromJson(Map<String, dynamic> json) => _$OrderPayloadFromJson(json);

 final  List<OrderStep> _steps;
 List<OrderStep> get steps {
  if (_steps is EqualUnmodifiableListView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_steps);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderPayloadCopyWith<OrderPayload> get copyWith => _$OrderPayloadCopyWithImpl<OrderPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderPayload&&const DeepCollectionEquality().equals(other.steps, _steps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_steps));
}

@override
String toString() {
    return 'QuestionPayload.order(steps: $steps)';
}


}

/// @nodoc
abstract mixin class $OrderPayloadCopyWith<$Res> implements $QuestionPayloadCopyWith<$Res> {
  factory $OrderPayloadCopyWith(OrderPayload value, $Res Function(OrderPayload) _then) = _$OrderPayloadCopyWithImpl;
@useResult
$Res call({
 List<OrderStep> steps
});




}
/// @nodoc
class _$OrderPayloadCopyWithImpl<$Res>
    implements $OrderPayloadCopyWith<$Res> {
  _$OrderPayloadCopyWithImpl(this._self, this._then);

  final OrderPayload _self;
  final $Res Function(OrderPayload) _then;

/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? steps = null,}) {
  return _then(OrderPayload(
steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as List<OrderStep>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FindErrorPayload extends QuestionPayload {
  const FindErrorPayload({required this.mode, this.language, required  List<String> lines, required  List<int> errorLines, required  Map<int, String> lineExplanations,  String? $type}): _lines = lines,_errorLines = errorLines,_lineExplanations = lineExplanations,$type = $type ?? 'find_error',super._();
  factory FindErrorPayload.fromJson(Map<String, dynamic> json) => _$FindErrorPayloadFromJson(json);

 final  FindErrorMode mode;
/// Язык подсветки для [FindErrorMode.code].
 final  String? language;
 final  List<String> _lines;
 List<String> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

 final  List<int> _errorLines;
 List<int> get errorLines {
  if (_errorLines is EqualUnmodifiableListView) return _errorLines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_errorLines);
}

/// Пояснения по номеру строки, есть для каждой строки из [errorLines].
 final  Map<int, String> _lineExplanations;
/// Пояснения по номеру строки, есть для каждой строки из [errorLines].
 Map<int, String> get lineExplanations {
  if (_lineExplanations is EqualUnmodifiableMapView) return _lineExplanations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_lineExplanations);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FindErrorPayloadCopyWith<FindErrorPayload> get copyWith => _$FindErrorPayloadCopyWithImpl<FindErrorPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FindErrorPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FindErrorPayload&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.language, language) || other.language == language)&&const DeepCollectionEquality().equals(other.lines, _lines)&&const DeepCollectionEquality().equals(other.errorLines, _errorLines)&&const DeepCollectionEquality().equals(other.lineExplanations, _lineExplanations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mode,language,const DeepCollectionEquality().hash(_lines),const DeepCollectionEquality().hash(_errorLines),const DeepCollectionEquality().hash(_lineExplanations));
}

@override
String toString() {
    return 'QuestionPayload.findError(mode: $mode, language: $language, lines: $lines, errorLines: $errorLines, lineExplanations: $lineExplanations)';
}


}

/// @nodoc
abstract mixin class $FindErrorPayloadCopyWith<$Res> implements $QuestionPayloadCopyWith<$Res> {
  factory $FindErrorPayloadCopyWith(FindErrorPayload value, $Res Function(FindErrorPayload) _then) = _$FindErrorPayloadCopyWithImpl;
@useResult
$Res call({
 FindErrorMode mode, String? language, List<String> lines, List<int> errorLines, Map<int, String> lineExplanations
});




}
/// @nodoc
class _$FindErrorPayloadCopyWithImpl<$Res>
    implements $FindErrorPayloadCopyWith<$Res> {
  _$FindErrorPayloadCopyWithImpl(this._self, this._then);

  final FindErrorPayload _self;
  final $Res Function(FindErrorPayload) _then;

/// Create a copy of QuestionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? language = freezed,Object? lines = null,Object? errorLines = null,Object? lineExplanations = null,}) {
  return _then(FindErrorPayload(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as FindErrorMode,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<String>,errorLines: null == errorLines ? _self._errorLines : errorLines // ignore: cast_nullable_to_non_nullable
as List<int>,lineExplanations: null == lineExplanations ? _self._lineExplanations : lineExplanations // ignore: cast_nullable_to_non_nullable
as Map<int, String>,
  ));
}


}

// dart format on
