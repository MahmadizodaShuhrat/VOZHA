// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'top_30_users_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Top30UsersDto _$Top30UsersDtoFromJson(Map<String, dynamic> json) =>
    _Top30UsersDto(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? '',
      count: (json['count'] as num?)?.toInt(),
      userType: json['user_type'] as String?,
      organizationName: json['organization_name'] as String?,
    );

Map<String, dynamic> _$Top30UsersDtoToJson(_Top30UsersDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar_url': instance.avatarUrl,
      'count': instance.count,
      'user_type': instance.userType,
      'organization_name': instance.organizationName,
    };
