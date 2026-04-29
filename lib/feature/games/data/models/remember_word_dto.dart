// lib/models/remember_word_dto.dart
// Response from api/v1/users/get-user-progress-words (matching Unity structure)

class RememberNewWordsResponse {
  final int count;
  final String status;
  final int streakCoins;
  final List<NewAchievement> newAchievements;

  RememberNewWordsResponse({
    required this.count,
    required this.status,
    this.streakCoins = 0,
    this.newAchievements = const [],
  });

  factory RememberNewWordsResponse.fromJson(Map<String, dynamic> json) {
    return RememberNewWordsResponse(
      count: json['count'] as int? ?? 0,
      status: json['status'] as String? ?? 'ok',
      streakCoins: json['streak_coins'] as int? ?? 0,
      newAchievements: (json['new_achievements'] as List<dynamic>?)
          ?.map((a) => NewAchievement.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
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
