/// Achievement data from backend.
/// API: GET api/v1/dict/achievements?lang={langCode}&lang_type={tableWords}
/// Matches Unity's Achievement class in UIAchievementsPage.cs
class AchievementDto {
  final String code;
  final String name;
  final String type;
  final bool claimed;
  final int progress;
  final int conditionValue;
  final String iconUrl;
  final int coinsReward;

  AchievementDto({
    required this.code,
    required this.name,
    required this.type,
    required this.claimed,
    required this.progress,
    required this.conditionValue,
    required this.iconUrl,
    required this.coinsReward,
  });

  factory AchievementDto.fromJson(Map<String, dynamic> json) {
    return AchievementDto(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      claimed: json['claimed'] as bool? ?? false,
      progress: _parseInt(json['progress']),
      conditionValue: json['condition_value'] as int? ?? 0,
      iconUrl: json['icon_url'] as String? ?? '',
      coinsReward: json['coins_reward'] as int? ?? 0,
    );
  }

  /// The icon URL to display.
  /// If not claimed, use grayed out version (Unity: icon_url.Replace(".png", "0.png"))
  String get displayIconUrl =>
      claimed ? iconUrl : iconUrl.replaceAll('.png', '0.png');

  /// Helper to parse progress that can be int or string
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
