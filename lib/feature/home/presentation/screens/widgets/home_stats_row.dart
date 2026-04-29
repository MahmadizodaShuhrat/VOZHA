import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/user_activity_provider.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/learning_streak_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/shared/widgets/celebration_animations.dart';
import 'package:vozhaomuz/shared/widgets/streak_history_dialog.dart';

/// User statistics row widget (days active, words learned, battle wins, ranking).
/// Extracted from home_page.dart for better maintainability.
class HomeStatsRow extends ConsumerWidget {
  const HomeStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(profileRatingProvider);
    // Streak comes from the newer `/user/activity` endpoint — it has the
    // correct current_streak while `profile-rating.days_active` still
    // returns the pre-fix value. Same source as the streak history dialog,
    // so both screens agree.
    final now = DateTime.now();
    final activityAsync = ref.watch(
      userActivityProvider((year: now.year, month: now.month)),
    );

    // Агар ҷоизаи silsila-и нагирифташуда мавҷуд бошад → flame-stat бо
    // animation-и хушдор намоиш меёбад, то корбар фаҳмад ки ҷоиза мунтазир
    // аст. Ҳамаи логика дар `learningStreakProvider` (manual-claim
    // milestones — 7/14/30/90/180/365 рӯз).
    final streakAsync = ref.watch(learningStreakProvider);
    final hasUnclaimedReward =
        streakAsync.asData?.value?.availableMilestones.any((m) => m.canClaim) ??
            false;

    return ratingAsync.when(
      // Keep showing cached data during refetches so the stat values can
      // animate smoothly between old and new numbers instead of flashing
      // through a shimmer on every invalidate.
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => _buildShimmerRow(),
      error: (_, _) => _buildShimmerRow(),
      data: (ratingData) {
        if (ratingData == null) return _buildShimmerRow();

        // Streak is computed from `/user/activity` — while that fetch is
        // still in-flight we show a shimmer placeholder instead of the
        // firstLaunch-based "1" fallback, so the user doesn't see a fake
        // number flash into the real one a second later.
        final activity = activityAsync.asData?.value;
        final streakLoading = activity == null;
        final int daysActive = activity?.currentStreak ?? 0;

        // Count learned words locally from the on-device progress. The
        // backend's `count_learned_words` aggregate only includes fully
        // mastered words (state ≥ 4, 3 successful repeats), which made
        // the home-page counter sit at 0 for new users for several days
        // even as they worked through a category. Product decision:
        // include every word the user has engaged with (state ≥ 1 —
        // learn session + repeat progress), and that count updates in
        // real time because `progressProvider` is patched optimistically
        // on every sync. Fully mastered words (state == 4) are still
        // included so the counter is monotonically non-decreasing.
        final progress = ref.watch(progressProvider);
        final activeLangKey = StorageService.instance.getTableWords();
        final wordsInActiveLang = progress.dirs[activeLangKey] ?? const [];
        final wordsLearned =
            wordsInActiveLang.where((w) => w.state > 0).length;
        final battleWins = ratingData.winsCount;
        final ranking = ratingData.rating;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _StatItem(
                emoji: '🔥',
                value: '$daysActive',
                label: 'days_active'.tr(),
                color: const Color(0xFFFF6B35),
                isLoading: streakLoading,
                hasReward: hasUnclaimedReward,
                onTap: () {
                  HapticFeedback.lightImpact();
                  StreakHistoryDialog.show(context);
                },
              ),
              const _StatDivider(),
              _LearnedStatTile(count: wordsLearned),
              const _StatDivider(),
              _StatItem(
                imageAsset: 'assets/images/UIHome/bum.png',
                value: '$battleWins',
                label: 'battle_wins'.tr(),
                color: const Color(0xFFF79009),
              ),
              const _StatDivider(),
              _RankingStatTile(ranking: ranking),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 24,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String? imageAsset;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  /// When true, render a shimmer placeholder in place of the value digit
  /// so the user doesn't see a stub (like "1") flash into the real number
  /// once the per-stat API finally returns.
  final bool isLoading;

  /// Агар ҷоизаи нагирифташудаи силсила мавҷуд бошад — icon бо glow-и
  /// pulsing, badge-и трофей ва subtle wiggle намоиш меёбад, то корбар
  /// "ҷоиза мунтазир аст"-ро дарк кунад. Танҳо аз stat-и силсила истифода
  /// мешавад; дигар stat-ҳо ҳамеша `false` мегузоранд.
  final bool hasReward;

  /// Optional one-shot effect rendered centered over the icon (fireworks,
  /// claps, etc.). Replay by passing a widget with a fresh [Key].
  final Widget? overlay;

  const _StatItem({
    this.icon,
    this.emoji,
    this.imageAsset,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
    this.hasReward = false,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;
    if (emoji != null) {
      iconWidget = Center(
        child: Text(emoji!, style: const TextStyle(fontSize: 18)),
      );
    } else if (imageAsset != null) {
      iconWidget = Center(
        child: Image.asset(imageAsset!, width: 18, height: 18),
      );
    } else {
      iconWidget = Icon(icon, color: color, size: 18);
    }

    final iconBox = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: iconWidget,
    );

    final Widget iconLayer = hasReward
        ? _RewardyIcon(color: color, child: iconBox)
        : iconBox;
    final Widget iconWithOverlay = overlay == null
        ? iconLayer
        : Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [iconLayer, overlay!],
          );

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWithOverlay,
          const SizedBox(height: 6),
          if (isLoading)
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: 20,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
            _AnimatedStatValue(value: value),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF98A2B3),
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      ),
    );
  }
}

