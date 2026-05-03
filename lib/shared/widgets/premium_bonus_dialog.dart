import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/rating/data/models/premium_bonus_dto.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// "+1 day premium" celebration shown when the activity / sync
/// endpoints return a `premium_bonus.granted: true` block.
///
/// One modal per grant — the backend's UNIQUE constraint on
/// `(user_id, streak_run_id, milestone_streak)` guarantees the same
/// bonus can't ship twice in the same response. After the modal
/// closes the caller MUST refresh the user profile so
/// `userType`/`tariff_expired_at` reflect the new bonus.
Future<void> showPremiumBonusDialog(
  BuildContext context, {
  required PremiumBonusDto bonus,
}) async {
  HapticFeedback.mediumImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (_, _, _) => _PremiumBonusDialog(bonus: bonus),
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.78,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class _PremiumBonusDialog extends StatelessWidget {
  final PremiumBonusDto bonus;
  const _PremiumBonusDialog({required this.bonus});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFDB022).withValues(alpha: 0.32),
                blurRadius: 60,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative top-band — soft cream-to-blue gradient
              // matching the app's celebration aesthetic.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFE8A3),
                        Color(0xFFFFF4E1),
                        Color(0xFFE8F0FE),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              // Confetti / sparkle layer.
              const Positioned.fill(child: IgnorePointer(child: _Sparkles())),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CrownBadge(),
                    const SizedBox(height: 16),
                    // Hero "+1 day" number was hidden at the user's
                    // request — empty box keeps the original layout
                    // breathing room between the crown and the title
                    // so nothing else jumps up.
                    const SizedBox(height: 70),
                    Text(
                          'streak_premium_modal_title'.tr(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D2939),
                            letterSpacing: -0.3,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 280.ms, duration: 320.ms)
                        .slideY(begin: 0.2, end: 0, delay: 280.ms),
                    const SizedBox(height: 6),
                    Text(
                      'streak_premium_modal_subtitle'.tr(
                        namedArgs: {'days': '${bonus.milestoneStreak}'},
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate().fadeIn(delay: 360.ms, duration: 280.ms),
                    if (bonus.newPremiumUntil != null) ...[
                      const SizedBox(height: 16),
                      _UntilCard(date: bonus.newPremiumUntil!),
                    ],
                    const SizedBox(height: 26),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrownBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring.
          Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFDB022).withValues(alpha: 0.45),
                      const Color(0xFFFDB022).withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.78, end: 1.12, duration: 1400.ms)
              .fadeIn(duration: 320.ms),
          // Solid medallion.
          Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFE08A),
                      Color(0xFFFDB022),
                      Color(0xFFE48B0B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE48B0B).withValues(alpha: 0.5),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                alignment: Alignment.center,
                child: const Text('👑', style: TextStyle(fontSize: 40)),
              )
              .animate()
              .scaleXY(
                begin: 0.4,
                end: 1.0,
                duration: 560.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 320.ms),
        ],
      ),
    );
  }
}

class _UntilCard extends StatelessWidget {
  final DateTime date;
  const _UntilCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final localeTag = context.locale.toLanguageTag();
    final formatted = DateFormat.yMMMMd(localeTag).format(date.toLocal());
    return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEF6E7), Color(0xFFFFFBEB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFDB022).withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDB022), Color(0xFFE48B0B)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'streak_premium_modal_body'.tr(
                    namedArgs: {'date': formatted},
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 460.ms, duration: 320.ms)
        .slideY(begin: 0.15, end: 0, delay: 460.ms);
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MyButton(
      width: double.infinity,
      depth: 4,
      borderRadius: 14,
      buttonColor: const Color(0xFFFDB022),
      backButtonColor: const Color(0xFFE48B0B),
      padding: const EdgeInsets.symmetric(vertical: 14),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            'streak_premium_modal_close'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint sparkles drifting through the gradient header — pure
/// decoration. Painter so we don't ship 30 individual widgets.
class _Sparkles extends StatefulWidget {
  const _Sparkles();

  @override
  State<_Sparkles> createState() => _SparklesState();
}

class _SparklesState extends State<_Sparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    final rand = math.Random(7);
    _sparkles = List.generate(14, (_) => _Sparkle.random(rand));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        painter: _SparklesPainter(t: _ctrl.value, sparkles: _sparkles),
      ),
    );
  }
}

class _Sparkle {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  const _Sparkle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
  });
  factory _Sparkle.random(math.Random r) => _Sparkle(
    dx: r.nextDouble(),
    dy: r.nextDouble() * 0.55, // confined to top band
    size: 2 + r.nextDouble() * 3,
    phase: r.nextDouble(),
  );
}

class _SparklesPainter extends CustomPainter {
  final double t;
  final List<_Sparkle> sparkles;
  _SparklesPainter({required this.t, required this.sparkles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      final phase = (t + s.phase) % 1.0;
      final alpha = (math.sin(phase * 2 * math.pi) + 1) / 2 * 0.7;
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.size,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklesPainter old) => old.t != t;
}
