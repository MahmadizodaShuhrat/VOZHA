// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_info_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileInfoDto {

 int? get id;@JsonKey(name: 'parent_id') int? get parentId; String? get name; String? get phone; String? get email;@JsonKey(name: 'organization_id') int? get organizationId; int? get money;@JsonKey(name: 'avatar_url') String? get avatarUrl;@JsonKey(name: 'avatar_base64') String? get avatarBase64;@JsonKey(name: 'user_type') String? get userType;@JsonKey(name: 'tariff_name') String? get tariffName;@JsonKey(name: 'tariff_expired_at') String? get tariffExpiredAt;
/// Create a copy of ProfileInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileInfoDtoCopyWith<ProfileInfoDto> get copyWith => _$ProfileInfoDtoCopyWithImpl<ProfileInfoDto>(this as ProfileInfoDto, _$identity);

  /// Serializes this ProfileInfoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileInfoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.money, money) || other.money == money)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.avatarBase64, avatarBase64) || other.avatarBase64 == avatarBase64)&&(identical(other.userType, userType) || other.userType == userType)&&(identical(other.tariffName, tariffName) || other.tariffName == tariffName)&&(identical(other.tariffExpiredAt, tariffExpiredAt) || other.tariffExpiredAt == tariffExpiredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,name,phone,email,organizationId,money,avatarUrl,avatarBase64,userType,tariffName,tariffExpiredAt);

@override
String toString() {
  return 'ProfileInfoDto(id: $id, parentId: $parentId, name: $name, phone: $phone, email: $email, organizationId: $organizationId, money: $money, avatarUrl: $avatarUrl, avatarBase64: $avatarBase64, userType: $userType, tariffName: $tariffName, tariffExpiredAt: $tariffExpiredAt)';
}


}

