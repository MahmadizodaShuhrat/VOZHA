import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/rating/data/models/streak_premium_history_dto.dart';

/// `GET /api/v1/dict/streak-premium-history?limit=N` (TZ §3).
///
/// Family-keyed by `limit` so the page can request up to 200 grants
/// while small previews (e.g. a "last 5 bonuses" widget) stay cheap.
final streakPremiumHistoryProvider = FutureProvider.family
    .autoDispose<StreakPremiumHistoryDto?, int>((ref, limit) async {
  final token = await StorageService.instance.getAccessToken();
  if (token == null || token.isEmpty) return null;

  final clamped = limit.clamp(1, 200);
  final uri = Uri.parse(
    '${ApiConstants.baseUrl}${ApiConstants.apiVersion}/dict/streak-premium-history'
    '?limit=$clamped',
  );

  try {
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(ApiConstants.receiveTimeout);

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('✅ Streak premium history: $json');
      return StreakPremiumHistoryDto.fromJson(json);
    }
    debugPrint('❌ Streak premium history ${res.statusCode}: ${res.body}');
    if (res.statusCode == 401) {
      await AuthSessionHandler.handle401();
    }
    return null;
  } catch (e) {
    debugPrint('❌ Streak premium history fetch error: $e');
    return null;
  }
});
