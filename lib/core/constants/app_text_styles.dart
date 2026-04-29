import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';

class AppTextStyles {
  static TextStyle get bigTextButton => GoogleFonts.inter(
    color: AppColors.whiteText,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static TextStyle get mediumTextButton => GoogleFonts.inter(
    color: AppColors.whiteText,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get headingStyle => GoogleFonts.inter(
    fontWeight: FontWeight.w500,
    color: AppColors.headingText,
    fontSize: 16,
  );

  static TextStyle get hintextStyle => GoogleFonts.inter(
    color: Color(0xFFE3E8EF),
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get bigTextStyle => GoogleFonts.inter(
    color: Color.fromARGB(255, 26, 26, 26),
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get whiteTextStyle => GoogleFonts.inter(
    color: AppColors.whiteText,
    fontSize: 25,
    fontWeight: FontWeight.w300,
  );
}
