import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';

/// Data class for user's profile rating stats from backend.
/// API: GET api/v1/dict/profile-rating?lang_type=en
/// Same endpoint used in Unity project (UIStatisticsPage.cs).
class ProfileRating {
  final int rating;
  final int winsCount;
  final int earnedMoney;
  final int countLearnedWords;
  final int daysActive;

  ProfileRating({
    required this.rating,
    required this.winsCount,
    required this.earnedMoney,
    required this.countLearnedWords,
    required this.daysActive,
  });

  factory ProfileRating.fromJson(Map<String, dynamic> json) {
    return ProfileRating(
      rating: json['rating'] as int? ?? 0,
      winsCount: json['wins_count'] as int? ?? 0,
      earnedMoney: json['earned_money'] as int? ?? 0,
      countLearnedWords: json['count_learned_words'] as int? ?? 0,
      daysActive:
          json['days_active'] as int? ??
          json['active_days'] as int? ??
          json['streak'] as int? ??
          0,
    );
  }

  ProfileRating copyWith({
    int? rating,
    int? winsCount,
    int? earnedMoney,
    int? countLearnedWords,
    int? daysActive,
  }) {
    return ProfileRating(
      rating: rating ?? this.rating,
      winsCount: winsCount ?? this.winsCount,
      earnedMoney: earnedMoney ?? this.earnedMoney,
      countLearnedWords: countLearnedWords ?? this.countLearnedWords,
      daysActive: daysActive ?? this.daysActive,
    );
  }
}

/// Provider that fetches the current user's rank and stats from the backend.
/// Uses the same API endpoint as the Unity project: api/v1/dict/profile-rating
final profileRatingProvider =
    AsyncNotifierProvider<ProfileRatingNotifier, ProfileRating?>(
      ProfileRatingNotifier.new,
    );

class ProfileRatingNotifier extends AsyncNotifier<ProfileRating?> {
  static const _baseUrl = '${ApiConstants.baseUrl}${ApiConstants.dictBase}';

  @override
  FutureOr<ProfileRating?> build() async {
    return await _fetchProfileRating();
  }

  Future<ProfileRating?> _fetchProfileRating() async {
    try {
      final token = await StorageService.instance.getAccessToken();
      final langType = StorageService.instance.getTableWords();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/profile-rating?lang_type=$langType'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          // Use the shared receive-timeout (45s) so this request survives
          // the same rural LTE / emulator-network conditions that the
          // Dio-based paths already tolerate. 10s was timing out on
          // fresh installs in Tajikistan / Afghanistan and in Android
          // Studio emulators where the host-side NAT adds ~3s of latency.
          .timeout(ApiConstants.receiveTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Profile rating: $json');
        return ProfileRating.fromJson(json);
      } else {
        debugPrint('❌ Profile rating error: ${response.statusCode}');
        if (response.statusCode == 401) {
          await AuthSessionHandler.handle401();
        }
        return null;
      }
    } catch (e) {
      debugPrint('❌ Profile rating fetch error: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchProfileRating());
  }

  /// Patch the learned-words counter in place so the home-page stat
  /// reflects a freshly-completed session *before* the backend's
  /// profile-rating aggregate has caught up. The server-side
  /// invalidate/refetch that runs 800 ms later will reconcile — this
  /// method is purely for the instant-feedback moment when the user
  /// returns from /result. [delta] may be positive (new words crossed
  /// the "learned" threshold this session) or negative (rare — a word
  /// lost its learned status, which shouldn't normally happen).
  void optimisticIncrementLearnedWords(int delta) {
    if (delta == 0) return;
    final current = state.asData?.value;
    if (current == null) return;
    final next = (current.countLearnedWords + delta).clamp(0, 1 << 31);
    state = AsyncData(current.copyWith(countLearnedWords: next));
    debugPrint(
      '✨ [profileRating] optimistic learnedWords '
      '${current.countLearnedWords} → $next (Δ$delta)',
    );
  }
}
