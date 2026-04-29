// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileInfoDto _$ProfileInfoDtoFromJson(Map<String, dynamic> json) =>
    _ProfileInfoDto(
      id: (json['id'] as num?)?.toInt(),
      parentId: (json['parent_id'] as num?)?.toInt(),
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      organizationId: (json['organization_id'] as num?)?.toInt(),
      money: (json['money'] as num?)?.toInt(),
      avatarUrl: json['avatar_url'] as String?,
      avatarBase64: json['avatar_base64'] as String?,
      userType: json['user_type'] as String?,
      tariffName: json['tariff_name'] as String?,
      tariffExpiredAt: json['tariff_expired_at'] as String?,
    );

Map<String, dynamic> _$ProfileInfoDtoToJson(_ProfileInfoDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parent_id': instance.parentId,
      'name': instance.name,
      'phone': instance.phone,
      'email': instance.email,
      'organization_id': instance.organizationId,
      'money': instance.money,
      'avatar_url': instance.avatarUrl,
      'avatar_base64': instance.avatarBase64,
      'user_type': instance.userType,
      'tariff_name': instance.tariffName,
      'tariff_expired_at': instance.tariffExpiredAt,
    };
