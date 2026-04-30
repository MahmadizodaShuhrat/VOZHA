import 'package:flutter/material.dart';

/// Single source of truth for the courses feature's brand palette
/// and shared spacing tokens. Replaces the dozens of inline
/// `Color(0xFF…)` literals scattered through the screen widgets.
class CourseColors {
  CourseColors._();

  // Brand
  static const brand = Color(0xFF2E90FA);
  static const brandDark = Color(0xFF1D4ED8);
  static const brandLight = Color(0xFF60A5FA);
  static const brandSurface = Color(0xFFEFF6FF);

  // Semantic — lesson status
  static const completed = Color(0xFF12B76A);
  static const completedSurface = Color(0xFFECFDF3);
  static const current = Color(0xFFF79009);
  static const locked = Color(0xFF98A2B3);

  // Neutrals
  static const ink = Color(0xFF0F172A);
  static const inkSoft = Color(0xFF1D2939);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const surface = Color(0xFFF5FAFF);

  // Accents
  static const gold = Color(0xFFFDB022);
  static const goldDark = Color(0xFFE48B0B);
  static const purple = Color(0xFF7A5AF8);
}

/// Shared durations / spacing for animations on the course screens.
class CourseMotion {
  CourseMotion._();

  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
}
