// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CourseManifest {

 String get id; String get title; String get language; String get description; String get version; String get hash; String? get exportDate; List<String> get lessons;
/// Create a copy of CourseManifest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CourseManifestCopyWith<CourseManifest> get copyWith => _$CourseManifestCopyWithImpl<CourseManifest>(this as CourseManifest, _$identity);

  /// Serializes this CourseManifest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CourseManifest&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.language, language) || other.language == language)&&(identical(other.description, description) || other.description == description)&&(identical(other.version, version) || other.version == version)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.exportDate, exportDate) || other.exportDate == exportDate)&&const DeepCollectionEquality().equals(other.lessons, lessons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,language,description,version,hash,exportDate,const DeepCollectionEquality().hash(lessons));

@override
String toString() {
  return 'CourseManifest(id: $id, title: $title, language: $language, description: $description, version: $version, hash: $hash, exportDate: $exportDate, lessons: $lessons)';
}


}

/// @nodoc
abstract mixin class $CourseManifestCopyWith<$Res>  {
  factory $CourseManifestCopyWith(CourseManifest value, $Res Function(CourseManifest) _then) = _$CourseManifestCopyWithImpl;
@useResult
$Res call({
 String id, String title, String language, String description, String version, String hash, String? exportDate, List<String> lessons
});




}
/// @nodoc
class _$CourseManifestCopyWithImpl<$Res>
    implements $CourseManifestCopyWith<$Res> {
  _$CourseManifestCopyWithImpl(this._self, this._then);

  final CourseManifest _self;
  final $Res Function(CourseManifest) _then;

/// Create a copy of CourseManifest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? language = null,Object? description = null,Object? version = null,Object? hash = null,Object? exportDate = freezed,Object? lessons = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,exportDate: freezed == exportDate ? _self.exportDate : exportDate // ignore: cast_nullable_to_non_nullable
as String?,lessons: null == lessons ? _self.lessons : lessons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CourseManifest].
extension CourseManifestPatterns on CourseManifest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CourseManifest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CourseManifest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CourseManifest value)  $default,){
final _that = this;
switch (_that) {
case _CourseManifest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CourseManifest value)?  $default,){
final _that = this;
switch (_that) {
case _CourseManifest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String language,  String description,  String version,  String hash,  String? exportDate,  List<String> lessons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CourseManifest() when $default != null:
return $default(_that.id,_that.title,_that.language,_that.description,_that.version,_that.hash,_that.exportDate,_that.lessons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String language,  String description,  String version,  String hash,  String? exportDate,  List<String> lessons)  $default,) {final _that = this;
switch (_that) {
case _CourseManifest():
return $default(_that.id,_that.title,_that.language,_that.description,_that.version,_that.hash,_that.exportDate,_that.lessons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String language,  String description,  String version,  String hash,  String? exportDate,  List<String> lessons)?  $default,) {final _that = this;
switch (_that) {
case _CourseManifest() when $default != null:
return $default(_that.id,_that.title,_that.language,_that.description,_that.version,_that.hash,_that.exportDate,_that.lessons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CourseManifest implements CourseManifest {
  const _CourseManifest({required this.id, required this.title, required this.language, this.description = '', this.version = '1.0', this.hash = '', this.exportDate, final  List<String> lessons = const []}): _lessons = lessons;
  factory _CourseManifest.fromJson(Map<String, dynamic> json) => _$CourseManifestFromJson(json);

@override final  String id;
@override final  String title;
@override final  String language;
@override@JsonKey() final  String description;
@override@JsonKey() final  String version;
@override@JsonKey() final  String hash;
@override final  String? exportDate;
 final  List<String> _lessons;
@override@JsonKey() List<String> get lessons {
  if (_lessons is EqualUnmodifiableListView) return _lessons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lessons);
}


/// Create a copy of CourseManifest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CourseManifestCopyWith<_CourseManifest> get copyWith => __$CourseManifestCopyWithImpl<_CourseManifest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CourseManifestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CourseManifest&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.language, language) || other.language == language)&&(identical(other.description, description) || other.description == description)&&(identical(other.version, version) || other.version == version)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.exportDate, exportDate) || other.exportDate == exportDate)&&const DeepCollectionEquality().equals(other._lessons, _lessons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,language,description,version,hash,exportDate,const DeepCollectionEquality().hash(_lessons));

@override
String toString() {
  return 'CourseManifest(id: $id, title: $title, language: $language, description: $description, version: $version, hash: $hash, exportDate: $exportDate, lessons: $lessons)';
}


}

/// @nodoc
abstract mixin class _$CourseManifestCopyWith<$Res> implements $CourseManifestCopyWith<$Res> {
  factory _$CourseManifestCopyWith(_CourseManifest value, $Res Function(_CourseManifest) _then) = __$CourseManifestCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String language, String description, String version, String hash, String? exportDate, List<String> lessons
});




}
/// @nodoc
class __$CourseManifestCopyWithImpl<$Res>
    implements _$CourseManifestCopyWith<$Res> {
  __$CourseManifestCopyWithImpl(this._self, this._then);

  final _CourseManifest _self;
  final $Res Function(_CourseManifest) _then;

/// Create a copy of CourseManifest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? language = null,Object? description = null,Object? version = null,Object? hash = null,Object? exportDate = freezed,Object? lessons = null,}) {
  return _then(_CourseManifest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,exportDate: freezed == exportDate ? _self.exportDate : exportDate // ignore: cast_nullable_to_non_nullable
as String?,lessons: null == lessons ? _self._lessons : lessons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$LessonInfo {

 String get id; String get name; String get title; String get description; int get order; List<String> get testing; String? get learningWordsPath;
/// Create a copy of LessonInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LessonInfoCopyWith<LessonInfo> get copyWith => _$LessonInfoCopyWithImpl<LessonInfo>(this as LessonInfo, _$identity);

  /// Serializes this LessonInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LessonInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.order, order) || other.order == order)&&const DeepCollectionEquality().equals(other.testing, testing)&&(identical(other.learningWordsPath, learningWordsPath) || other.learningWordsPath == learningWordsPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,title,description,order,const DeepCollectionEquality().hash(testing),learningWordsPath);

@override
String toString() {
  return 'LessonInfo(id: $id, name: $name, title: $title, description: $description, order: $order, testing: $testing, learningWordsPath: $learningWordsPath)';
}


}

/// @nodoc
abstract mixin class $LessonInfoCopyWith<$Res>  {
  factory $LessonInfoCopyWith(LessonInfo value, $Res Function(LessonInfo) _then) = _$LessonInfoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String title, String description, int order, List<String> testing, String? learningWordsPath
});




}
/// @nodoc
class _$LessonInfoCopyWithImpl<$Res>
    implements $LessonInfoCopyWith<$Res> {
  _$LessonInfoCopyWithImpl(this._self, this._then);

  final LessonInfo _self;
  final $Res Function(LessonInfo) _then;

/// Create a copy of LessonInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? title = null,Object? description = null,Object? order = null,Object? testing = null,Object? learningWordsPath = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,testing: null == testing ? _self.testing : testing // ignore: cast_nullable_to_non_nullable
as List<String>,learningWordsPath: freezed == learningWordsPath ? _self.learningWordsPath : learningWordsPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LessonInfo].
extension LessonInfoPatterns on LessonInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LessonInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LessonInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LessonInfo value)  $default,){
final _that = this;
switch (_that) {
case _LessonInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LessonInfo value)?  $default,){
final _that = this;
switch (_that) {
case _LessonInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String title,  String description,  int order,  List<String> testing,  String? learningWordsPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LessonInfo() when $default != null:
return $default(_that.id,_that.name,_that.title,_that.description,_that.order,_that.testing,_that.learningWordsPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String title,  String description,  int order,  List<String> testing,  String? learningWordsPath)  $default,) {final _that = this;
switch (_that) {
case _LessonInfo():
return $default(_that.id,_that.name,_that.title,_that.description,_that.order,_that.testing,_that.learningWordsPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String title,  String description,  int order,  List<String> testing,  String? learningWordsPath)?  $default,) {final _that = this;
switch (_that) {
case _LessonInfo() when $default != null:
return $default(_that.id,_that.name,_that.title,_that.description,_that.order,_that.testing,_that.learningWordsPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LessonInfo implements LessonInfo {
  const _LessonInfo({required this.id, required this.name, required this.title, this.description = '', this.order = 0, final  List<String> testing = const [], this.learningWordsPath}): _testing = testing;
  factory _LessonInfo.fromJson(Map<String, dynamic> json) => _$LessonInfoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String title;
@override@JsonKey() final  String description;
@override@JsonKey() final  int order;
 final  List<String> _testing;
@override@JsonKey() List<String> get testing {
  if (_testing is EqualUnmodifiableListView) return _testing;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_testing);
}

@override final  String? learningWordsPath;

/// Create a copy of LessonInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessonInfoCopyWith<_LessonInfo> get copyWith => __$LessonInfoCopyWithImpl<_LessonInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LessonInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LessonInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.order, order) || other.order == order)&&const DeepCollectionEquality().equals(other._testing, _testing)&&(identical(other.learningWordsPath, learningWordsPath) || other.learningWordsPath == learningWordsPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,title,description,order,const DeepCollectionEquality().hash(_testing),learningWordsPath);

@override
String toString() {
  return 'LessonInfo(id: $id, name: $name, title: $title, description: $description, order: $order, testing: $testing, learningWordsPath: $learningWordsPath)';
}


}

/// @nodoc
abstract mixin class _$LessonInfoCopyWith<$Res> implements $LessonInfoCopyWith<$Res> {
  factory _$LessonInfoCopyWith(_LessonInfo value, $Res Function(_LessonInfo) _then) = __$LessonInfoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String title, String description, int order, List<String> testing, String? learningWordsPath
});




}
/// @nodoc
class __$LessonInfoCopyWithImpl<$Res>
    implements _$LessonInfoCopyWith<$Res> {
  __$LessonInfoCopyWithImpl(this._self, this._then);

  final _LessonInfo _self;
  final $Res Function(_LessonInfo) _then;

/// Create a copy of LessonInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? title = null,Object? description = null,Object? order = null,Object? testing = null,Object? learningWordsPath = freezed,}) {
  return _then(_LessonInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,testing: null == testing ? _self._testing : testing // ignore: cast_nullable_to_non_nullable
as List<String>,learningWordsPath: freezed == learningWordsPath ? _self.learningWordsPath : learningWordsPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LearningWordsData {

 String get title; String? get learningLanguage; String? get translationLanguage; List<String> get translationLanguages; List<CourseWord> get words;
/// Create a copy of LearningWordsData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LearningWordsDataCopyWith<LearningWordsData> get copyWith => _$LearningWordsDataCopyWithImpl<LearningWordsData>(this as LearningWordsData, _$identity);

  /// Serializes this LearningWordsData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LearningWordsData&&(identical(other.title, title) || other.title == title)&&(identical(other.learningLanguage, learningLanguage) || other.learningLanguage == learningLanguage)&&(identical(other.translationLanguage, translationLanguage) || other.translationLanguage == translationLanguage)&&const DeepCollectionEquality().equals(other.translationLanguages, translationLanguages)&&const DeepCollectionEquality().equals(other.words, words));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,learningLanguage,translationLanguage,const DeepCollectionEquality().hash(translationLanguages),const DeepCollectionEquality().hash(words));

@override
String toString() {
  return 'LearningWordsData(title: $title, learningLanguage: $learningLanguage, translationLanguage: $translationLanguage, translationLanguages: $translationLanguages, words: $words)';
}


}

/// @nodoc
abstract mixin class $LearningWordsDataCopyWith<$Res>  {
  factory $LearningWordsDataCopyWith(LearningWordsData value, $Res Function(LearningWordsData) _then) = _$LearningWordsDataCopyWithImpl;
@useResult
$Res call({
 String title, String? learningLanguage, String? translationLanguage, List<String> translationLanguages, List<CourseWord> words
});




}
/// @nodoc
class _$LearningWordsDataCopyWithImpl<$Res>
    implements $LearningWordsDataCopyWith<$Res> {
  _$LearningWordsDataCopyWithImpl(this._self, this._then);

  final LearningWordsData _self;
  final $Res Function(LearningWordsData) _then;

/// Create a copy of LearningWordsData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? learningLanguage = freezed,Object? translationLanguage = freezed,Object? translationLanguages = null,Object? words = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,learningLanguage: freezed == learningLanguage ? _self.learningLanguage : learningLanguage // ignore: cast_nullable_to_non_nullable
as String?,translationLanguage: freezed == translationLanguage ? _self.translationLanguage : translationLanguage // ignore: cast_nullable_to_non_nullable
as String?,translationLanguages: null == translationLanguages ? _self.translationLanguages : translationLanguages // ignore: cast_nullable_to_non_nullable
as List<String>,words: null == words ? _self.words : words // ignore: cast_nullable_to_non_nullable
as List<CourseWord>,
  ));
}

}


/// Adds pattern-matching-related methods to [LearningWordsData].
extension LearningWordsDataPatterns on LearningWordsData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LearningWordsData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LearningWordsData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LearningWordsData value)  $default,){
final _that = this;
switch (_that) {
case _LearningWordsData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LearningWordsData value)?  $default,){
final _that = this;
switch (_that) {
case _LearningWordsData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String? learningLanguage,  String? translationLanguage,  List<String> translationLanguages,  List<CourseWord> words)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LearningWordsData() when $default != null:
return $default(_that.title,_that.learningLanguage,_that.translationLanguage,_that.translationLanguages,_that.words);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String? learningLanguage,  String? translationLanguage,  List<String> translationLanguages,  List<CourseWord> words)  $default,) {final _that = this;
switch (_that) {
case _LearningWordsData():
return $default(_that.title,_that.learningLanguage,_that.translationLanguage,_that.translationLanguages,_that.words);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String? learningLanguage,  String? translationLanguage,  List<String> translationLanguages,  List<CourseWord> words)?  $default,) {final _that = this;
switch (_that) {
case _LearningWordsData() when $default != null:
return $default(_that.title,_that.learningLanguage,_that.translationLanguage,_that.translationLanguages,_that.words);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LearningWordsData implements LearningWordsData {
  const _LearningWordsData({required this.title, this.learningLanguage, this.translationLanguage, final  List<String> translationLanguages = const [], final  List<CourseWord> words = const []}): _translationLanguages = translationLanguages,_words = words;
  factory _LearningWordsData.fromJson(Map<String, dynamic> json) => _$LearningWordsDataFromJson(json);

@override final  String title;
@override final  String? learningLanguage;
@override final  String? translationLanguage;
 final  List<String> _translationLanguages;
@override@JsonKey() List<String> get translationLanguages {
  if (_translationLanguages is EqualUnmodifiableListView) return _translationLanguages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_translationLanguages);
}

 final  List<CourseWord> _words;
@override@JsonKey() List<CourseWord> get words {
  if (_words is EqualUnmodifiableListView) return _words;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_words);
}


/// Create a copy of LearningWordsData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LearningWordsDataCopyWith<_LearningWordsData> get copyWith => __$LearningWordsDataCopyWithImpl<_LearningWordsData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LearningWordsDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LearningWordsData&&(identical(other.title, title) || other.title == title)&&(identical(other.learningLanguage, learningLanguage) || other.learningLanguage == learningLanguage)&&(identical(other.translationLanguage, translationLanguage) || other.translationLanguage == translationLanguage)&&const DeepCollectionEquality().equals(other._translationLanguages, _translationLanguages)&&const DeepCollectionEquality().equals(other._words, _words));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,learningLanguage,translationLanguage,const DeepCollectionEquality().hash(_translationLanguages),const DeepCollectionEquality().hash(_words));

@override
String toString() {
  return 'LearningWordsData(title: $title, learningLanguage: $learningLanguage, translationLanguage: $translationLanguage, translationLanguages: $translationLanguages, words: $words)';
}


}

