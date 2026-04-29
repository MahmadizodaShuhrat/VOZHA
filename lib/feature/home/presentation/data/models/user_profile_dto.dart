// lib/feature/user_profile/data/models/user_profile_dto.dart

import 'package:freezed_annotation/freezed_annotation.dart';
part 'user_profile_dto.freezed.dart';
part 'user_profile_dto.g.dart';

@freezed
abstract class UserProfileDto with _$UserProfileDto {
  const factory UserProfileDto({
    required int id,
    required String name,
    @JsonKey(name: 'avatar_url', defaultValue: '') required String avatarUrl,
    String? email,
    String? bio,
    @JsonKey(name: 'user_type') required String userType,
    @JsonKey(name: 'joined_at') String? joinedAt,
    // добавьте другие поля, которые возвращает API
  }) = _UserProfileDto;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDtoFromJson(json);
}
