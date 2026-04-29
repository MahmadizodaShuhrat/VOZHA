import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/feature/rating/data/models/achievement_dto.dart';

/// Provider that fetches achievements from backend.
/// API: GET api/v1/dict/achievements?lang={langCode}&lang_type={tableWords}
/// Same endpoint used in Unity (UIStatisticsPage.cs line 138).
final achievementsProvider =
    AsyncNotifierProvider<AchievementsNotifier, List<AchievementDto>>(
      AchievementsNotifier.new,
    );

class AchievementsNotifier extends AsyncNotifier<List<AchievementDto>> {
  static const _baseUrl = '${ApiConstants.baseUrl}${ApiConstants.dictBase}';

  @override
  FutureOr<List<AchievementDto>> build() async {
    // Watch locale so we auto-refetch when language changes
    final locale = ref.watch(localeProvider);
    return await _fetchAchievements(locale.languageCode);
  }

  Future<List<AchievementDto>> _fetchAchievements(String interfaceLang) async {
    try {
      final token = await StorageService.instance.getAccessToken();
      final langType = StorageService.instance.getTableWords();

      // Unity: DataResources.InterfaceLanguageCode => "ru" or "tj"
      // Convert 'tg' -> 'tj' for API compatibility
      final langCode = interfaceLang == 'tg' ? 'tj' : interfaceLang;

      final url = '$_baseUrl/achievements?lang=$langCode&lang_type=$langType';
      debugPrint('🏆 Fetching achievements: $url');
      debugPrint(
        '🏆 interfaceLang=$interfaceLang, langType=$langType, langCode=$langCode',
      );

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(ApiConstants.receiveTimeout);

      if (response.statusCode == 200) {
        debugPrint('🏆 Raw achievements response: ${response.body}');
        final List<dynamic> data = jsonDecode(response.body);
        final achievements = data
            .map((json) => AchievementDto.fromJson(json))
            .toList();
        debugPrint('✅ Loaded ${achievements.length} achievements');
        for (final a in achievements) {
          debugPrint(
            '  🏆 ${a.type}: ${a.name} progress=${a.progress}/${a.conditionValue} claimed=${a.claimed}',
          );
        }
        return achievements;
      } else {
        debugPrint('❌ Achievements error: ${response.statusCode}');
        if (response.statusCode == 401) {
          await AuthSessionHandler.handle401();
        }
        return [];
      }
    } catch (e) {
      debugPrint('❌ Achievements fetch error: $e');
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final locale = ref.read(localeProvider);
    state = await AsyncValue.guard(
      () => _fetchAchievements(locale.languageCode),
    );
  }
}
