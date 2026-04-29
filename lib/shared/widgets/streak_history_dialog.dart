import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:vozhaomuz/feature/home/presentation/providers/user_activity_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/rating/data/models/learning_streak_dto.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/learning_streak_provider.dart';
import 'package:vozhaomuz/shared/widgets/milestone_claim_celebration.dart';

/// Immutable snapshot of a user's activity history, filled from the
/// `GET /api/v1/user/activity?year=&month=` endpoint.
class StreakHistory {
  final int currentStreak;
  final int longestStreak;
  final Set<DateTime> activeDates;

  const StreakHistory({
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDates,
  });
}

/// Streak dialog, Duolingo-style: big animated flame, this-week strip,
/// progress bar to the next milestone, expandable monthly calendar.
class StreakHistoryDialog extends ConsumerStatefulWidget {
  const StreakHistoryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const StreakHistoryDialog(),
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.88,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<StreakHistoryDialog> createState() =>
      _StreakHistoryDialogState();
}

/// Duolingo milestone tiers — lets us show progress like "2 days to 14 days".
const _kMilestones = [7, 14, 30, 50, 100, 180, 365, 500, 1000];

int _nextMilestoneFor(int streak) {
  for (final m in _kMilestones) {
    if (streak < m) return m;
  }
  return streak + 100; // past 1000 — round hundreds
}

