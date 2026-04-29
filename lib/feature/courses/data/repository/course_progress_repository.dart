import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tiny key/value store for "which lessons has the user completed in
/// course X?". Exists so we can track progress locally until the
/// backend's user-progress API ships — once that happens, swap this
/// for the API call and the UI keeps working.
///
/// Storage shape per course (key `course_progress_<id>`):
/// `{"completed":["welcome","first_words", ...]}`.
class CourseProgressRepository {
  CourseProgressRepository();

  String _key(String courseId) => 'course_progress_$courseId';

  Future<Set<String>> load(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(courseId));
    if (raw == null) return <String>{};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final list = (m['completed'] as List?)?.cast<String>() ?? const [];
      return list.toSet();
    } catch (_) {
      // Corrupt storage — start over rather than throw at the user.
      return <String>{};
    }
  }

  Future<void> save(String courseId, Set<String> completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(courseId),
      jsonEncode({'completed': completed.toList()}),
    );
  }

  /// Mark one lesson as completed and persist. Returns the new full
  /// set so callers can update their UI immediately.
  Future<Set<String>> markCompleted(String courseId, String lessonId) async {
    final current = await load(courseId);
    final updated = {...current, lessonId};
    await save(courseId, updated);
    return updated;
  }
}
