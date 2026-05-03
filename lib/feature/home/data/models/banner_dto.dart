/// Banner model — response from `GET /api/v1/dict/banners`.
///
/// Backend (commit `ba58fcc`) controls banners through an admin panel:
/// `is_active`, `valid_from/to`, `target_user_type` and `app_version`
/// are all filtered server-side, so the client only renders what it
/// gets. The optional fields are still parsed defensively in case the
/// server response changes or a stale cache is shown offline.
class BannerDto {
  final int id;

  /// `'image'` (regular picture banner) or `'rating'` (special slide
  /// rendered with the top-3 widget). Unknown values fall back to
  /// `'image'` so older clients don't crash on a new type.
  final String type;

  final String title;

  /// Public R2 URL for the banner picture (empty for `type='rating'`).
  final String fileName;

  /// Action URL: `https://...` opens browser, `app://PageName[/<arg>]`
  /// navigates in-app. See [BannerLinkRouter] for the full route table.
  final String link;

  final int position;
  final int priority;
  final bool isActive;
  final double appVersion;
  final String platform;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? targetUserType;
  final int? minUserLevel;
  final Map<String, Map<String, String>>? localization;

  BannerDto({
    required this.id,
    this.type = 'image',
    required this.title,
    required this.fileName,
    required this.link,
    required this.position,
    this.priority = 0,
    this.isActive = true,
    required this.appVersion,
    required this.platform,
    this.validFrom,
    this.validTo,
    this.targetUserType,
    this.minUserLevel,
    this.localization,
  });

  /// Localized title — picks `localization[<locale>].title` if present,
  /// otherwise falls back to the legacy `title` field. Backend sends
  /// `tg` (not `tj`), matching the app's locale codes.
  String resolvedTitle(String locale) {
    final loc = localization?[locale];
    final localized = loc?['title'];
    if (localized != null && localized.isNotEmpty) return localized;
    return title;
  }

  /// Serialize back to the same shape the backend sends, so the disk
  /// cache can round-trip through `BannerDto.fromJson`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'file_name': fileName,
    'link': link,
    'position': position,
    'priority': priority,
    'is_active': isActive,
    'app_version': appVersion,
    'platform': platform,
    'valid_from': validFrom?.toIso8601String(),
    'valid_to': validTo?.toIso8601String(),
    'target_user_type': targetUserType,
    'min_user_level': minUserLevel,
    'localization': localization,
  };

  factory BannerDto.fromJson(Map<String, dynamic> json) {
    Map<String, Map<String, String>>? localization;
    final locRaw = json['localization'];
    if (locRaw is Map) {
      localization = locRaw.map((key, value) {
        if (value is Map) {
          return MapEntry(
            key.toString(),
            value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
          );
        }
        return MapEntry(key.toString(), <String, String>{});
      });
    }

    DateTime? parseTs(dynamic raw) {
      if (raw == null) return null;
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw)?.toUtc();
      }
      return null;
    }

    return BannerDto(
      id: json['id'] as int? ?? 0,
      type: (json['type'] as String?)?.isNotEmpty == true
          ? json['type'] as String
          : 'image',
      title: json['title'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      link: json['link'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      priority: json['priority'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      appVersion: (json['app_version'] is int)
          ? (json['app_version'] as int).toDouble()
          : (json['app_version'] as num?)?.toDouble() ?? 0.0,
      platform: json['platform'] as String? ?? '',
      validFrom: parseTs(json['valid_from']),
      validTo: parseTs(json['valid_to']),
      targetUserType: json['target_user_type'] as String?,
      minUserLevel: json['min_user_level'] as int?,
      localization: localization,
    );
  }
}