/// @nodoc
abstract mixin class $ProfileInfoDtoCopyWith<$Res>  {
  factory $ProfileInfoDtoCopyWith(ProfileInfoDto value, $Res Function(ProfileInfoDto) _then) = _$ProfileInfoDtoCopyWithImpl;
@useResult
$Res call({
 int? id,@JsonKey(name: 'parent_id') int? parentId, String? name, String? phone, String? email,@JsonKey(name: 'organization_id') int? organizationId, int? money,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'avatar_base64') String? avatarBase64,@JsonKey(name: 'user_type') String? userType,@JsonKey(name: 'tariff_name') String? tariffName,@JsonKey(name: 'tariff_expired_at') String? tariffExpiredAt
});




}
/// @nodoc
class _$ProfileInfoDtoCopyWithImpl<$Res>
    implements $ProfileInfoDtoCopyWith<$Res> {
  _$ProfileInfoDtoCopyWithImpl(this._self, this._then);

  final ProfileInfoDto _self;
  final $Res Function(ProfileInfoDto) _then;

/// Create a copy of ProfileInfoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? parentId = freezed,Object? name = freezed,Object? phone = freezed,Object? email = freezed,Object? organizationId = freezed,Object? money = freezed,Object? avatarUrl = freezed,Object? avatarBase64 = freezed,Object? userType = freezed,Object? tariffName = freezed,Object? tariffExpiredAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,organizationId: freezed == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as int?,money: freezed == money ? _self.money : money // ignore: cast_nullable_to_non_nullable
as int?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,avatarBase64: freezed == avatarBase64 ? _self.avatarBase64 : avatarBase64 // ignore: cast_nullable_to_non_nullable
as String?,userType: freezed == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as String?,tariffName: freezed == tariffName ? _self.tariffName : tariffName // ignore: cast_nullable_to_non_nullable
as String?,tariffExpiredAt: freezed == tariffExpiredAt ? _self.tariffExpiredAt : tariffExpiredAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileInfoDto].
extension ProfileInfoDtoPatterns on ProfileInfoDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileInfoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileInfoDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileInfoDto value)  $default,){
final _that = this;
switch (_that) {
case _ProfileInfoDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileInfoDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileInfoDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'parent_id')  int? parentId,  String? name,  String? phone,  String? email, @JsonKey(name: 'organization_id')  int? organizationId,  int? money, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'avatar_base64')  String? avatarBase64, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'tariff_name')  String? tariffName, @JsonKey(name: 'tariff_expired_at')  String? tariffExpiredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileInfoDto() when $default != null:
return $default(_that.id,_that.parentId,_that.name,_that.phone,_that.email,_that.organizationId,_that.money,_that.avatarUrl,_that.avatarBase64,_that.userType,_that.tariffName,_that.tariffExpiredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'parent_id')  int? parentId,  String? name,  String? phone,  String? email, @JsonKey(name: 'organization_id')  int? organizationId,  int? money, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'avatar_base64')  String? avatarBase64, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'tariff_name')  String? tariffName, @JsonKey(name: 'tariff_expired_at')  String? tariffExpiredAt)  $default,) {final _that = this;
switch (_that) {
case _ProfileInfoDto():
return $default(_that.id,_that.parentId,_that.name,_that.phone,_that.email,_that.organizationId,_that.money,_that.avatarUrl,_that.avatarBase64,_that.userType,_that.tariffName,_that.tariffExpiredAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id, @JsonKey(name: 'parent_id')  int? parentId,  String? name,  String? phone,  String? email, @JsonKey(name: 'organization_id')  int? organizationId,  int? money, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'avatar_base64')  String? avatarBase64, @JsonKey(name: 'user_type')  String? userType, @JsonKey(name: 'tariff_name')  String? tariffName, @JsonKey(name: 'tariff_expired_at')  String? tariffExpiredAt)?  $default,) {final _that = this;
switch (_that) {
case _ProfileInfoDto() when $default != null:
return $default(_that.id,_that.parentId,_that.name,_that.phone,_that.email,_that.organizationId,_that.money,_that.avatarUrl,_that.avatarBase64,_that.userType,_that.tariffName,_that.tariffExpiredAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileInfoDto implements ProfileInfoDto {
  const _ProfileInfoDto({this.id, @JsonKey(name: 'parent_id') this.parentId, this.name, this.phone, this.email, @JsonKey(name: 'organization_id') this.organizationId, this.money, @JsonKey(name: 'avatar_url') this.avatarUrl, @JsonKey(name: 'avatar_base64') this.avatarBase64, @JsonKey(name: 'user_type') this.userType, @JsonKey(name: 'tariff_name') this.tariffName, @JsonKey(name: 'tariff_expired_at') this.tariffExpiredAt});
  factory _ProfileInfoDto.fromJson(Map<String, dynamic> json) => _$ProfileInfoDtoFromJson(json);

@override final  int? id;
@override@JsonKey(name: 'parent_id') final  int? parentId;
@override final  String? name;
@override final  String? phone;
@override final  String? email;
@override@JsonKey(name: 'organization_id') final  int? organizationId;
@override final  int? money;
@override@JsonKey(name: 'avatar_url') final  String? avatarUrl;
@override@JsonKey(name: 'avatar_base64') final  String? avatarBase64;
@override@JsonKey(name: 'user_type') final  String? userType;
@override@JsonKey(name: 'tariff_name') final  String? tariffName;
@override@JsonKey(name: 'tariff_expired_at') final  String? tariffExpiredAt;

/// Create a copy of ProfileInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileInfoDtoCopyWith<_ProfileInfoDto> get copyWith => __$ProfileInfoDtoCopyWithImpl<_ProfileInfoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileInfoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileInfoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.money, money) || other.money == money)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.avatarBase64, avatarBase64) || other.avatarBase64 == avatarBase64)&&(identical(other.userType, userType) || other.userType == userType)&&(identical(other.tariffName, tariffName) || other.tariffName == tariffName)&&(identical(other.tariffExpiredAt, tariffExpiredAt) || other.tariffExpiredAt == tariffExpiredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,name,phone,email,organizationId,money,avatarUrl,avatarBase64,userType,tariffName,tariffExpiredAt);

@override
String toString() {
  return 'ProfileInfoDto(id: $id, parentId: $parentId, name: $name, phone: $phone, email: $email, organizationId: $organizationId, money: $money, avatarUrl: $avatarUrl, avatarBase64: $avatarBase64, userType: $userType, tariffName: $tariffName, tariffExpiredAt: $tariffExpiredAt)';
}


}

/// @nodoc
abstract mixin class _$ProfileInfoDtoCopyWith<$Res> implements $ProfileInfoDtoCopyWith<$Res> {
  factory _$ProfileInfoDtoCopyWith(_ProfileInfoDto value, $Res Function(_ProfileInfoDto) _then) = __$ProfileInfoDtoCopyWithImpl;
@override @useResult
$Res call({
 int? id,@JsonKey(name: 'parent_id') int? parentId, String? name, String? phone, String? email,@JsonKey(name: 'organization_id') int? organizationId, int? money,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'avatar_base64') String? avatarBase64,@JsonKey(name: 'user_type') String? userType,@JsonKey(name: 'tariff_name') String? tariffName,@JsonKey(name: 'tariff_expired_at') String? tariffExpiredAt
});




}
/// @nodoc
class __$ProfileInfoDtoCopyWithImpl<$Res>
    implements _$ProfileInfoDtoCopyWith<$Res> {
  __$ProfileInfoDtoCopyWithImpl(this._self, this._then);

  final _ProfileInfoDto _self;
  final $Res Function(_ProfileInfoDto) _then;

/// Create a copy of ProfileInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? name = freezed,Object? phone = freezed,Object? email = freezed,Object? organizationId = freezed,Object? money = freezed,Object? avatarUrl = freezed,Object? avatarBase64 = freezed,Object? userType = freezed,Object? tariffName = freezed,Object? tariffExpiredAt = freezed,}) {
  return _then(_ProfileInfoDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,organizationId: freezed == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as int?,money: freezed == money ? _self.money : money // ignore: cast_nullable_to_non_nullable
as int?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,avatarBase64: freezed == avatarBase64 ? _self.avatarBase64 : avatarBase64 // ignore: cast_nullable_to_non_nullable
as String?,userType: freezed == userType ? _self.userType : userType // ignore: cast_nullable_to_non_nullable
as String?,tariffName: freezed == tariffName ? _self.tariffName : tariffName // ignore: cast_nullable_to_non_nullable
as String?,tariffExpiredAt: freezed == tariffExpiredAt ? _self.tariffExpiredAt : tariffExpiredAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
