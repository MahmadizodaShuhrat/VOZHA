import 'dart:math';

import 'package:flutter/material.dart';

class DirectionArrow extends StatelessWidget {
  final Point<int> direction;
  const DirectionArrow({super.key, required this.direction});

  @override
  Widget build(BuildContext context) {
      Alignment alignment;
      double rotation;

      if (direction.x == -1) {
        alignment = Alignment.bottomCenter;
        rotation = 0;
      } else if (direction.x == 1) {
        alignment = Alignment.topCenter;
        rotation = pi;
      } else if (direction.y == -1) {
        alignment = Alignment.centerRight;
        rotation = -pi / 2;
      } else {
        alignment = Alignment.centerLeft;
        rotation = pi / 2;
      }

      return Align(
        alignment: alignment,
        child: Transform.rotate(
          angle: rotation,
          child: CustomPaint(
            size: Size(12, 6),
            painter: TrianglePainter(),
          ),
        ),
      );
  }
}


class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xffff4322)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