class _StreakHistoryDialogState extends ConsumerState<StreakHistoryDialog>
    with SingleTickerProviderStateMixin {
  late DateTime _monthCursor;
  bool _showMonthly = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthCursor = DateTime(now.year, now.month, 1);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _prevMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _monthCursor = DateTime(_monthCursor.year, _monthCursor.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final cap = DateTime(now.year, now.month, 1);
    if (!_monthCursor.isBefore(cap)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _monthCursor = DateTime(_monthCursor.year, _monthCursor.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Backend endpoint (772dcb8): GET /user/activity?year=&month= returns
    // active_dates for the requested month + current_streak + longest_streak
    // (same streak numbers regardless of month). Watch the visible month so
    // calendar navigation fetches that month's cells.
    final activityAsync = ref.watch(
      userActivityProvider((
        year: _monthCursor.year,
        month: _monthCursor.month,
      )),
    );
    final activity = activityAsync.asData?.value;

    // First-ever fetch has no data yet → show shimmer instead of a "streak 0"
    // placeholder that would flash before the real numbers arrive.
    if (activity == null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: _ShimmerBody(onClose: () => Navigator.of(context).pop()),
          ),
        ),
      );
    }

    final history = StreakHistory(
      currentStreak: activity.currentStreak,
      longestStreak: activity.longestStreak,
      activeDates: activity.activeDates,
    );
    final nextMilestone = _nextMilestoneFor(history.currentStreak);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(onClose: () => Navigator.of(context).pop()),
                const SizedBox(height: 6),
                _FlameBadge(streak: history.currentStreak, pulse: _pulse),
                const SizedBox(height: 20),
                _CurrentWeekRow(activeDates: history.activeDates),
                const SizedBox(height: 22),
                _MilestoneBar(
                  streak: history.currentStreak,
                  nextMilestone: nextMilestone,
                ),
                // The "longest streak" card is redundant noise when the user
                // has never started a streak — hide it and let the milestone
                // bar carry the motivation on its own.
                if (history.longestStreak > 0) ...[
                  const SizedBox(height: 18),
                  _LongestStreakCard(longest: history.longestStreak),
                ],
                // Milestone rewards (manual claim — 7/14/30/90/180/365 days).
                // Backend: `/dict/learning-streak` → `available_milestones`.
                const SizedBox(height: 18),
                const _MilestonesSection(),
                const SizedBox(height: 14),
                _ToggleMonthlyButton(
                  expanded: _showMonthly,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showMonthly = !_showMonthly);
                  },
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 280),
                  crossFadeState: _showMonthly
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        _MonthSwitcher(
                          month: _monthCursor,
                          onPrev: _prevMonth,
                          onNext: _nextMonth,
                          canGoNext: _monthCursor.isBefore(
                            DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CalendarGrid(
                          month: _monthCursor,
                          activeDates: history.activeDates,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton shown while the first `/user/activity` response is in
/// flight. Mirrors the real dialog's layout (header → flame → week → bar)
/// so there's no size jump when the data lands and replaces the shimmer.
class _ShimmerBody extends StatelessWidget {
  final VoidCallback onClose;
  const _ShimmerBody({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.shade300;
    final highlightColor = Colors.grey.shade100;

    Widget box({double? width, required double height, double radius = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Keep the real header (title + close button) so the user can still
        // dismiss while loading.
        _Header(onClose: onClose),
        const SizedBox(height: 6),
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Column(
            children: [
              // Flame badge
              box(width: 120, height: 120, radius: 60),
              const SizedBox(height: 12),
              // Big streak number
              box(width: 80, height: 44),
              const SizedBox(height: 10),
              // Subtitle
              box(width: 220, height: 14),
              const SizedBox(height: 22),
              // Week row
              box(width: double.infinity, height: 60, radius: 16),
              const SizedBox(height: 22),
              // Milestone bar row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  box(width: 110, height: 14),
                  box(width: 60, height: 14),
                ],
              ),
              const SizedBox(height: 10),
              box(width: double.infinity, height: 10, radius: 100),
              const SizedBox(height: 24),
              // Toggle-calendar line
              box(width: 180, height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 32),
        Expanded(
          child: Text(
            'streak_history_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D2939),
            ),
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 18, color: Color(0xFF667085)),
          ),
        ),
      ],
    );
  }
}

class _FlameBadge extends StatelessWidget {
  final int streak;
  final Animation<double> pulse;

  const _FlameBadge({required this.streak, required this.pulse});

  // Day 10/15/20/30 grant the user a premium reward — show a distinct card.
  static const _premiumDays = {10, 15, 20, 30};

  @override
  Widget build(BuildContext context) {
    final hasDailyPush = streak >= 1 && streak <= 30;
    final isPremiumDay = _premiumDays.contains(streak);

    return Column(
      children: [
        SizedBox(
          height: 120,
          width: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => Container(
                  width: 110 + 14 * pulse.value,
                  height: 110 + 14 * pulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF6B35).withOpacity(0.28),
                        const Color(0xFFFF6B35).withOpacity(0.0),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9F1C), Color(0xFFFF4E1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.08).animate(
                      CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
                    ),
                    child: const Text('🔥', style: TextStyle(fontSize: 56)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Animated counter — count up from 0 to `streak` with a quick
        // bounce on first frame so opening the dialog feels celebratory
        // instead of static. Re-runs whenever `streak` changes (e.g.
        // after a fresh learning session that ticked the counter).
        TweenAnimationBuilder<double>(
          // Use a String key so AnimatedSwitcher-style "value changed →
          // restart" still fires when streak goes 0→1 mid-session.
          key: ValueKey<int>(streak),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, t, __) {
            // Count up: 0 → streak across the tween.
            final shown = (streak * t).round();
            return Transform.scale(
              // Pop slightly at the end of the count.
              scale: 1.0 + 0.08 * Curves.easeOut.transform(t),
              child: Text(
                '$shown',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: streak == 0
                      ? const Color(0xFF98A2B3)
                      : const Color(0xFF1D2939),
                  height: 1.0,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        // Cross-fade between text variants when the streak changes
        // (e.g. user just hit day 1 — replaces "Start today" with the
        // "Хороший старт" push card with a smooth animation).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: hasDailyPush
              ? _DailyPushCard(
                  key: ValueKey('push-$streak'),
                  day: streak,
                  isPremium: isPremiumDay,
                )
              : Text(
                  streak == 0
                      ? 'streak_start_today'.tr()
                      : 'streak_days_in_a_row'.tr(
                          namedArgs: {'count': '$streak'},
                        ),
                  key: ValueKey('caption-$streak'),
                  style: TextStyle(
                    fontSize: 13,
                    color: streak == 0
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF667085),
                    fontWeight:
                        streak == 0 ? FontWeight.w600 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      ],
    );
  }
}

/// Styled card that shows the per-day motivational message
/// (streak_push_day_1 … streak_push_day_30). Premium days (10/15/20/30)
/// get a golden gradient + crown emoji to hint at the reward.
class _DailyPushCard extends StatelessWidget {
  final int day;
  final bool isPremium;

  const _DailyPushCard({super.key, required this.day, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final gradientColors = isPremium
        ? const [Color(0xFFFFF4C2), Color(0xFFFFE39A)]
        : const [Color(0xFFFFF7E5), Color(0xFFFFEBCC)];
    final borderColor = isPremium
        ? const Color(0xFFF7B955)
        : const Color(0xFFFFD699);
    final shadowColor = isPremium
        ? const Color(0xFFF7B955)
        : const Color(0xFFFF9F1C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isPremium
                    ? const [Color(0xFFFFD86E), Color(0xFFF59E0B)]
                    : const [Color(0xFFFF9F1C), Color(0xFFFF4E1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                isPremium ? '👑' : '✨',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'streak_push_day_$day'.tr(),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: isPremium
                    ? const Color(0xFF7C4A03)
                    : const Color(0xFF7A3E0F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Monday → Sunday strip of the current week. Past inactive days are grey
/// dots, active days have a flame, future days are faint outlines.
class _CurrentWeekRow extends StatelessWidget {
  final Set<DateTime> activeDates;
  const _CurrentWeekRow({required this.activeDates});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // weekday: 1=Mon..7=Sun. We want the Monday of this week as anchor.
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final labels = 'streak_weekday_labels'.tr().split(',');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final d = monday.add(Duration(days: i));
          final key = DateTime(d.year, d.month, d.day);
          final isActive = activeDates.contains(key);
          final isToday = key.isAtSameMomentAs(today);
          final inFuture = key.isAfter(today);

          return Expanded(
            child: Column(
              children: [
                Text(
                  labels[i],
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 8),
                _WeekDayDot(
                  isActive: isActive,
                  isToday: isToday,
                  inFuture: inFuture,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _WeekDayDot extends StatelessWidget {
  final bool isActive;
  final bool isToday;
  final bool inFuture;

  const _WeekDayDot({
    required this.isActive,
    required this.isToday,
    required this.inFuture,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9F1C), Color(0xFFFF4E1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // Today gets a soft gold ring that reads as "highlighted, still
          // on-fire" instead of the previous flat black that clashed with
          // the warm gradient palette.
          border: isToday
              ? Border.all(color: const Color(0xFFFFD86E), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 255, 161, 53).withOpacity(0.32),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: Text('🔥', style: TextStyle(fontSize: 18))),
      );
    }

    // Today without a streak yet → warm, inviting — a "start here" marker,
    // not a warning. Other inactive days stay as neutral dots to keep the
    // empty state from looking like a wall of failures.
    if (isToday) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFF7E5),
          border: Border.all(color: const Color(0xFFFF9F1C), width: 2),
        ),
        child: const Center(
          child: Icon(
            Icons.local_fire_department_outlined,
            size: 16,
            color: Color(0xFFFF6B35),
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: inFuture ? const Color(0xFFF8FAFC) : const Color(0xFFF2F4F7),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inFuture ? const Color(0xFFE4E7EC) : const Color(0xFFCFD4DC),
          ),
        ),
      ),
    );
  }
}

/// Linear progress to next milestone. At 0 streak → "Start your streak today!"
class _MilestoneBar extends StatelessWidget {
  final int streak;
  final int nextMilestone;

  const _MilestoneBar({required this.streak, required this.nextMilestone});

  @override
  Widget build(BuildContext context) {
    final progress = nextMilestone == 0
        ? 0.0
        : (streak / nextMilestone).clamp(0.0, 1.0);
    final remaining = nextMilestone - streak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'streak_milestone_label'.tr(
                namedArgs: {'target': '$nextMilestone'},
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475467),
              ),
            ),
            Text(
              streak >= nextMilestone
                  ? '✓'
                  : 'streak_days_left'.tr(namedArgs: {'count': '$remaining'}),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF6B35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 10,
            color: const Color(0xFFF1F5F9),
            child: LayoutBuilder(
              builder: (_, c) => Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  width: c.maxWidth * progress,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF9F1C), Color(0xFFFF4E1A)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Milestone reward rail — one card per tier (7/14/30/90/180/365 days).
/// Pulls state from `learningStreakProvider`; renders three visual states:
///   • claimable  → bright gradient + "Получить N монет" button (claims on tap)
///   • claimed    → subdued green with a ✓ badge
///   • locked     → grey, shows "X / N дней" progress
class _MilestonesSection extends ConsumerWidget {
  const _MilestonesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(learningStreakProvider);
    final data = async.asData?.value;
    if (data == null || data.availableMilestones.isEmpty) {
      // Keep the layout stable while streak state is loading or the
      // endpoint is unreachable — avoids a visible "pop" when the data
      // lands after the dialog's entry animation.
      return const SizedBox(height: 4);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'streak_milestones_title'.tr(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D2939),
            ),
          ),
        ),
        for (final m in data.availableMilestones) ...[
          _MilestoneCard(
            milestone: m,
            currentStreak: data.currentStreak,
            onClaim: () => _handleClaim(context, ref, m.days),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> _handleClaim(
    BuildContext context,
    WidgetRef ref,
    int days,
  ) async {
    HapticFeedback.mediumImpact();
    try {
      final result =
          await ref.read(learningStreakProvider.notifier).claim(days);
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('energy_refill_error_server'.tr())),
        );
        return;
      }
      // Reflect the new balance in the coin badge immediately.
      final profile = ref.read(getProfileInfoProvider).value;
      if (profile != null) {
        final currentMoney = profile.money ?? 0;
        ref
            .read(getProfileInfoProvider.notifier)
            .syncMoneyFromServer(currentMoney + result.coinsEarned);
      }
      // Ба ҷои SnackBar-и ҳамвор — попап-и ҷашнӣ бо counter-и тангаҳои
      // анимасия-шуда. Корбар бубинад ки чанд танга гирифт ва ҳис кунад
      // ки ҷоиза воқеан ба даст омад.
      await showMilestoneClaimCelebration(
        context,
        days: days,
        coinsEarned: result.coinsEarned,
      );
    } on ClaimMilestoneException catch (e) {
      if (!context.mounted) return;
      final key = switch (e.error) {
        ClaimMilestoneError.notAvailable => 'milestone_claim_not_available',
        ClaimMilestoneError.unauthorized =>
          'energy_refill_error_unauthorized',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(key.tr())),
      );
    }
  }
}

class _MilestoneCard extends StatelessWidget {
  final MilestoneDto milestone;
  final int currentStreak;
  final VoidCallback onClaim;

  const _MilestoneCard({
    required this.milestone,
    required this.currentStreak,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final state = milestone.claimed
        ? _MilestoneState.claimed
        : milestone.canClaim
            ? _MilestoneState.claimable
            : _MilestoneState.locked;

    final bg = switch (state) {
      _MilestoneState.claimable => const Color(0xFFFFF4E1),
      _MilestoneState.claimed => const Color(0xFFECFDF3),
      _MilestoneState.locked => const Color(0xFFF8FAFC),
    };
    final border = switch (state) {
      _MilestoneState.claimable => const Color(0xFFFFD699),
      _MilestoneState.claimed => const Color(0xFFA6F4C5),
      _MilestoneState.locked => const Color(0xFFEAECF0),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _MilestoneIcon(state: state),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'milestone_days_label'.tr(
                    namedArgs: {'days': milestone.days.toString()},
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(state),
                  style: TextStyle(
                    fontSize: 12,
                    color: _subtitleColor(state),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MilestoneAction(state: state, coins: milestone.coins, onClaim: onClaim),
        ],
      ),
    );
  }

  String _subtitle(_MilestoneState state) {
    switch (state) {
      case _MilestoneState.claimable:
        return 'milestone_ready_to_claim'.tr();
      case _MilestoneState.claimed:
        return 'milestone_claimed'.tr();
      case _MilestoneState.locked:
        return 'milestone_progress'.tr(namedArgs: {
          'current': currentStreak.toString(),
          'target': milestone.days.toString(),
        });
    }
  }

  Color _subtitleColor(_MilestoneState state) => switch (state) {
        _MilestoneState.claimable => const Color(0xFFB45309),
        _MilestoneState.claimed => const Color(0xFF027A48),
        _MilestoneState.locked => const Color(0xFF98A2B3),
      };
}

enum _MilestoneState { claimable, claimed, locked }

class _MilestoneIcon extends StatelessWidget {
  final _MilestoneState state;
  const _MilestoneIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    final size = 40.0;
    final emoji = switch (state) {
      _MilestoneState.claimable => '🏆',
      _MilestoneState.claimed => '✓',
      _MilestoneState.locked => '🔒',
    };
    final gradient = switch (state) {
      _MilestoneState.claimable =>
        const [Color(0xFFFFD86E), Color(0xFFFF9F1C)],
      _MilestoneState.claimed =>
        const [Color(0xFF6CE9A6), Color(0xFF12B76A)],
      _MilestoneState.locked =>
        const [Color(0xFFE4E7EC), Color(0xFFCFD4DC)],
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: state == _MilestoneState.claimed ? 20 : 18,
            color: state == _MilestoneState.claimed
                ? Colors.white
                : null,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MilestoneAction extends StatelessWidget {
  final _MilestoneState state;
  final int coins;
  final VoidCallback onClaim;

  const _MilestoneAction({
    required this.state,
    required this.coins,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _MilestoneState.claimable:
        return SizedBox(
          height: 34,
          child: ElevatedButton(
            onPressed: onClaim,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9F1C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'milestone_claim_button'.tr(namedArgs: {'coins': '$coins'}),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case _MilestoneState.claimed:
        return Text(
          'milestone_coins_value'.tr(namedArgs: {'coins': '$coins'}),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF98A2B3),
            decoration: TextDecoration.lineThrough,
          ),
        );
      case _MilestoneState.locked:
        return Text(
          'milestone_coins_value'.tr(namedArgs: {'coins': '$coins'}),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF98A2B3),
          ),
        );
    }
  }
}

class _LongestStreakCard extends StatelessWidget {
  final int longest;
  const _LongestStreakCard({required this.longest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE0A6)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'streak_longest'.tr(),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'streak_longest_value'.tr(namedArgs: {'count': '$longest'}),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleMonthlyButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ToggleMonthlyButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              (expanded ? 'streak_hide_calendar' : 'streak_show_calendar').tr(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: const Color(0xFF2563EB),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canGoNext;

  const _MonthSwitcher({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _NavButton(icon: Icons.chevron_left, onTap: onPrev, enabled: true),
        Text(
          DateFormat.yMMMM(context.locale.toString()).format(month),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D2939),
          ),
        ),
        _NavButton(
          icon: Icons.chevron_right,
          onTap: onNext,
          enabled: canGoNext,
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFF2F4F7),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF344054) : const Color(0xFFD0D5DD),
          size: 18,
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Set<DateTime> activeDates;

  const _CalendarGrid({required this.month, required this.activeDates});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final labels = 'streak_weekday_labels'.tr().split(',');

    return Column(
      children: [
        Row(
          children: labels
              .map(
                (l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, constraints) {
            final cellSize = (constraints.maxWidth - 6 * 6) / 7;
            final cells = <Widget>[];
            for (int i = 1; i < firstWeekday; i++) {
              cells.add(SizedBox(width: cellSize, height: cellSize));
            }
            for (int day = 1; day <= daysInMonth; day++) {
              final date = DateTime(month.year, month.month, day);
              final active = activeDates.contains(date);
              final isToday = date.isAtSameMomentAs(todayKey);
              final inFuture = date.isAfter(todayKey);
              cells.add(
                _DayCell(
                  day: day,
                  size: cellSize,
                  active: active,
                  isToday: isToday,
                  inFuture: inFuture,
                ),
              );
            }
            return Wrap(spacing: 6, runSpacing: 6, children: cells);
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final double size;
  final bool active;
  final bool isToday;
  final bool inFuture;

  const _DayCell({
    required this.day,
    required this.size,
    required this.active,
    required this.isToday,
    required this.inFuture,
  });

  @override
  Widget build(BuildContext context) {
    final BoxDecoration decoration;
    final Widget content;
    if (active) {
      // GitHub contribution-graph style — solid green tile with the day
      // number in white. Keeps the monthly grid scannable as "dense" vs
      // "sparse" at a glance, without the noise of 30 flame emojis.
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF40C463), Color(0xFF30A14E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(color: const Color(0xFF1D2939), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF30A14E).withOpacity(0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
      content = Center(
        child: Text(
          '$day',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (inFuture) {
      decoration = BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2F4F7)),
      );
      content = Center(
        child: Text(
          '$day',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFD0D5DD),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(color: const Color(0xFF667085), width: 2)
            : null,
      );
      content = Center(
        child: Text(
          '$day',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF667085),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Container(decoration: decoration, child: content),
    );
  }
}