/// @nodoc
abstract mixin class _$LearningWordsDataCopyWith<$Res> implements $LearningWordsDataCopyWith<$Res> {
  factory _$LearningWordsDataCopyWith(_LearningWordsData value, $Res Function(_LearningWordsData) _then) = __$LearningWordsDataCopyWithImpl;
@override @useResult
$Res call({
 String title, String? learningLanguage, String? translationLanguage, List<String> translationLanguages, List<CourseWord> words
});




}
/// @nodoc
class __$LearningWordsDataCopyWithImpl<$Res>
    implements _$LearningWordsDataCopyWith<$Res> {
  __$LearningWordsDataCopyWithImpl(this._self, this._then);

  final _LearningWordsData _self;
  final $Res Function(_LearningWordsData) _then;

/// Create a copy of LearningWordsData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? learningLanguage = freezed,Object? translationLanguage = freezed,Object? translationLanguages = null,Object? words = null,}) {
  return _then(_LearningWordsData(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,learningLanguage: freezed == learningLanguage ? _self.learningLanguage : learningLanguage // ignore: cast_nullable_to_non_nullable
as String?,translationLanguage: freezed == translationLanguage ? _self.translationLanguage : translationLanguage // ignore: cast_nullable_to_non_nullable
as String?,translationLanguages: null == translationLanguages ? _self._translationLanguages : translationLanguages // ignore: cast_nullable_to_non_nullable
as List<String>,words: null == words ? _self._words : words // ignore: cast_nullable_to_non_nullable
as List<CourseWord>,
  ));
}


}


