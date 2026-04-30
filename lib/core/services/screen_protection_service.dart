import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';

/// Tiny wrapper around Android's `FLAG_SECURE`. Enabling the flag
/// makes Android refuse to capture the window in screenshots or
/// screen recordings — captures show up as a black frame instead.
///
/// Used by [LessonPlayerPage] (and any other page that displays paid
/// course content) to discourage trivial pirating. Always disable
/// the flag when leaving the protected screen — otherwise the rest
/// of the app stays uncapturable for the whole session.
///
/// iOS has no FLAG_SECURE equivalent. AirPlay / hardware capture is
/// detectable via `UIScreen.isCaptured` and blockable by replacing
/// the screen with a privacy view, but that's a separate native
/// integration we haven't built yet — this service is a no-op on
/// platforms other than Android.
class ScreenProtectionService {
  ScreenProtectionService._();

  /// Block screenshots / screen recording for the current window.
  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterWindowManagerPlus.addFlags(
        FlutterWindowManagerPlus.FLAG_SECURE,
      );
    } catch (e) {
      debugPrint('ScreenProtectionService.enable failed: $e');
    }
  }

  /// Re-allow screenshots / screen recording.
  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterWindowManagerPlus.clearFlags(
        FlutterWindowManagerPlus.FLAG_SECURE,
      );
    } catch (e) {
      debugPrint('ScreenProtectionService.disable failed: $e');
    }
  }
}
