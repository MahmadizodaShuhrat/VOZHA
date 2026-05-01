/// GET /api/v1/dict/learning-streak response.
///
/// Shape per backend commit bcef49e:
/// ```json
/// {
///   "current_streak": 7,
///   "longest_streak": 12,
///   "total_learning_days": 45,
///   "today_learned": true,
///   "available_milestones": [
///     { "days": 7,   "coins": 20,  "claimed": false, "unlocked": true  },
///     { "days": 14,  "coins": 50,  "claimed": false, "unlocked": false },
///     ...
///   ],
///   "claimed_milestones": [7]
/// }
/// ```
///
/// Backend returns `available_milestones` in undefined order (Go map
/// iteration) — callers MUST sort by `days` before rendering.
class LearningStreakDto {
  final int currentStreak;
  final int longestStreak;
  final int totalLearningDays;
  final bool todayLearned;
  final List<MilestoneDto> availableMilestones;
  final List<int> claimedMilestones;

  // Premium-bonus block — see `TZ_STREAK_PREMIUM_BONUS.md` §2. All four
  // are optional; when the backend doesn't ship the feature yet (older
  // staging, custom builds), they fall back to "no bonus" defaults so
  // the rest of the streak UI keeps working unchanged.

  /// How many active days are left before the next +1-day premium
  /// milestone fires. `0` means the bonus already triggered on this
  /// very request.
  final int nextPremiumMilestoneIn;

  /// Cycle length (default 10). Drives the progress bar
  /// `current_streak % threshold / threshold`.
  final int premiumBonusThreshold;

  /// Lifetime sum of premium days the user has earned via streak
  /// bonuses (purchased subscriptions excluded).
  final int totalPremiumDaysEarned;

  /// UTC date until which the accumulated bonus subscription stays
  /// active, separately from any purchased premium. Null when the
  /// user has never earned a bonus or the field is missing.
  final DateTime? bonusPremiumActiveUntil;

  const LearningStreakDto({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalLearningDays,
    required this.todayLearned,
    required this.availableMilestones,
    required this.claimedMilestones,
    required this.nextPremiumMilestoneIn,
    required this.premiumBonusThreshold,
    required this.totalPremiumDaysEarned,
    required this.bonusPremiumActiveUntil,
  });

  factory LearningStreakDto.fromJson(Map<String, dynamic> j) {
    final rawMilestones = (j['available_milestones'] as List?) ?? const [];
    final milestones = rawMilestones
        .whereType<Map<String, dynamic>>()
        .map(MilestoneDto.fromJson)
        .toList()
      ..sort((a, b) => a.days.compareTo(b.days));
    final claimedRaw = (j['claimed_milestones'] as List?) ?? const [];
    final claimed = claimedRaw
        .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
        .where((d) => d > 0)
        .toList();
    final activeUntilRaw = j['bonus_premium_active_until'];
    DateTime? activeUntil;
    if (activeUntilRaw is String && activeUntilRaw.isNotEmpty) {
      activeUntil = DateTime.tryParse(activeUntilRaw)?.toUtc();
    }
    return LearningStreakDto(
      currentStreak: (j['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (j['longest_streak'] as num?)?.toInt() ?? 0,
      totalLearningDays: (j['total_learning_days'] as num?)?.toInt() ?? 0,
      todayLearned: j['today_learned'] as bool? ?? false,
      availableMilestones: milestones,
      claimedMilestones: claimed,
      nextPremiumMilestoneIn:
          (j['next_premium_milestone_in'] as num?)?.toInt() ?? 0,
      // `0` signals "old backend that doesn't ship the bonus
      // feature yet" so the UI can hide the progress card. New
      // deployments always send 10 (or whatever
      // `STREAK_PREMIUM_THRESHOLD` is configured to).
      premiumBonusThreshold:
          (j['premium_bonus_threshold'] as num?)?.toInt() ?? 0,
      totalPremiumDaysEarned:
          (j['total_premium_days_earned'] as num?)?.toInt() ?? 0,
      bonusPremiumActiveUntil: activeUntil,
    );
  }

  static const LearningStreakDto empty = LearningStreakDto(
    currentStreak: 0,
    longestStreak: 0,
    totalLearningDays: 0,
    todayLearned: false,
    availableMilestones: [],
    claimedMilestones: [],
    nextPremiumMilestoneIn: 0,
    premiumBonusThreshold: 0,
    totalPremiumDaysEarned: 0,
    bonusPremiumActiveUntil: null,
  );
}

class MilestoneDto {
  final int days;
  final int coins;
  final bool claimed;
  final bool unlocked;

  const MilestoneDto({
    required this.days,
    required this.coins,
    required this.claimed,
    required this.unlocked,
  });

  factory MilestoneDto.fromJson(Map<String, dynamic> j) => MilestoneDto(
        days: (j['days'] as num?)?.toInt() ?? 0,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        claimed: j['claimed'] as bool? ?? false,
        unlocked: j['unlocked'] as bool? ?? false,
      );

  bool get canClaim => unlocked && !claimed;
}

/// Result of POST /dict/claim-milestone.
class ClaimMilestoneResult {
  final String status;
  final int coinsEarned;
  const ClaimMilestoneResult({required this.status, required this.coinsEarned});

  factory ClaimMilestoneResult.fromJson(Map<String, dynamic> j) =>
      ClaimMilestoneResult(
        status: j['status'] as String? ?? 'ok',
        coinsEarned: (j['coins_earned'] as num?)?.toInt() ?? 0,
      );
}

/// Errors surfaced by the claim endpoint. Transient errors return null from
/// the service call.
enum ClaimMilestoneError {
  notAvailable,    // 400 — streak < milestone_days OR already claimed
  unauthorized,    // 401
}

class ClaimMilestoneException implements Exception {
  final ClaimMilestoneError error;
  const ClaimMilestoneException(this.error);
  @override
  String toString() => 'ClaimMilestoneException($error)';
}
