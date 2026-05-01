// lib/models/remember_word_dto.dart
// Response from api/v1/users/get-user-progress-words (matching Unity structure)

import 'package:vozhaomuz/feature/rating/data/models/premium_bonus_dto.dart';

class RememberNewWordsResponse {
  final int count;
  final String status;
  final int streakCoins;
  final List<NewAchievement> newAchievements;

  /// Optional streak premium-bonus block (TZ §1). Null when this
  /// request didn't trigger a milestone — most calls.
  final PremiumBonusDto? premiumBonus;

  RememberNewWordsResponse({
    required this.count,
    required this.status,
    this.streakCoins = 0,
    this.newAchievements = const [],
    this.premiumBonus,
  });

  factory RememberNewWordsResponse.fromJson(Map<String, dynamic> json) {
    return RememberNewWordsResponse(
      count: json['count'] as int? ?? 0,
      status: json['status'] as String? ?? 'ok',
      streakCoins: json['streak_coins'] as int? ?? 0,
      newAchievements: (json['new_achievements'] as List<dynamic>?)
          ?.map((a) => NewAchievement.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
      premiumBonus: PremiumBonusDto.tryParse(json),
    );
  }
}

/// Achievement from server (matching Unity NewAchievements)
class NewAchievement {
  final String code;
  final String name;
  final String iconUrl;
  final int coinsEarned;
  final int countWords;
  final int conditionValue;

  NewAchievement({
    required this.code,
    required this.name,
    required this.iconUrl,
    required this.coinsEarned,
    required this.countWords,
    required this.conditionValue,
  });

  factory NewAchievement.fromJson(Map<String, dynamic> json) {
    return NewAchievement(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      iconUrl: json['icon_url'] as String? ?? '',
      coinsEarned: json['coins_earned'] as int? ?? 0,
      countWords: json['count_words'] as int? ?? 0,
      conditionValue: json['condition_value'] as int? ?? 0,
    );
  }
}
