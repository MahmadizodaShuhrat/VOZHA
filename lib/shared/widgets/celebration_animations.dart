import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Salyut/fireworks burst that plays once when mounted. Replay by giving
/// it a new [Key] (e.g. ValueKey of an incrementing counter) — each new
/// state instance restarts the animation.
class FireworksBurst extends StatefulWidget {
  /// Approximate radius of the burst in logical pixels.
  final double radius;
  final Duration duration;

  const FireworksBurst({
    super.key,
    this.radius = 110,
    this.duration = const Duration(milliseconds: 3000),
  });

  @override
  State<FireworksBurst> createState() => _FireworksBurstState();
}

class _FireworksBurstState extends State<FireworksBurst>
    with SingleTickerProviderStateMixin {
  static const _palette = <Color>[
    Color(0xFFFFD93D),
    Color(0xFFFF6B35),
    Color(0xFF12B76A),
    Color(0xFF3DA9FC),
    Color(0xFFE63946),
    Color(0xFF7A5AF8),
  ];

  late final AnimationController _controller;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();

    final rand = math.Random();
    const count = 22;
    _sparks = List.generate(count, (i) {
      final angle = (i / count) * 2 * math.pi + rand.nextDouble() * 0.4;
      return _Spark(
        angle: angle,
        distance: widget.radius * (0.7 + rand.nextDouble() * 0.6),
        color: _palette[rand.nextInt(_palette.length)],
        size: 5 + rand.nextDouble() * 4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.radius * 2.4;
    // SizedBox(0,0) reports zero size to the parent so the burst doesn't
    // grow the stack/column it's overlaid on. The inner OverflowBox then
    // gives its child new bounded constraints up to `box`, letting the
    // burst paint at full size and visually overflow the parent. The
    // parent must use `clipBehavior: Clip.none` for the overflow to show.
    return SizedBox(
      width: 0,
      height: 0,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: box,
        maxHeight: box,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => CustomPaint(
              painter: _FireworksPainter(
                t: _controller.value,
                sparks: _sparks,
              ),
              size: Size.square(box),
            ),
          ),
        ),
      ),
    );
  }
}

class _Spark {
  final double angle;
  final double distance;
  final Color color;
  final double size;

  const _Spark({
    required this.angle,
    required this.distance,
    required this.color,
    required this.size,
  });
}

class _FireworksPainter extends CustomPainter {
  final double t; // 0..1
  final List<_Spark> sparks;

  _FireworksPainter({required this.t, required this.sparks});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Eased outward travel + slight gravity drop in the second half.
    final travel = Curves.easeOutCubic.transform(t);
    final gravity = (t < 0.5 ? 0.0 : (t - 0.5) * 2);
    final fade = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4).clamp(0.0, 1.0);

    for (final s in sparks) {
      final dx = math.cos(s.angle) * s.distance * travel;
      final dy = math.sin(s.angle) * s.distance * travel + gravity * 6;
      final pos = center + Offset(dx, dy);

      final paint = Paint()
        ..color = s.color.withValues(alpha: fade)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s.size
        ..style = PaintingStyle.stroke;

      // Streak: draw a short trail behind the spark for "salyut" feel.
      final trailVec = Offset(math.cos(s.angle), math.sin(s.angle)) *
          (s.size * 2.2 + travel * 6);
      canvas.drawLine(pos - trailVec, pos, paint);

      // Bright head.
      final head = Paint()
        ..color = Colors.white.withValues(alpha: fade * 0.9);
      canvas.drawCircle(pos, s.size * 0.6, head);
    }

    // Initial flash at the center.
    if (t < 0.18) {
      final flashAlpha = (1 - t / 0.18).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        12 + t * 60,
        Paint()
          ..color = const Color(0xFFFFE08A).withValues(alpha: flashAlpha * 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter old) => old.t != t;
}

/// Clap burst — а few floating 👏 emojis that pop, drift up, and fade.
/// Same trigger contract as [FireworksBurst]: rebuild with a new [Key]
/// to replay.
class ClapBurst extends StatefulWidget {
  final double radius;
  final Duration duration;

  const ClapBurst({
    super.key,
    this.radius = 60,
    this.duration = const Duration(milliseconds: 3000),
  });

  @override
  State<ClapBurst> createState() => _ClapBurstState();
}

class _ClapBurstState extends State<ClapBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ClapEmoji> _emojis;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();

    final rand = math.Random();
    _emojis = List.generate(6, (i) {
      // Spread across an upward fan: angles between -150° and -30°.
      final base = math.pi + (i / 5) * (math.pi * 2 / 3) - math.pi / 6;
      return _ClapEmoji(
        angle: base + (rand.nextDouble() - 0.5) * 0.3,
        distance: widget.radius * (0.85 + rand.nextDouble() * 0.5),
        delay: i * 0.06 + rand.nextDouble() * 0.05,
        size: 26 + rand.nextDouble() * 10,
        rotation: (rand.nextDouble() - 0.5) * 0.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.radius * 2.4;
    // See FireworksBurst for the reason this is wrapped in
    // SizedBox(0,0) → OverflowBox.
    return SizedBox(
      width: 0,
      height: 0,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: box,
        maxHeight: box,
        child: IgnorePointer(
          child: SizedBox(
            width: box,
            height: box,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final e in _emojis) _buildEmoji(e),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmoji(_ClapEmoji e) {
    final raw = ((_controller.value - e.delay) / (1 - e.delay)).clamp(0.0, 1.0);
    if (raw == 0) return const SizedBox.shrink();

    final travel = Curves.easeOutCubic.transform(raw);
    final dx = math.cos(e.angle) * e.distance * travel;
    final dy = math.sin(e.angle) * e.distance * travel;

    final scale = raw < 0.25
        ? Curves.easeOutBack.transform(raw / 0.25)
        : 1.0 - (raw - 0.25) * 0.15;
    final opacity = raw < 0.7 ? 1.0 : (1.0 - (raw - 0.7) / 0.3).clamp(0.0, 1.0);

    final box = widget.radius * 2.4;
    return Positioned(
      left: box / 2 + dx - e.size / 2,
      top: box / 2 + dy - e.size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: e.rotation * raw,
          child: Transform.scale(
            scale: scale,
            child: Text(
              '👏',
              style: TextStyle(fontSize: e.size, height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClapEmoji {
  final double angle;
  final double distance;
  final double delay;
  final double size;
  final double rotation;

  const _ClapEmoji({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.size,
    required this.rotation,
  });
}
