import 'package:flutter/material.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';

class HeaderWidget extends StatelessWidget {
  final String title;
  final EdgeInsets headingPadding;
  final Alignment alignment;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  
  const HeaderWidget({
    super.key,
    required this.title,
    this.textAlign = TextAlign.center,
    this.headingPadding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 13,
    ),
    required this.alignment,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: headingPadding,
      child: Align(
        alignment: alignment,
        child: Text(
          title, 
          style: textStyle ?? AppTextStyles.headingStyle, 
          textAlign: textAlign,
        ),
      ),
    );
  }
}
