import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

const _milestones = {7, 14, 30, 50, 100, 180, 365, 500, 1000};

class StreakPopup extends StatefulWidget {
  final int streak;
  /// Calendar dates the user was active on. Passed to the week row so
  /// each day of the current week can render its own flame/empty state
  /// based on real activity instead of a "last N days" assumption —
  /// reflects gaps and rest days accurately.
  final Set<DateTime> activeDates;

  const StreakPopup({
    super.key,
    required this.streak,
    this.activeDates = const {},
  });

  static Future<void> show(
    BuildContext context,
    int streak, {
    Set<DateTime> activeDates = const {},
  }) {
    HapticFeedback.mediumImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'streak',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => StreakPopup(
        streak: streak,
        activeDates: activeDates,
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
  }

  @override
  State<StreakPopup> createState() => _StreakPopupState();
}

class _StreakPopupState extends State<StreakPopup> {
  bool get _isMilestone => _milestones.contains(widget.streak);

  @override
  Widget build(BuildContext context) {
    final accent = _isMilestone
        ? const _Palette(
            glow: Color(0xFFFF6B00),
            outer: Color(0xFFFF1F00),
            mid: Color(0xFFFFB400),
            core: Color(0xFFFFF050),
          )
        : const _Palette(
            glow: Color(0xFFFF8A0A),
            outer: Color(0xFFE82200),
            mid: Color(0xFFFF9A1A),
            core: Color(0xFFFFDD33),
          );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Material(
          color: Colors.transparent,
          child: _buildCard(accent)
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: 820.ms,
              )
              .fadeIn(duration: 260.ms),
        ),
      ),
    );
  }

  Widget _buildCard(_Palette accent) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF4E1)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.glow.withValues(alpha: 0.28),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Big centrepiece flame removed — the week row at the bottom
          // (with its animated fire landing on today) is doing the
          // heavy lifting now, and the giant flame made the card feel
          // too busy.
          const SizedBox(height: 6),
          _SlotNumber(
            // Анимасия аз қимати дирӯз (streak-1) ба имрӯз (streak) —
            // popup танҳо дар лаҳзаи "+1 шудан"-и streak пайдо мешавад
            // (`shouldShowToday` як маротиба дар як рӯз), пас from = streak-1
            // ҳамеша дуруст. Барои streak=1 аввалин рӯз from=0 — мисли
            // қаблӣ.
            from: widget.streak > 0 ? widget.streak - 1 : 0,
            target: widget.streak,
            palette: accent,
          ),
          const SizedBox(height: 10),
          _buildPushChip(accent)
              .animate()
              .fadeIn(delay: 1000.ms, duration: 320.ms)
              .slideY(begin: 0.35, end: 0, delay: 1000.ms, duration: 380.ms),
          const SizedBox(height: 18),
          _WeekCalendar(
            streak: widget.streak,
            activeDates: widget.activeDates,
            accent: accent,
          )
              .animate()
              .fadeIn(delay: 1200.ms, duration: 320.ms)
              .slideY(begin: 0.25, end: 0, delay: 1200.ms, duration: 380.ms),
          const SizedBox(height: 22),
          _buildContinueButton(accent)
              .animate()
              .fadeIn(delay: 1450.ms, duration: 280.ms)
              .slideY(begin: 0.6, end: 0, delay: 1450.ms, duration: 380.ms),
        ],
      ),
    );
  }

  /// Orange pill containing the per-day motivational push text. Mirrors
  /// the Duolingo-style "2 дня подряд 🔥 это уже серьёзно" chip the
  /// design team referenced.
  Widget _buildPushChip(_Palette accent) {
    // `streak_push_day_N` is defined for 1..30. Fall back to a generic
    // subtitle for streaks past the table (rare — most users don't
    // hit day 30 between releases).
    final key = widget.streak <= 30
        ? 'streak_push_day_${widget.streak}'
        : 'streak_subtitle';
    final text = key.tr();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E1), Color(0xFFFFEBCC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD699), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9F1C).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent.mid, accent.outer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.outer.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A3E0F),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContinueButton(_Palette accent) {
    return MyButton(
      width: double.infinity,
      height: 52,
      depth: 4,
      borderRadius: 16,
      padding: EdgeInsets.zero,
      buttonColor: accent.mid,
      backButtonColor: accent.outer,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent.mid, accent.outer],
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
      },
      child: Center(
        child: Text(
          'streak_continue'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _Palette {
  final Color glow;
  final Color outer;
  final Color mid;
  final Color core;

  const _Palette({
    required this.glow,
    required this.outer,
    required this.mid,
    required this.core,
  });
}

/// Monday → Sunday row with a flame on every past day the user was
/// actually active this week (`activeDates`), an empty circle on today
/// which fills with an animated flame after a short delay (Duolingo-
/// style "fire lands on today"), and faint outlines for future days.
///
/// When `activeDates` is empty (e.g. first game on a fresh install, or
/// the `/user/activity` fetch failed) we degrade to a "streak covers the
/// last N days" approximation so the row still looks populated.
class _WeekCalendar extends StatelessWidget {
  final int streak;
  final Set<DateTime> activeDates;
  final _Palette accent;
  const _WeekCalendar({
    required this.streak,
    required this.activeDates,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    // weekday: 1=Mon..7=Sun → 0-indexed
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIdx = today.weekday - 1;
    // Monday of the current week as anchor.
    final monday = today.subtract(Duration(days: todayIdx));

    // Fallback band: when we have no real activity data the streak
    // itself tells us the last N days were active, so paint those.
    final coveredBefore = (streak - 1).clamp(0, todayIdx);
    final firstCovered = todayIdx - coveredBefore;
    final hasRealData = activeDates.isNotEmpty;

    // Use the existing translation bundle so we stay consistent with the
    // streak-history dialog labels (Дш,Сш,Чш,Пш,Ҷм,Шн,Як in Tajik).
    final labels = 'streak_weekday_labels'.tr().split(',');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        children: [
          // Weekday labels row.
          Row(
            children: List.generate(7, (i) {
              final isToday = i == todayIdx;
              return Expanded(
                child: Center(
                  child: Text(
                    labels[i].trim(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isToday
                          ? accent.outer
                          : const Color(0xFF98A2B3),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Circles row.
          Row(
            children: List.generate(7, (i) {
              _DayState state;
              if (i == todayIdx) {
                state = _DayState.today;
              } else if (i < todayIdx) {
                // Past day of this week.
                final isActive = hasRealData
                    ? activeDates.contains(monday.add(Duration(days: i)))
                    : (i >= firstCovered);
                state = isActive ? _DayState.active : _DayState.empty;
              } else {
                // Future day.
                state = _DayState.empty;
              }
              return Expanded(
                child: Center(
                  child: _DayCircle(state: state, accent: accent),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

enum _DayState { active, today, empty }

/// A single day's dot. Active days show an orange flame, future days
/// show a faint grey dot, and today renders as an outlined circle that
/// a flame flies into ~400ms after the row appears — matches the
/// Duolingo "today's flame just landed" moment.
class _DayCircle extends StatelessWidget {
  final _DayState state;
  final _Palette accent;
  const _DayCircle({required this.state, required this.accent});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _DayState.active:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [accent.mid, accent.outer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.outer.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text('🔥', style: TextStyle(fontSize: 14)),
          ),
        );
      case _DayState.empty:
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF2F4F7),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFCDD5DF),
              ),
            ),
          ),
        );
      case _DayState.today:
        // Two-layer stack so the flame can fly in on top of a persistent
        // outlined circle. The flame starts above the circle with
        // scale=0, drops down, then settles with an elastic bounce and
        // a gentle rotation — reads as "the flame just landed".
        return SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outlined "today" ring — accent-coloured so the user can
              // tell which day is being celebrated.
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: accent.outer, width: 2),
                ),
              ),
              // Flame lands in after the card animates open.
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent.mid, accent.outer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.outer.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 14)),
                ),
              )
                  .animate()
                  // Slow, deliberate fall from above — reads as "the
                  // flame is coming down to crown today". easeInCubic
                  // gives gravity-like acceleration into the circle.
                  .slideY(
                    begin: -2.4,
                    end: 0,
                    delay: 1600.ms,
                    duration: 820.ms,
                    curve: Curves.easeInCubic,
                  )
                  // Elastic landing — bigger swing so the flame really
                  // "sticks" to today. Extended duration so the bounce
                  // is visible, not a flash.
                  .scaleXY(
                    begin: 0.25,
                    end: 1.0,
                    delay: 1600.ms,
                    duration: 1100.ms,
                    curve: Curves.elasticOut,
                  )
                  .rotate(
                    begin: -0.25,
                    end: 0.0,
                    delay: 1600.ms,
                    duration: 820.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(delay: 1600.ms, duration: 400.ms)
                  // Post-landing pulse — two quick heartbeats that
                  // emphasise the impact without looking busy.
                  .then(delay: 220.ms)
                  .scaleXY(
                    begin: 1.0,
                    end: 1.18,
                    duration: 220.ms,
                    curve: Curves.easeOut,
                  )
                  .then()
                  .scaleXY(
                    begin: 1.18,
                    end: 1.0,
                    duration: 260.ms,
                    curve: Curves.easeIn,
                  )
                  .then(delay: 60.ms)
                  .scaleXY(
                    begin: 1.0,
                    end: 1.08,
                    duration: 180.ms,
                    curve: Curves.easeOut,
                  )
                  .then()
                  .scaleXY(
                    begin: 1.08,
                    end: 1.0,
                    duration: 220.ms,
                    curve: Curves.easeIn,
                  ),
            ],
          ),
        );
    }
  }
}

