import 'dart:math';

import 'package:flutter/material.dart';

/// Unity-parity status circle indicator.
///
/// Unity `UIWordItemState.SetStatus()` uses 3 separate circle images,
/// each colored green (#20CD7F), red (#E6394F), or grey (#D4DAE5)
/// depending on the word's learning state.
///
/// State → Segment colors:
///  -3 → [red, red, red]
///  -2 → [red, grey, red]
///  -1 → [red, grey, grey]
///   0 → [grey, grey, grey]
///   1 → [green, grey, grey]
///   2 → [green, grey, green]
///   3 → [green, green, green]
///  4+ → [green, green, green] (+ check mark drawn externally)
class SegmentedCirclePainter extends CustomPainter {
  final double strokeWidth;
  final int state;

  static const _green = Color(0xFF20CD7F);
  static const _red = Color(0xFFE6394F);
  static const _grey = Color(0xFFD4DAE5);

  SegmentedCirclePainter({
    required this.strokeWidth,
    required this.state,
  });

  List<Color> get _segmentColors {
    switch (state) {
      case -3:
        return [_red, _red, _red];
      case -2:
        return [_red, _grey, _red];
      case -1:
        return [_red, _grey, _grey];
      case 1:
        return [_green, _grey, _grey];
      case 2:
        return [_green, _grey, _green];
      case 3:
        return [_green, _green, _green];
      case >= 4:
        return [_green, _green, _green];
      default:
        return [_grey, _grey, _grey];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final colors = _segmentColors;

    const segmentAngle = 2 * pi / 3; // 120° per segment
    const gap = 0.6; // gap between segments (radians)

    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 + i * segmentAngle,
        segmentAngle - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedCirclePainter oldDelegate) =>
      oldDelegate.state != state;
}
