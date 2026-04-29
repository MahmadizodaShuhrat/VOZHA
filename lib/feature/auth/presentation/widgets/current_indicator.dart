import 'package:flutter/material.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';

class CurrentIndicator extends StatelessWidget {
  final int indicatorLength;
  final int currentIndex;
  final double size;
  final Alignment alignment;
  final EdgeInsets itempadding;
  const CurrentIndicator({
    super.key,
    required this.indicatorLength,
    required this.currentIndex,
    required this.size,
    required this.alignment,
    required this.itempadding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(
            indicatorLength,
            (index) => Padding(
              padding: itempadding,
              child: CircleAvatar(
                radius: size,
                backgroundColor:
                    currentIndex == index
                        ? AppColors.buttonColor
                        : Colors.blue[50],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
