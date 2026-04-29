import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:vozhaomuz/feature/profile/data/model/profile_info_dto.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

/// Исключение, когда токена нет или он невалиден
class NoTokenException implements Exception {}

/// Репозиторий для работы с профилем
class ProfileRepository {
  static const _base = '${ApiConstants.baseUrl}${ApiConstants.usersBase}';
  final http.Client _client = http.Client();

  Future<ProfileInfoDto> getProfile() async {
    final token = await StorageService.instance.getAccessToken();
    if (token == null) throw NoTokenException();

    final response = await _client.get(
      Uri.parse('$_base/get-profile'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      debugPrint(
        '[getProfile] RAW avatar_url=${body['avatar_url']}, name=${body['name']}',
      );
      final dto = ProfileInfoDto.fromJson(body);
      debugPrint('[getProfile] DTO avatarUrl=${dto.avatarUrl}, name=${dto.name}');
      return dto;
    } else if (response.statusCode == 401) {
      throw NoTokenException();
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  /// Пример обновления аватара (необязательно трогать)
  Future<bool> uploadAvatarWithName(Uint8List avatarBytes, String name) async {
    try {
      final token = await StorageService.instance.getAccessToken();
      if (token == null) throw NoTokenException();

      final uri = Uri.parse('$_base/update-profile');
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['Name'] = name;

      // Танҳо вақте ки акси нав дорад, расмро илова мекунем
      if (avatarBytes.isNotEmpty) {
        final image = img.decodeImage(avatarBytes);
        if (image == null) return false;
        final resized = img.copyResize(image, width: 800);
        final compressed = Uint8List.fromList(img.encodeJpg(resized));

        req.files.add(
          http.MultipartFile.fromBytes(
            'AvatarFile',
            compressed,
            filename: 'avatar.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

}