/// Wraps the "learned words" stat and triggers a fireworks burst whenever
/// the count goes up by a small delta (i.e. the user actually learned new
/// words this session). Big jumps are skipped because they usually mean
/// `progressProvider` just hydrated from disk on first build.
class _LearnedStatTile extends StatefulWidget {
  final int count;

  const _LearnedStatTile({required this.count});

  @override
  State<_LearnedStatTile> createState() => _LearnedStatTileState();
}

class _LearnedStatTileState extends State<_LearnedStatTile> {
  int _burstKey = 0;

  @override
  void didUpdateWidget(covariant _LearnedStatTile old) {
    super.didUpdateWidget(old);
    final delta = widget.count - old.count;
    if (delta > 0 && delta <= 5) {
      _burstKey++;
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StatItem(
      imageAsset: 'assets/images/note-2.png',
      value: '${widget.count}',
      label: 'learned'.tr(),
      color: const Color(0xFF12B76A),
      overlay: _burstKey > 0
          ? FireworksBurst(key: ValueKey(_burstKey))
          : null,
    );
  }
}

/// Wraps the "rating" stat and triggers a clap burst whenever the user's
/// rank improves (rank number decreases) by a small step. Big jumps are
/// skipped because they usually mean the rating provider just hydrated
/// (e.g. switching from `-` to a real rank).
class _RankingStatTile extends StatefulWidget {
  /// 0-indexed rank from the backend; `< 0` means "not yet ranked".
  final int ranking;

  const _RankingStatTile({required this.ranking});

  @override
  State<_RankingStatTile> createState() => _RankingStatTileState();
}

class _RankingStatTileState extends State<_RankingStatTile> {
  int _burstKey = 0;

  @override
  void didUpdateWidget(covariant _RankingStatTile old) {
    super.didUpdateWidget(old);
    final oldRank = old.ranking;
    final newRank = widget.ranking;
    if (oldRank >= 0 && newRank >= 0 && newRank < oldRank &&
        (oldRank - newRank) <= 50) {
      _burstKey++;
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StatItem(
      icon: Icons.leaderboard_rounded,
      value: widget.ranking >= 0 ? '${widget.ranking + 1}' : '-',
      label: 'rating'.tr(),
      color: const Color(0xFF7A5AF8),
      overlay: _burstKey > 0
          ? ClapBurst(key: ValueKey(_burstKey))
          : null,
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: const Color(0xFFE4E7EC));
  }
}

/// Icon-и stat-и силсила вақте ки ҷоизаи нагирифташуда мавҷуд аст:
///   • халқаи pulsing glow дар атроф (рангаш ба color-и stat пайваста)
///   • subtle wiggle (rotation back-and-forth) дар icon — диққатҷалбкунанда
///     лекин не disturbing
///   • badge-и хурд-и тиллой "🏆" дар кунҷи рости боло, ки 'continuously
///     bouncing' тариқа дорад
class _RewardyIcon extends StatelessWidget {
  final Widget child;
  final Color color;

  const _RewardyIcon({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Pulsing glow дар атроф — мисли халқаи нур.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.45),
                  color.withValues(alpha: 0.0),
                ],
                stops: const [0.35, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.75, end: 1.15, duration: 1100.ms)
              .fadeIn(duration: 400.ms),
          // Icon-и асли бо subtle wiggle.
          child
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .rotate(begin: -0.04, end: 0.04, duration: 700.ms)
              .scaleXY(begin: 0.96, end: 1.04, duration: 1100.ms),
          // Badge-и трофей дар кунҷи рости боло — bouncing.
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFFDB022)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE48B0B).withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '🏆',
                  style: TextStyle(fontSize: 10, height: 1.0),
                ),
              ),
            )
                .animate()
                .scaleXY(
                  begin: 0.0,
                  end: 1.0,
                  duration: 540.ms,
                  curve: Curves.elasticOut,
                )
                .then()
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 1.0,
                  end: 1.18,
                  duration: 700.ms,
                  curve: Curves.easeInOut,
                ),
          ),
        ],
      ),
    );
  }
}

/// Stat number that rolls between the previous value and the new one
/// whenever [value] changes (e.g. rank 10 → 9 → 8 → 7 → 6 after a lesson).
/// The first render (and any parent rebuild without a value change) shows
/// the number instantly — no count-up from zero. Non-numeric values (like
/// "-" for unranked) are displayed as-is.
class _AnimatedStatValue extends StatefulWidget {
  final String value;

  const _AnimatedStatValue({required this.value});

  @override
  State<_AnimatedStatValue> createState() => _AnimatedStatValueState();
}

class _AnimatedStatValueState extends State<_AnimatedStatValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double? _current;

  static const _style = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1D2939),
    height: 1.1,
  );

  // When both the old and new value are whole, render as int;
  // otherwise render with one decimal so fractional energy ticks are visible.
  static String _format(double v, {required bool showDecimal}) {
    if (!showDecimal) return '${v.round()}';
    return v.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _current = double.tryParse(widget.value);
    _animation = AlwaysStoppedAnimation<double>(_current ?? 0);
  }

  @override
  void didUpdateWidget(covariant _AnimatedStatValue old) {
    super.didUpdateWidget(old);
    final parsed = double.tryParse(widget.value);
    if (parsed == null) {
      _current = null;
      return;
    }
    if (_current != null && (parsed - _current!).abs() < 0.0001) return;

    final from = _current ?? parsed;
    _current = parsed;
    _animation = Tween<double>(begin: from, end: parsed).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = double.tryParse(widget.value);
    if (parsed == null) {
      return Text(widget.value, style: _style);
    }
    final showDecimal = widget.value.contains('.');
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Text(
        _format(_animation.value, showDecimal: showDecimal),
        style: _style,
      ),
    );
  }
}
