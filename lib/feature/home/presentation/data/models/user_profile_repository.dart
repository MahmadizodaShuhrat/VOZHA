// lib/feature/user_profile/data/user_profile_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/feature/home/presentation/data/models/user_profile_dto.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

class UserProfileRepository {
  final _base = '${ApiConstants.baseUrl}${ApiConstants.usersBase}';

  /// Получить профиль пользователя по его ID.
  Future<UserProfileDto> getUserProfile(int userId) async {
    final token = await StorageService.instance.getAccessToken();
    // Предполагаем, что API умеет принимать GET-параметр user_id
    final uri = Uri.parse('$_base/get-profile?user_id=$userId');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки профиля $userId: ${response.statusCode}',
      );
    }
    final Map<String, dynamic> json = jsonDecode(response.body);
    return UserProfileDto.fromJson(json);
  }
}
