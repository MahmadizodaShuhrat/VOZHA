import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/core/services/app_logger.dart';

/// Repository for fetching categories from backend.
/// API: GET /api/v1/dict/categories-flutter/list
/// Caches response locally for offline access.
class CategoriesRepository {
  static const _baseUrl = '${ApiConstants.baseUrl}${ApiConstants.dictBase}';
  static const _cacheKey = 'cached_categories_json';

  Future<List<CategoryFlutterDto>> getCategories() async {
    try {
      final token = await StorageService.instance.getAccessToken();

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ Categories API: No auth token available — user may not be logged in');
        return [];
      }

      final url = '$_baseUrl/categories-flutter/list';
      debugPrint('📂 Fetching categories: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15)); // Increased timeout for slow networks

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final categories = data
            .map(
              (json) =>
                  CategoryFlutterDto.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        debugPrint('✅ Loaded ${categories.length} categories from API');
        // Cache for offline access
        _saveToCache(response.body);
        return categories;
      } else if (response.statusCode == 401) {
        debugPrint('🔒 Categories API: 401 — attempting token refresh');
        final refreshed = await AuthSessionHandler.handle401();
        if (refreshed) {
          // Retry once after token refresh
          return getCategories();
        }
        return [];
      } else {
        debugPrint('❌ Categories API error: ${response.statusCode} body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
        return [];
      }
    } catch (e, st) {
      AppLogger.error('Categories', e, st);
      // Offline fallback: try loading from cache
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        debugPrint('📦 Loaded ${cached.length} categories from offline cache');
        return cached;
      }
      return [];
    }
  }

  Future<void> _saveToCache(String jsonBody) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonBody);
    } catch (_) {}
  }

  Future<List<CategoryFlutterDto>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null) return [];
      final List<dynamic> data = jsonDecode(jsonStr);
      return data
          .map((json) => CategoryFlutterDto.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

