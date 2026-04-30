import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-course "which lessons has the user completed?" tracker.
/// Implementations decide where the data lives. The rest of the app
/// only talks to this interface so we can swap the storage backend
/// (local → remote) without touching consumers.
abstract class CourseProgressRepository {
  Future<Set<String>> load(String courseId);
  Future<void> save(String courseId, Set<String> completed);

  /// Mark one lesson as completed and persist. Returns the new full
  /// set so callers can update their UI immediately. Idempotent —
  /// safe to call twice for the same lesson.
  Future<Set<String>> markCompleted(String courseId, String lessonId);
}

/// SharedPreferences-backed implementation used while the backend's
/// user-progress API is in development.
///
/// Storage shape per course (key `course_progress_<id>`):
/// `{"completed":["welcome","first_words", ...]}`.
class LocalCourseProgressRepository implements CourseProgressRepository {
  LocalCourseProgressRepository();

  String _key(String courseId) => 'course_progress_$courseId';

  @override
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

  @override
  Future<void> save(String courseId, Set<String> completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(courseId),
      jsonEncode({'completed': completed.toList()}),
    );
  }

  @override
  Future<Set<String>> markCompleted(String courseId, String lessonId) async {
    final current = await load(courseId);
    final updated = {...current, lessonId};
    await save(courseId, updated);
    return updated;
  }
}
