import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized logger that works in both debug and release modes.
///
/// - Debug mode: prints to console via [debugPrint]
/// - Release mode: logs non-fatal errors to Firebase Crashlytics
///   so they are visible in the Firebase console.
class AppLogger {
  AppLogger._();

  /// Log a warning message. Visible in both debug and release.
  static void warning(String tag, String message) {
    debugPrint('⚠️ [$tag] $message');
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.log('[$tag] $message');
    }
  }

  /// Log an error with optional stack trace.
  /// In release mode, sends to Crashlytics as a non-fatal error.
  static void error(String tag, Object error, [StackTrace? stackTrace]) {
    debugPrint('❌ [$tag] $error');
    if (stackTrace != null && kDebugMode) {
      debugPrint('$stackTrace');
    }
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace ?? StackTrace.current,
        reason: tag,
        fatal: false,
      );
    }
  }

  /// Log informational message (debug only, no Crashlytics).
  static void info(String tag, String message) {
    debugPrint('ℹ️ [$tag] $message');
  }
}
