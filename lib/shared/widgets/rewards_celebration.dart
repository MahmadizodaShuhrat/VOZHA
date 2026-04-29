import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key that stores the last local calendar date
/// (YYYY-MM-DD) the celebration dialog was shown. The dialog is
/// intentionally limited to one appearance per day — the backend's
/// `streakCoins > 0` signal also only fires once per day, but we
/// keep a client-side guard in case the server double-issues the
/// bonus during a retry.
const String _kLastCelebrationDateKey = 'last_rewards_celebration_date';

String _todayKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// Celebration popup shown after a sync response credits the user coins.
///
/// Composes one row per reward source:
///   • 🎉 words        — `count` from sync response
///   • 🔥 streak       — `streak_coins` (daily bonus)
///   • 🏅 achievements — sum of `new_achievements[].coins_earned`
///
/// Auto-dismisses after 3s; users can also tap anywhere or the OK button to
/// close sooner. Nothing is shown when [wordCoins + streakCoins + achievementCoins]
/// is zero — call sites should check before invoking.
Future<void> showRewardsCelebration(
  BuildContext context, {
  required int wordCoins,
  required int streakCoins,
  required int achievementCoins,
  List<String> achievementNames = const [],
}) async {
  final total = wordCoins + streakCoins + achievementCoins;
  if (total <= 0 && achievementNames.isEmpty) return;

  // Once-per-day gate: the dialog should surface the FIRST time the
  // user earns coins on a given local calendar day. Subsequent sessions
  // the same day already have the popup "banked" in SharedPreferences
  // and are silently skipped. We deliberately don't gate on the
  // backend's `streakCoins` field because some sync flows omit it
  // even on the first session — the client-side date stamp is the
  // reliable source of truth for "have we celebrated today yet".
  final prefs = await SharedPreferences.getInstance();
  final today = _todayKey();
  final lastShown = prefs.getString(_kLastCelebrationDateKey);
  if (lastShown == today) return;
  await prefs.setString(_kLastCelebrationDateKey, today);

  if (!context.mounted) return;
  HapticFeedback.mediumImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (_, __, ___) => _RewardsCelebrationDialog(
      wordCoins: wordCoins,
      streakCoins: streakCoins,
      achievementCoins: achievementCoins,
      achievementNames: achievementNames,
      total: total,
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.75, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class _RewardsCelebrationDialog extends StatefulWidget {
  final int wordCoins;
  final int streakCoins;
  final int achievementCoins;
  final List<String> achievementNames;
  final int total;

  const _RewardsCelebrationDialog({
    required this.wordCoins,
    required this.streakCoins,
    required this.achievementCoins,
    required this.achievementNames,
    required this.total,
  });

  @override
  State<_RewardsCelebrationDialog> createState() =>
      _RewardsCelebrationDialogState();
}

class _RewardsCelebrationDialogState extends State<_RewardsCelebrationDialog> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss so the user isn't stuck staring at the popup if they
    // don't tap — long enough to read the numbers.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

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
              colors: [
                Color(0xFFFFF8EC), // soft cream at top — coin-themed
                Colors.white,
              ],
              stops: [0.0, 0.45],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFDB022).withValues(alpha: 0.22),
                blurRadius: 50,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative top accent band — a soft gold gradient with
              // blue highlights that reads as "celebration" without
              // stealing attention from the medallion.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 130,
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
              // Faint sparkle confetti drifting down in the header.
              const Positioned.fill(
                child: IgnorePointer(
                  child: _Sparkles(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TotalMedallion(total: widget.total),
                    const SizedBox(height: 16),
                    Text(
                      'rewards_celebration_title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D2939),
                        letterSpacing: -0.3,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 240.ms, duration: 320.ms)
                        .slideY(
                          begin: 0.25,
                          end: 0,
                          delay: 240.ms,
                          duration: 360.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 16),
                    // Reward breakdown chips. Each non-zero source
                    // animates in independently so the values read.
                    if (widget.wordCoins > 0)
                      _RewardChip(
                        icon: '🎉',
                        accent: const Color(0xFFFDB022),
                        label: 'rewards_celebration_words'.tr(),
                        value: widget.wordCoins,
                        delay: 340.ms,
                      ),
                    if (widget.streakCoins > 0)
                      _RewardChip(
                        icon: '🔥',
                        accent: const Color(0xFFF97316),
                        label: 'rewards_celebration_streak'.tr(),
                        value: widget.streakCoins,
                        delay: 420.ms,
                      ),
                    if (widget.achievementCoins > 0)
                      _RewardChip(
                        icon: '🏅',
                        accent: const Color(0xFFB45309),
                        label: 'rewards_celebration_achievements'.tr(),
                        value: widget.achievementCoins,
                        delay: 500.ms,
                      ),
                    if (widget.achievementNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (int i = 0; i < widget.achievementNames.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '🏅 ${widget.achievementNames[i]}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB45309),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                delay: (580 + i * 80).ms,
                                duration: 300.ms,
                              )
                              .slideY(
                                begin: 0.3,
                                end: 0,
                                delay: (580 + i * 80).ms,
                              ),
                        ),
                    ],
                    const SizedBox(height: 22),
                    _PrimaryButton(
                      label: 'rewards_celebration_ok'.tr(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
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

/// Big gold coin "medallion" with the total reward — the visual anchor
/// of the popup. Combines a pulsing outer glow, a gradient coin face,
/// a specular highlight, and a small satellite coin that springs in.
class _TotalMedallion extends StatelessWidget {
  final int total;
  const _TotalMedallion({required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring — reads as "glow" behind the coin.
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFDB022).withValues(alpha: 0.32),
                  const Color(0xFFFDB022).withValues(alpha: 0.0),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.88, end: 1.1, duration: 1500.ms),
          // Main coin face.
          Container(
            width: 108,
            height: 108,
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
                stops: [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFFFFE08A),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE48B0B).withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top-left specular highlight — makes the disc read as
                // glossy rather than flat orange.
                Positioned(
                  top: 8,
                  left: 14,
                  child: Container(
                    width: 34,
                    height: 18,
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
                Center(
                  child: Text(
                    '+$total',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.2,
                      shadows: [
                        Shadow(
                          color: Color(0x40000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .scaleXY(
                begin: 0.25,
                end: 1.0,
                duration: 680.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 260.ms),
          // Small satellite coin that springs in from the corner.
          Positioned(
            top: 10,
            right: 8,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFFDB022)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE48B0B).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Image(
                  image: AssetImage('assets/images/coin.png'),
                  width: 22,
                  height: 22,
                ),
              ),
            )
                .animate()
                .scaleXY(
                  begin: 0.1,
                  end: 1.0,
                  delay: 260.ms,
                  duration: 560.ms,
                  curve: Curves.elasticOut,
                )
                .rotate(
                  begin: -0.25,
                  end: 0.0,
                  delay: 260.ms,
                  duration: 560.ms,
                ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped chip describing one source of coins. Replaces the old
/// three-column row — reads more like a receipt line and matches the
/// app's general "rounded info pill" visual vocabulary.
class _RewardChip extends StatelessWidget {
  final String icon;
  final Color accent;
  final String label;
  final int value;
  final Duration delay;

  const _RewardChip({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF344054),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+$value',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Image(
                    image: AssetImage('assets/images/coin.png'),
                    width: 16,
                    height: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: delay, duration: 300.ms)
        .slideX(begin: 0.2, end: 0, delay: delay, duration: 360.ms);
  }
}

/// Primary action button matching the app's "pill with bottom-shadow
/// depth" style used on home action buttons and MyButton — keeps the
/// popup visually continuous with the rest of the app.
class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
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
                      color: const Color(0xFFE48B0B).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              widget.label,
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
        .fadeIn(delay: 620.ms, duration: 300.ms)
        .slideY(begin: 0.3, end: 0, delay: 620.ms, duration: 320.ms);
  }
}

/// Tiny decorative sparkle field scattered around the header — adds
/// celebration feel without blocking the content.
class _Sparkles extends StatelessWidget {
  const _Sparkles();

  @override
  Widget build(BuildContext context) {
    // Deterministic positions so the effect is stable per render.
    final rng = math.Random(42);
    final dots = List.generate(14, (i) {
      return _SparkleDot(
        left: 8 + rng.nextDouble() * 300,
        top: 6 + rng.nextDouble() * 120,
        size: 4 + rng.nextDouble() * 6,
        delay: Duration(milliseconds: 60 + rng.nextInt(700)),
        color: i.isEven
            ? const Color(0xFFFDB022)
            : const Color(0xFF2E90FA),
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
          color: color.withValues(alpha: 0.6),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 600.ms, delay: delay)
          .scaleXY(
            begin: 0.4,
            end: 1.0,
            duration: 900.ms,
            delay: delay,
          ),
    );
  }
}
