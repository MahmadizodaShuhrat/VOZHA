/// Banner model matching Unity3D BannerResponse.
/// API: GET /api/v1/dict/banners
class BannerDto {
  final int id;
  final String title;

  /// URL to the banner image file
  final String fileName;

  /// Action URL: "https://..." opens browser, "app://PageName" navigates in-app
  final String link;

  final int position;
  final double appVersion;
  final String platform;
  final Map<String, Map<String, String>>? localization;

  BannerDto({
    required this.id,
    required this.title,
    required this.fileName,
    required this.link,
    required this.position,
    required this.appVersion,
    required this.platform,
    this.localization,
  });

  factory BannerDto.fromJson(Map<String, dynamic> json) {
    // Parse localization safely
    Map<String, Map<String, String>>? localization;
    if (json['localization'] != null && json['localization'] is Map) {
      localization = (json['localization'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        ),
      );
    }

    return BannerDto(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      link: json['link'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      appVersion: (json['app_version'] is int)
          ? (json['app_version'] as int).toDouble()
          : (json['app_version'] as num?)?.toDouble() ?? 0.0,
      platform: json['platform'] as String? ?? '',
      localization: localization,
    );
  }
}
