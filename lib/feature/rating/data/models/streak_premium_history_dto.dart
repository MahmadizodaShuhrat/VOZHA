/// `GET /api/v1/dict/streak-premium-history?limit=N` response (TZ §3).
///
/// Lists every streak-bonus grant the user has earned, newest first,
/// plus aggregate fields for the page header (total earned, current
/// bonus expiry, threshold settings).
class StreakPremiumHistoryDto {
  final List<StreakPremiumGrantDto> history;
  final int totalDaysGranted;
  final DateTime? bonusActiveUntil;
  final int threshold;
  final int daysPerMilestone;

  const StreakPremiumHistoryDto({
    required this.history,
    required this.totalDaysGranted,
    required this.bonusActiveUntil,
    required this.threshold,
    required this.daysPerMilestone,
  });

  factory StreakPremiumHistoryDto.fromJson(Map<String, dynamic> j) {
    final rawHistory = (j['history'] as List?) ?? const [];
    final grants = rawHistory
        .whereType<Map<String, dynamic>>()
        .map(StreakPremiumGrantDto.fromJson)
        .toList();
    final activeRaw = j['bonus_active_until'];
    DateTime? activeUntil;
    if (activeRaw is String && activeRaw.isNotEmpty) {
      activeUntil = DateTime.tryParse(activeRaw)?.toUtc();
    }
    return StreakPremiumHistoryDto(
      history: grants,
      totalDaysGranted: (j['total_days_granted'] as num?)?.toInt() ?? 0,
      bonusActiveUntil: activeUntil,
      threshold: (j['threshold'] as num?)?.toInt() ?? 10,
      daysPerMilestone: (j['days_per_milestone'] as num?)?.toInt() ?? 1,
    );
  }

  static const StreakPremiumHistoryDto empty = StreakPremiumHistoryDto(
    history: [],
    totalDaysGranted: 0,
    bonusActiveUntil: null,
    threshold: 10,
    daysPerMilestone: 1,
  );
}

class StreakPremiumGrantDto {
  final int id;
  final int userId;
  final int streakRunId;
  final int milestoneStreak;
  final int premiumDaysAdded;
  final DateTime? newPremiumUntil;
  final DateTime? grantedAt;

  const StreakPremiumGrantDto({
    required this.id,
    required this.userId,
    required this.streakRunId,
    required this.milestoneStreak,
    required this.premiumDaysAdded,
    required this.newPremiumUntil,
    required this.grantedAt,
  });

  factory StreakPremiumGrantDto.fromJson(Map<String, dynamic> j) =>
      StreakPremiumGrantDto(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        streakRunId: (j['streak_run_id'] as num?)?.toInt() ?? 0,
        milestoneStreak: (j['milestone_streak'] as num?)?.toInt() ?? 0,
        premiumDaysAdded: (j['premium_days_added'] as num?)?.toInt() ?? 0,
        newPremiumUntil: _parseDate(j['new_premium_until']),
        grantedAt: _parseDate(j['granted_at']),
      );

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
