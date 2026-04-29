// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'top_30_users_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Top30UsersDto {

 int? get id; String? get name;@JsonKey(name: 'avatar_url', defaultValue: '') String? get avatarUrl; int? get count;@JsonKey(name: 'user_type') String? get userType;@JsonKey(name: 'organization_name') String? get organizationName;
/// Create a copy of Top30UsersDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Top30UsersDtoCopyWith<Top30UsersDto> get copyWith => _$Top30UsersDtoCopyWithImpl<Top30UsersDto>(this as Top30UsersDto, _$identity);

  /// Serializes this Top30UsersDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Top30UsersDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.count, count) || other.count == count)&&(identical(other.userType, userType) || other.userType == userType)&&(identical(other.organizationName, organizationName) || other.organizationName == organizationName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatarUrl,count,userType,organizationName);

@override
String toString() {
  return 'Top30UsersDto(id: $id, name: $name, avatarUrl: $avatarUrl, count: $count, userType: $userType, organizationName: $organizationName)';
}


}

/// @nodoc
abstract mixin class $Top30UsersDtoCopyWith<$Res>  {
  factory $Top30UsersDtoCopyWith(Top30UsersDto value, $Res Function(Top30UsersDto) _then) = _$Top30UsersDtoCopyWithImpl;
@useResult
$Res call({
 int? id, String? name,@JsonKey(name: 'avatar_url', defaultValue: '') String? avatarUrl, int? count,@JsonKey(name: 'user_type') String? userType,@JsonKey(name: 'organization_name') String? organizationName
});




}
/// @nodoc
class _$Top30UsersDtoCopyWithImpl<$Res>
    implements $Top30UsersDtoCopyWith<$Res> {
  _$Top30UsersDtoCopyWithImpl(this._self, this._then);

  final Top30UsersDto _self;
  final $Res Function(Top30UsersDto) _then;

/// Create a copy of Top30UsersDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = freezed,Object? avatarUrl = freezed,Object? count = freezed,Object? userType = freezed,Object? organizationName = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,count: freezed == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int?,userType: freezed == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as String?,organizationName: freezed == organizationName ? _self.organizationName : organizationName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Top30UsersDto].
extension Top30UsersDtoPatterns on Top30UsersDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Top30UsersDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Top30UsersDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Top30UsersDto value)  $default,){
final _that = this;
switch (_that) {
case _Top30UsersDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Top30UsersDto value)?  $default,){
final _that = this;
switch (_that) {
case _Top30UsersDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String? name, @JsonKey(name: 'avatar_url', defaultValue: '')  String? avatarUrl,  int? count, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'organization_name')  String? organizationName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Top30UsersDto() when $default != null:
return $default(_that.id,_that.name,_that.avatarUrl,_that.count,_that.userType,_that.organizationName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String? name, @JsonKey(name: 'avatar_url', defaultValue: '')  String? avatarUrl,  int? count, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'organization_name')  String? organizationName)  $default,) {final _that = this;
switch (_that) {
case _Top30UsersDto():
return $default(_that.id,_that.name,_that.avatarUrl,_that.count,_that.userType,_that.organizationName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String? name, @JsonKey(name: 'avatar_url', defaultValue: '')  String? avatarUrl,  int? count, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'organization_name')  String? organizationName)?  $default,) {final _that = this;
switch (_that) {
case _Top30UsersDto() when $default != null:
return $default(_that.id,_that.name,_that.avatarUrl,_that.count,_that.userType,_that.organizationName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Top30UsersDto implements Top30UsersDto {
  const _Top30UsersDto({this.id, this.name, @JsonKey(name: 'avatar_url', defaultValue: '') this.avatarUrl, this.count, @JsonKey(name: 'user_type') this.userType, @JsonKey(name: 'organization_name') this.organizationName});
  factory _Top30UsersDto.fromJson(Map<String, dynamic> json) => _$Top30UsersDtoFromJson(json);

@override final  int? id;
@override final  String? name;
@override@JsonKey(name: 'avatar_url', defaultValue: '') final  String? avatarUrl;
@override final  int? count;
@override@JsonKey(name: 'user_type') final  String? userType;
@override@JsonKey(name: 'organization_name') final  String? organizationName;

/// Create a copy of Top30UsersDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Top30UsersDtoCopyWith<_Top30UsersDto> get copyWith => __$Top30UsersDtoCopyWithImpl<_Top30UsersDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$Top30UsersDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Top30UsersDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.count, count) || other.count == count)&&(identical(other.userType, userType) || other.userType == userType)&&(identical(other.organizationName, organizationName) || other.organizationName == organizationName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatarUrl,count,userType,organizationName);

@override
String toString() {
  return 'Top30UsersDto(id: $id, name: $name, avatarUrl: $avatarUrl, count: $count, userType: $userType, organizationName: $organizationName)';
}


}

/// @nodoc
abstract mixin class _$Top30UsersDtoCopyWith<$Res> implements $Top30UsersDtoCopyWith<$Res> {
  factory _$Top30UsersDtoCopyWith(_Top30UsersDto value, $Res Function(_Top30UsersDto) _then) = __$Top30UsersDtoCopyWithImpl;
@override @useResult
$Res call({
 int? id, String? name,@JsonKey(name: 'avatar_url', defaultValue: '') String? avatarUrl, int? count,@JsonKey(name: 'user_type') String? userType,@JsonKey(name: 'organization_name') String? organizationName
});




}
/// @nodoc
class __$Top30UsersDtoCopyWithImpl<$Res>
    implements _$Top30UsersDtoCopyWith<$Res> {
  __$Top30UsersDtoCopyWithImpl(this._self, this._then);

  final _Top30UsersDto _self;
  final $Res Function(_Top30UsersDto) _then;

/// Create a copy of Top30UsersDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = freezed,Object? avatarUrl = freezed,Object? count = freezed,Object? userType = freezed,Object? organizationName = freezed,}) {
  return _then(_Top30UsersDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,count: freezed == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int?,userType: freezed == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as String?,organizationName: freezed == organizationName ? _self.organizationName : organizationName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
