import 'package:freezed_annotation/freezed_annotation.dart';

part 'top_30_users_dto.freezed.dart';
part 'top_30_users_dto.g.dart';

@freezed
abstract class Top30UsersDto with _$Top30UsersDto {
  const factory Top30UsersDto({
    int? id,
    String? name,
    @JsonKey(name: 'avatar_url', defaultValue: '') String? avatarUrl,
    int? count,
    @JsonKey(name: 'user_type') String? userType,
    @JsonKey(name: 'organization_name') String? organizationName,
  }) = _Top30UsersDto;

  factory Top30UsersDto.fromJson(Map<String, dynamic> json) =>
      _$Top30UsersDtoFromJson(json);
}