/// @nodoc
mixin _$CourseWord {

 int get id; String get word; String get translation; Map<String, String> get translations; String get transcription; String get description; String get photo; String get audio;
/// Create a copy of CourseWord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CourseWordCopyWith<CourseWord> get copyWith => _$CourseWordCopyWithImpl<CourseWord>(this as CourseWord, _$identity);

  /// Serializes this CourseWord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CourseWord&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.translation, translation) || other.translation == translation)&&const DeepCollectionEquality().equals(other.translations, translations)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.description, description) || other.description == description)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.audio, audio) || other.audio == audio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,translation,const DeepCollectionEquality().hash(translations),transcription,description,photo,audio);

@override
String toString() {
  return 'CourseWord(id: $id, word: $word, translation: $translation, translations: $translations, transcription: $transcription, description: $description, photo: $photo, audio: $audio)';
}


}

/// @nodoc
abstract mixin class $CourseWordCopyWith<$Res>  {
  factory $CourseWordCopyWith(CourseWord value, $Res Function(CourseWord) _then) = _$CourseWordCopyWithImpl;
@useResult
$Res call({
 int id, String word, String translation, Map<String, String> translations, String transcription, String description, String photo, String audio
});




}
/// @nodoc
class _$CourseWordCopyWithImpl<$Res>
    implements $CourseWordCopyWith<$Res> {
  _$CourseWordCopyWithImpl(this._self, this._then);

  final CourseWord _self;
  final $Res Function(CourseWord) _then;

/// Create a copy of CourseWord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? word = null,Object? translation = null,Object? translations = null,Object? transcription = null,Object? description = null,Object? photo = null,Object? audio = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,translation: null == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as String,translations: null == translations ? _self.translations : translations // ignore: cast_nullable_to_non_nullable
as Map<String, String>,transcription: null == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CourseWord].
extension CourseWordPatterns on CourseWord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CourseWord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CourseWord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CourseWord value)  $default,){
final _that = this;
switch (_that) {
case _CourseWord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CourseWord value)?  $default,){
final _that = this;
switch (_that) {
case _CourseWord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String word,  String translation,  Map<String, String> translations,  String transcription,  String description,  String photo,  String audio)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CourseWord() when $default != null:
return $default(_that.id,_that.word,_that.translation,_that.translations,_that.transcription,_that.description,_that.photo,_that.audio);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String word,  String translation,  Map<String, String> translations,  String transcription,  String description,  String photo,  String audio)  $default,) {final _that = this;
switch (_that) {
case _CourseWord():
return $default(_that.id,_that.word,_that.translation,_that.translations,_that.transcription,_that.description,_that.photo,_that.audio);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String word,  String translation,  Map<String, String> translations,  String transcription,  String description,  String photo,  String audio)?  $default,) {final _that = this;
switch (_that) {
case _CourseWord() when $default != null:
return $default(_that.id,_that.word,_that.translation,_that.translations,_that.transcription,_that.description,_that.photo,_that.audio);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CourseWord implements CourseWord {
  const _CourseWord({required this.id, required this.word, required this.translation, final  Map<String, String> translations = const {}, this.transcription = '', this.description = '', this.photo = '', this.audio = ''}): _translations = translations;
  factory _CourseWord.fromJson(Map<String, dynamic> json) => _$CourseWordFromJson(json);

@override final  int id;
@override final  String word;
@override final  String translation;
 final  Map<String, String> _translations;
@override@JsonKey() Map<String, String> get translations {
  if (_translations is EqualUnmodifiableMapView) return _translations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_translations);
}

@override@JsonKey() final  String transcription;
@override@JsonKey() final  String description;
@override@JsonKey() final  String photo;
@override@JsonKey() final  String audio;

/// Create a copy of CourseWord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CourseWordCopyWith<_CourseWord> get copyWith => __$CourseWordCopyWithImpl<_CourseWord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CourseWordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CourseWord&&(identical(other.id, id) || other.id == id)&&(identical(other.word, word) || other.word == word)&&(identical(other.translation, translation) || other.translation == translation)&&const DeepCollectionEquality().equals(other._translations, _translations)&&(identical(other.transcription, transcription) || other.transcription == transcription)&&(identical(other.description, description) || other.description == description)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.audio, audio) || other.audio == audio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,word,translation,const DeepCollectionEquality().hash(_translations),transcription,description,photo,audio);

@override
String toString() {
  return 'CourseWord(id: $id, word: $word, translation: $translation, translations: $translations, transcription: $transcription, description: $description, photo: $photo, audio: $audio)';
}


}

/// @nodoc
abstract mixin class _$CourseWordCopyWith<$Res> implements $CourseWordCopyWith<$Res> {
  factory _$CourseWordCopyWith(_CourseWord value, $Res Function(_CourseWord) _then) = __$CourseWordCopyWithImpl;
@override @useResult
$Res call({
 int id, String word, String translation, Map<String, String> translations, String transcription, String description, String photo, String audio
});




}
/// @nodoc
class __$CourseWordCopyWithImpl<$Res>
    implements _$CourseWordCopyWith<$Res> {
  __$CourseWordCopyWithImpl(this._self, this._then);

  final _CourseWord _self;
  final $Res Function(_CourseWord) _then;

/// Create a copy of CourseWord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? word = null,Object? translation = null,Object? translations = null,Object? transcription = null,Object? description = null,Object? photo = null,Object? audio = null,}) {
  return _then(_CourseWord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,word: null == word ? _self.word : word // ignore: cast_nullable_to_non_nullable
as String,translation: null == translation ? _self.translation : translation // ignore: cast_nullable_to_non_nullable
as String,translations: null == translations ? _self._translations : translations // ignore: cast_nullable_to_non_nullable
as Map<String, String>,transcription: null == transcription ? _self.transcription : transcription // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
