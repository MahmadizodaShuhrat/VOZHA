import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Ҷашни гирифтани ҷоизаи силсила (streak milestone). Корбар тугмаи
/// "Гирифтан"-ро мезанад → серверро муваффақият мегардонад → ин popup
/// бо counter-и анимасия-шудаи тангаҳо ва эффектҳои ҷашнӣ намоиш меёбад.
Future<void> showMilestoneClaimCelebration(
  BuildContext context, {
  required int days,
  required int coinsEarned,
}) async {
  HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => _MilestoneClaimDialog(
      days: days,
      coinsEarned: coinsEarned,
    ),
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class _MilestoneClaimDialog extends StatelessWidget {
  final int days;
  final int coinsEarned;

  const _MilestoneClaimDialog({
    required this.days,
    required this.coinsEarned,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF8EC), Colors.white],
              stops: [0.0, 0.55],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFDB022).withValues(alpha: 0.28),
                blurRadius: 50,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Декоративи sparkles дар атроф.
              const Positioned.fill(
                child: IgnorePointer(child: _Sparkles()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TrophyBadge(days: days),
                    const SizedBox(height: 18),
                    Text(
                      'milestone_celebration_title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D2939),
                        letterSpacing: -0.3,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 320.ms, duration: 320.ms)
                        .slideY(
                          begin: 0.25,
                          end: 0,
                          delay: 320.ms,
                          duration: 360.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 8),
                    Text(
                      'milestone_celebration_subtitle'.tr(
                        namedArgs: {'days': '$days'},
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 420.ms, duration: 280.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          delay: 420.ms,
                          duration: 320.ms,
                        ),
                    const SizedBox(height: 22),
                    _CoinCounter(coinsEarned: coinsEarned),
                    const SizedBox(height: 26),
                    _ContinueButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
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

/// Знак-и трофей бо силсилаи "N рӯз" дар поён. Pulsing glow дар атроф.
class _TrophyBadge extends StatelessWidget {
  final int days;

  const _TrophyBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer glow.
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFDB022).withValues(alpha: 0.35),
                  const Color(0xFFFDB022).withValues(alpha: 0.0),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.85, end: 1.12, duration: 1400.ms),
          // Корпус-и медаль.
          Container(
            width: 110,
            height: 110,
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
                stops: [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: const Color(0xFFFFE08A), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE48B0B).withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Highlight-и тиҷоратӣ.
                Positioned(
                  top: 10,
                  left: 18,
                  child: Container(
                    width: 32,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 56)),
                ),
              ],
            ),
          )
              .animate()
              .scaleXY(
                begin: 0.2,
                end: 1.0,
                duration: 720.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 280.ms)
              .then(delay: 200.ms)
              .shake(hz: 3, duration: 480.ms, rotation: 0.04),
          // Badge-и силсила "N рӯз" дар поён-чап.
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    'milestone_celebration_days_badge'.tr(
                      namedArgs: {'days': '$days'},
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 280.ms)
                .scaleXY(
                  begin: 0.4,
                  end: 1.0,
                  delay: 600.ms,
                  duration: 480.ms,
                  curve: Curves.elasticOut,
                ),
          ),
        ],
      ),
    );
  }
}

/// Counter бо анимасияи рост афзоянда: аз 0 то `coinsEarned` дар 1.2с.
/// Дар атроф асарӣ glow ва тангачаҳои хурд парвоз мекунанд.
class _CoinCounter extends StatelessWidget {
  final int coinsEarned;

  const _CoinCounter({required this.coinsEarned});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E1), Color(0xFFFFE6B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFDB022).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDB022).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Тангаи кашфшуда бо spin entrance.
          const Image(
            image: AssetImage('assets/images/coin.png'),
            width: 38,
            height: 38,
          )
              .animate()
              .scaleXY(
                begin: 0.0,
                end: 1.0,
                delay: 540.ms,
                duration: 620.ms,
                curve: Curves.elasticOut,
              )
              .rotate(
                begin: -0.5,
                end: 0.0,
                delay: 540.ms,
                duration: 620.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(width: 14),
          // Counter аз 0 ба coinsEarned.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (_, t, _) {
              final shown = (coinsEarned * t).round();
              return Text(
                '+$shown',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB45309),
                  letterSpacing: -1.0,
                  shadows: [
                    Shadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 480.ms, duration: 320.ms)
        .slideY(
          begin: 0.4,
          end: 0,
          delay: 480.ms,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _ContinueButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ContinueButton({required this.onTap});

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 90),
        offset: Offset(0, _pressed ? 0.04 : 0),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFC24C), Color(0xFFFDB022)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(
                color: _pressed
                    ? Colors.transparent
                    : const Color(0xFFE48B0B),
                width: 4,
              ),
            ),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: const Color(0xFFE48B0B).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              'milestone_celebration_continue'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 280.ms)
        .slideY(
          begin: 0.4,
          end: 0,
          delay: 800.ms,
          duration: 320.ms,
        );
  }
}

/// Тандем-и нуқтаҳои тилло-кабуди парокандашуда дар атроф — celebration feel.
class _Sparkles extends StatelessWidget {
  const _Sparkles();

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(7);
    final dots = List.generate(18, (i) {
      return _SparkleDot(
        left: 10 + rng.nextDouble() * 320,
        top: 10 + rng.nextDouble() * 360,
        size: 4 + rng.nextDouble() * 7,
        delay: Duration(milliseconds: 80 + rng.nextInt(900)),
        color: i.isEven
            ? const Color(0xFFFDB022)
            : const Color(0xFFE53935),
      );
    });
    return Stack(children: dots);
  }
}

class _SparkleDot extends StatelessWidget {
  final double left;
  final double top;
  final double size;
  final Duration delay;
  final Color color;

  const _SparkleDot({
    required this.left,
    required this.top,
    required this.size,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.7),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 600.ms, delay: delay)
          .scaleXY(
            begin: 0.3,
            end: 1.0,
            duration: 900.ms,
            delay: delay,
          ),
    );
  }
}
