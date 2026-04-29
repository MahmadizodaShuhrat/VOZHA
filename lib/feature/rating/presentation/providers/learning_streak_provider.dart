import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/rating/data/models/learning_streak_dto.dart';

/// Fetches the user's current streak + milestones.
///
/// Backend endpoint: `GET /api/v1/dict/learning-streak` (commit bcef49e).
/// This is the AUTHORITATIVE source for milestone claim state — `/user/activity`
/// gives calendar / active_dates but doesn't expose milestone flags.
final learningStreakProvider =
    AsyncNotifierProvider<LearningStreakNotifier, LearningStreakDto?>(
  LearningStreakNotifier.new,
);

class LearningStreakNotifier extends AsyncNotifier<LearningStreakDto?> {
  @override
  FutureOr<LearningStreakDto?> build() async {
    return await _fetch();
  }

  Future<LearningStreakDto?> _fetch() async {
    try {
      final token = await StorageService.instance.getAccessToken();
      if (token == null || token.isEmpty) return null;

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.learningStreak}',
      );
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(ApiConstants.receiveTimeout);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        debugPrint('🏅 Learning streak: $json');
        return LearningStreakDto.fromJson(json);
      }
      debugPrint('❌ Learning streak error: ${res.statusCode}');
      if (res.statusCode == 401) {
        await AuthSessionHandler.handle401();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Learning streak fetch error: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// POST /api/v1/dict/claim-milestone `{ "milestone_days": N }`.
  ///
  /// Returns the new coin balance delta on success. Throws
  /// [ClaimMilestoneException] on business errors, returns null on
  /// transient/network issues.
  Future<ClaimMilestoneResult?> claim(int milestoneDays) async {
    final token = await StorageService.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const ClaimMilestoneException(ClaimMilestoneError.unauthorized);
    }
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.claimMilestone}',
    );
    try {
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'milestone_days': milestoneDays}),
      ).timeout(const Duration(seconds: 15));

      debugPrint('🏅 Claim milestone $milestoneDays → ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final result = ClaimMilestoneResult.fromJson(json);
        // Refresh streak state so the card flips to the "claimed" style
        // without the caller having to do it.
        await refresh();
        return result;
      }
      if (res.statusCode == 401) {
        throw const ClaimMilestoneException(ClaimMilestoneError.unauthorized);
      }
      if (res.statusCode == 400) {
        throw const ClaimMilestoneException(ClaimMilestoneError.notAvailable);
      }
      return null; // 5xx / transient
    } on ClaimMilestoneException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Claim milestone error: $e');
      return null;
    }
  }
}
