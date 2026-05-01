/// Optional `premium_bonus` payload returned by the activity / sync
/// endpoints. Backend awards +1 day of premium every N consecutive
/// active days (default N=10) — when that happens the response gets a
/// `premium_bonus` block describing the grant. The block is absent on
/// requests that didn't trip a milestone, so consumers must treat it
/// as nullable.
///
/// Spec — `TZ_STREAK_PREMIUM_BONUS.md` (commit `fd105a5`):
/// ```json
/// {
///   "granted": true,
///   "days_added": 1,
///   "milestone_streak": 10,
///   "new_premium_until": "2026-05-12T03:24:17Z"
/// }
/// ```
class PremiumBonusDto {
  final bool granted;
  final int daysAdded;
  final int milestoneStreak;
  final DateTime? newPremiumUntil;

  const PremiumBonusDto({
    required this.granted,
    required this.daysAdded,
    required this.milestoneStreak,
    required this.newPremiumUntil,
  });

  factory PremiumBonusDto.fromJson(Map<String, dynamic> j) => PremiumBonusDto(
        granted: j['granted'] as bool? ?? false,
        daysAdded: (j['days_added'] as num?)?.toInt() ?? 0,
        milestoneStreak: (j['milestone_streak'] as num?)?.toInt() ?? 0,
        newPremiumUntil: _parseDate(j['new_premium_until']),
      );

  /// Convenience: tries to parse the bonus block off any response. The
  /// backend returns it under the key `premium_bonus`; if absent or
  /// `granted` is false, returns null so the caller can branch on the
  /// presence of a real grant without writing the same `?.` chain
  /// everywhere.
  static PremiumBonusDto? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final raw = json['premium_bonus'];
    if (raw is! Map<String, dynamic>) return null;
    final dto = PremiumBonusDto.fromJson(raw);
    if (!dto.granted) return null;
    return dto;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
