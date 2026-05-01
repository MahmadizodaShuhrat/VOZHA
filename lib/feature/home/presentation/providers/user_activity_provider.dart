import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

/// Per-month activity + streak snapshot returned by
/// `GET /api/v1/user/activity?year=Y&month=M`.
///
/// Backend spec (backend commit 772dcb8):
///   - `active_dates`: YYYY-MM-DD strings, days the user did at least one
///     activity in the requested month (UTC day boundary).
///   - `current_streak`: consecutive-day streak (with lazy-expiry: if the
///     gap since the last active day is > 1 day, backend returns 0).
///   - `longest_streak`: best streak the user ever had.
class UserActivity {
  final int year;
  final int month;
  final Set<DateTime> activeDates;
  final int currentStreak;
  final int longestStreak;

  // TZ §2 — premium-bonus block. Optional on the response. Defaults
  // are safe for older backends that don't ship the feature yet.
  final int nextPremiumMilestoneIn;
  final int premiumBonusThreshold;
  final int totalPremiumDaysEarned;
  final DateTime? bonusPremiumActiveUntil;

  const UserActivity({
    required this.year,
    required this.month,
    required this.activeDates,
    required this.currentStreak,
    required this.longestStreak,
    required this.nextPremiumMilestoneIn,
    required this.premiumBonusThreshold,
    required this.totalPremiumDaysEarned,
    required this.bonusPremiumActiveUntil,
  });

  factory UserActivity.fromJson(Map<String, dynamic> json) {
    final rawDates = (json['active_dates'] as List?) ?? const [];
    final parsed = <DateTime>{};
    for (final s in rawDates) {
      if (s is! String) continue;
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        // Normalize to local date-only key for UI comparisons.
        parsed.add(DateTime(dt.year, dt.month, dt.day));
      }
    }
    final activeUntilRaw = json['bonus_premium_active_until'];
    DateTime? activeUntil;
    if (activeUntilRaw is String && activeUntilRaw.isNotEmpty) {
      activeUntil = DateTime.tryParse(activeUntilRaw)?.toUtc();
    }
    return UserActivity(
      year: json['year'] as int? ?? 0,
      month: json['month'] as int? ?? 0,
      activeDates: parsed,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      nextPremiumMilestoneIn:
          (json['next_premium_milestone_in'] as num?)?.toInt() ?? 0,
      // Default `0` (not 10) when the field is absent so the UI can
      // tell "old backend without the feature" apart from "new
      // backend that explicitly sent 10". Real deployments always
      // include the field — `0` is the "feature not shipped yet"
      // signal that hides the progress bar.
      premiumBonusThreshold:
          (json['premium_bonus_threshold'] as num?)?.toInt() ?? 0,
      totalPremiumDaysEarned:
          (json['total_premium_days_earned'] as num?)?.toInt() ?? 0,
      bonusPremiumActiveUntil: activeUntil,
    );
  }

  static const UserActivity empty = UserActivity(
    year: 0,
    month: 0,
    activeDates: {},
    currentStreak: 0,
    longestStreak: 0,
    nextPremiumMilestoneIn: 0,
    premiumBonusThreshold: 0,
    totalPremiumDaysEarned: 0,
    bonusPremiumActiveUntil: null,
  );
}

/// Family-provider keyed by (year, month). The streak dialog watches the
/// month currently visible in the calendar; switching months fetches a
/// different cell. `current_streak`/`longest_streak` come back identical
/// for every month request, so any call answers the "today streak" question.
final userActivityProvider = FutureProvider.family
    .autoDispose<UserActivity?, ({int year, int month})>((ref, key) async {
  final token = await StorageService.instance.getAccessToken();
  if (token == null || token.isEmpty) return null;

  final uri = Uri.parse(
    '${ApiConstants.baseUrl}${ApiConstants.userActivity}'
    '?year=${key.year}&month=${key.month}',
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
      debugPrint('✅ User activity ${key.year}-${key.month}: $json');
      return UserActivity.fromJson(json);
    }

    debugPrint('❌ User activity ${res.statusCode}: ${res.body}');
    if (res.statusCode == 401) {
      await AuthSessionHandler.handle401();
    }
    return null;
  } catch (e) {
    debugPrint('❌ User activity fetch error: $e');
    return null;
  }
});
