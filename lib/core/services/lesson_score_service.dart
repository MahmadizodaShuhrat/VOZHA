import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists test/workbook scores per lesson using SharedPreferences.
/// Key format: "ls_{categoryId}_{lessonIndex}_{type}_{testIndex}"
class LessonScoreService {
  static const _prefix = 'ls_';

  static String _key(int categoryId, int lessonIndex, String type,
      [int testIndex = 0]) {
    return '$_prefix${categoryId}_${lessonIndex}_${type}_$testIndex';
  }

  /// Save score when test/workbook is completed.
  static Future<void> saveScore({
    required int categoryId,
    required int lessonIndex,
    required String type, // "test" | "workbook"
    int testIndex = 0,
    required int correct,
    required int total,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({'correct': correct, 'total': total});
    await prefs.setString(_key(categoryId, lessonIndex, type, testIndex), data);
  }

  /// Get score for a specific test/workbook.
  static Future<LessonScore?> getScore({
    required int categoryId,
    required int lessonIndex,
    required String type,
    int testIndex = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(categoryId, lessonIndex, type, testIndex));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return LessonScore(
        correct: map['correct'] as int,
        total: map['total'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all test scores for a lesson (tries indices 0..9).
  static Future<List<LessonScore>> getTestScores(
    int categoryId,
    int lessonIndex,
  ) async {
    final scores = <LessonScore>[];
    for (int i = 0; i < 10; i++) {
      final s = await getScore(
        categoryId: categoryId,
        lessonIndex: lessonIndex,
        type: 'test',
        testIndex: i,
      );
      if (s != null) {
        scores.add(s);
      } else {
        break; // No more tests saved
      }
    }
    return scores;
  }

  /// Get workbook score for a lesson.
  static Future<LessonScore?> getWorkbookScore(
    int categoryId,
    int lessonIndex,
  ) async {
    return getScore(
      categoryId: categoryId,
      lessonIndex: lessonIndex,
      type: 'workbook',
    );
  }
}

/// A single test/workbook result.
class LessonScore {
  final int correct;
  final int total;

  const LessonScore({required this.correct, required this.total});

  double get percent => total > 0 ? correct / total * 100 : 0;
  bool get isDone => total > 0;
}