/// `from` slides up and fades out while the target streak slides in from
/// below with elastic bounce — slot-machine style. `from` одатан
/// `target - 1` аст (streak-и дирӯз), to-popup намоиш диҳад "1 → 2".
class _SlotNumber extends StatefulWidget {
  final int from;
  final int target;
  final _Palette palette;

  const _SlotNumber({
    required this.from,
    required this.target,
    required this.palette,
  });

  @override
  State<_SlotNumber> createState() => _SlotNumberState();
}

class _SlotNumberState extends State<_SlotNumber>
    with TickerProviderStateMixin {
  late final AnimationController _out;
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _out = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );

    Future.delayed(const Duration(milliseconds: 640), () {
      if (!mounted) return;
      _out.forward();
      Future.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        _in.forward();
      });
    });
  }

  @override
  void dispose() {
    _out.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const height = 96.0;
    return SizedBox(
      height: height,
      child: ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _out,
              builder: (_, _) {
                final v = Curves.easeInCubic.transform(_out.value);
                return Transform.translate(
                  offset: Offset(0, -height * 0.9 * v),
                  child: Opacity(
                    opacity: (1.0 - v).clamp(0.0, 1.0),
                    child: _numText('${widget.from}', widget.palette),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _in,
              builder: (_, _) {
                final raw = _in.value.clamp(0.0, 1.0);
                final slide = Curves.easeOutCubic.transform(raw);
                final scale = Curves.elasticOut.transform(raw);
                return Transform.translate(
                  offset: Offset(0, height * 0.9 * (1.0 - slide)),
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * scale,
                    child: Opacity(
                      opacity: raw,
                      child: _numText('${widget.target}', widget.palette),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _numText(String s, _Palette p) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.mid, p.outer],
      ).createShader(bounds),
      child: Text(
        s,
        style: const TextStyle(
          fontSize: 78,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.0,
          letterSpacing: -2,
        ),
      ),
    );
  }
}
