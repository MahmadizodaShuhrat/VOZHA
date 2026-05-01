// lib/data/remember_new_words_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/feature/games/data/models/remember_word_dto.dart';
import 'package:vozhaomuz/core/services/words_sync_service.dart';
import 'package:vozhaomuz/feature/games/data/models/user_words_with_upload.dart';
import 'package:vozhaomuz/feature/rating/data/models/premium_bonus_dto.dart';

class RememberNewWordsRepository implements IRememberNewWordsRepository {
  final String baseUrl;
  final http.Client _client;

  RememberNewWordsRepository({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// Синхронизирует прогресс слов с сервером.
  /// POST /api/v1/users/flutter/sync-user-progress-words
  @override
  Future<RememberNewWordsResponse> syncProgress({
    required List<UserWordsWithUpload> words,
  }) async {
    final token = await StorageService.instance.getAccessToken();
    if (token == null) {
      throw Exception('Access token not found');
    }

    if (words.isEmpty) {
      return RememberNewWordsResponse(count: 0, status: 'skipped');
    }

    final uri = Uri.parse('$baseUrl/api/v1/users/flutter/sync-user-progress-words');
    final body = words.map((w) => w.toJson()).toList();

    debugPrint(
      '🔐 Token preview: ${token.length > 20 ? token.substring(0, 20) : token}...',
    );
    debugPrint('📤 Sending ${words.length} words to server (syncProgress)');
    debugPrint('📤 Payload: ${jsonEncode(body)}');

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));

    debugPrint('📥 Response: ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      return RememberNewWordsResponse.fromJson(jsonMap);
    } else {
      throw Exception(
        'Ошибка при синхронизации: ${res.statusCode} ${res.body}',
      );
    }
  }

  /// Получить прогресс слов с сервера.
  /// GET /api/v1/users/flutter/get-user-progress-words
  @override
  Future<Map<String, dynamic>?> getUserProgressWords() async {
    final token = await StorageService.instance.getAccessToken();
    if (token == null) {
      debugPrint('❌ [getUserProgressWords] No token available');
      return null;
    }

    debugPrint('🔍 [getUserProgressWords] Fetching progress from server...');
    debugPrint('🔐 Token preview: ${token.substring(0, 20)}...');

    final uri = Uri.parse(
      '$baseUrl/api/v1/users/flutter/get-user-progress-words',
    );

    final res = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    debugPrint('📥 [getUserProgressWords] Response status: ${res.statusCode}');
    debugPrint(
      '📥 [getUserProgressWords] Response body: ${res.body.length > 500 ? '${res.body.substring(0, 500)}...' : res.body}',
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint(
        '✅ [getUserProgressWords] Parsed data keys: ${data.keys.toList()}',
      );
      if (data.containsKey('words')) {
        final words = data['words'] as List?;
        debugPrint(
          '📋 [getUserProgressWords] Words count: ${words?.length ?? 0}',
        );
      }
      return data;
    }

    // Агар токен муҳлаташ гузашт — handle401() зану кунем
    if (res.statusCode == 401) {
      debugPrint('🔒 [getUserProgressWords] 401 — calling handle401()');
      await AuthSessionHandler.handle401();
      return null;
    }

    debugPrint(
      '❌ [getUserProgressWords] Failed with status: ${res.statusCode}',
    );
    return null;
  }

  /// Отправляет статистику учебной сессии.
  /// POST /api/v1/users/flutter/activity
  ///
  /// Returns the response's optional `premium_bonus` block when the
  /// session crossed a streak milestone (TZ §1).
  @override
  Future<PremiumBonusDto?> sendActivity({
    required DateTime startTime,
    required DateTime endTime,
    required List<int> learned,
    required List<int> errors,
    required List<int> repeated,
  }) async {
    final token = await StorageService.instance.getAccessToken();
    if (token == null) {
      debugPrint('❌ [sendActivity] No token available');
      return null;
    }

    final durationSeconds = endTime.difference(startTime).inSeconds;
    final dateStr =
        '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';

    final body = {
      'date': dateStr,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_seconds': durationSeconds,
      'learned': learned,
      'errors': errors,
      'repeated': repeated,
    };

    debugPrint('📊 [sendActivity] Sending session: ${jsonEncode(body)}');

    final uri = Uri.parse('$baseUrl/api/v1/users/flutter/activity');

    try {
      final res = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 [sendActivity] Response: ${res.statusCode}');
      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);
          return PremiumBonusDto.tryParse(body);
        } catch (_) {
          // Body wasn't JSON — backend's old format. No bonus.
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ [sendActivity] Error: $e');
      return null;
    }
  }

  /// Получить статистику активности за конкретный день.
  /// GET /api/v1/users/flutter/activity?date=YYYY-MM-DD
  Future<Map<String, dynamic>?> getActivity({required String date}) async {
    final token = await StorageService.instance.getAccessToken();
    if (token == null) {
      debugPrint('❌ [getActivity] No token available');
      return null;
    }

    final uri = Uri.parse('$baseUrl/api/v1/users/flutter/activity?date=$date');

    try {
      final res = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 [getActivity] Response: ${res.statusCode}');

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('❌ [getActivity] Failed: ${res.statusCode} ${res.body}');
      return null;
    } catch (e) {
      debugPrint('❌ [getActivity] Error: $e');
      return null;
    }
  }
}
