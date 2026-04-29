import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_info_dto.freezed.dart';
part 'profile_info_dto.g.dart';

@freezed
abstract class ProfileInfoDto with _$ProfileInfoDto {
  const factory ProfileInfoDto({
    int? id,
    @JsonKey(name: 'parent_id') int? parentId,
    String? name,
    String? phone,
    String? email,
    @JsonKey(name: 'organization_id') int? organizationId,
    int? money,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'avatar_base64') String? avatarBase64,
    @JsonKey(name: 'user_type') String? userType,
    @JsonKey(name: 'tariff_name') String? tariffName,
    @JsonKey(name: 'tariff_expired_at') String? tariffExpiredAt,
  }) = _ProfileInfoDto;

  factory ProfileInfoDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileInfoDtoFromJson(json);
}
