import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/feature/rating/data/models/top_30_users_dto.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

class TopUsersRepository {
  final _base = '${ApiConstants.baseUrl}${ApiConstants.dictBase}';

  Future<List<Top30UsersDto>> getTopUsers(String period) async {
    try {
      final token = await StorageService.instance.getAccessToken();
      final response = await http
          .get(
            Uri.parse('$_base/top-active-users/$period'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiConstants.receiveTimeout);

      if (response.statusCode == 200) {
        // Defensive parse: backend used to send `null` (Go nil-slice) for
        // empty top-users; the new build returns `[]`, but older / cached
        // proxies and any other server that ever returns null shouldn't
        // crash the home-screen tile.
        final decoded = jsonDecode(response.body);
        final data = (decoded is List) ? decoded : const <dynamic>[];
        return data
            .map((json) => Top30UsersDto.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('❌ Ошибка сервера: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки top users: $e');
      return [];
    }
  }
}
