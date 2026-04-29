import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хизматрасонии In-App Review.
/// Баъди ҳар [_sessionThreshold] сессия диалоги баҳогузорӣ нишон медиҳад.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String _sessionCountKey = 'review_session_count';
  static const String _lastReviewKey = 'last_review_timestamp';
  static const int _sessionThreshold = 5; // Ҳар 5 сессия як бор
  static const int _minDaysBetweenReviews = 30; // Камаш 30 рӯз байни 2 review

  /// Шумораи сессияро зиёд мекунад ва агар шарт иҷро шавад, review мепурсад.
  /// Ин методро баъди battle result ё game result занед.
  Future<void> trackAndRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionCount = (prefs.getInt(_sessionCountKey) ?? 0) + 1;
      await prefs.setInt(_sessionCountKey, sessionCount);

      debugPrint('⭐ Review session count: $sessionCount');

      // Ҳар 5 сессия як маротиба review мепурсем
      if (sessionCount % _sessionThreshold != 0) return;

      // Санҷиш: оё 30 рӯз гузаштааст аз охирин review?
      final lastReview = prefs.getInt(_lastReviewKey) ?? 0;
      final daysSinceLastReview = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastReview))
          .inDays;

      if (lastReview != 0 && daysSinceLastReview < _minDaysBetweenReviews) {
        debugPrint(
          '⭐ Skipping review: only $daysSinceLastReview days since last',
        );
        return;
      }

      // Cанҷиш: оё review дастрас аст?
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await prefs.setInt(
          _lastReviewKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        debugPrint('⭐ In-App Review requested!');
      } else {
        debugPrint(
          '⭐ In-App Review not available (emulator or not from store)',
        );
      }
    } catch (e) {
      debugPrint('⭐ Review error (ignored): $e');
    }
  }
}
