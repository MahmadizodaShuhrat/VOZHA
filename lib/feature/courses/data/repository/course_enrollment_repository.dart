import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which course the user is currently enrolled in (single active
/// enrollment at a time) and how many lesson videos they've opened
/// inside each course. Watch count gates the auto-enrollment popup
/// — the 4th video the user opens is the one that flips them to
/// "enrolled" and adds the course to "My courses".
///
/// Kept separate from [CourseProgressRepository] (which only tracks
/// completed lessons) so the enrollment / payment-gate logic doesn't
/// have to be tangled into the existing progress reads/writes.
abstract class CourseEnrollmentRepository {
  /// Currently active course ID. Null when the user has no enrollment
  /// or just finished their last enrolled course.
  Future<String?> getActiveCourseId();
  Future<void> setActiveCourseId(String? courseId);

  /// Set of lesson IDs the user has opened (counted as "watched") in
  /// the given course. Used by the player page to know when to fire
  /// the enrollment popup.
  Future<Set<String>> loadWatchedVideos(String courseId);

  /// Add [lessonId] to the watched-videos set for [courseId]. Returns
  /// the new full set so callers can decide whether the popup should
  /// fire (e.g. set length crosses the free-preview threshold).
  /// Idempotent — re-watching the same lesson does not bump the count.
  Future<Set<String>> markVideoWatched(String courseId, String lessonId);

  /// Whether the course's intro/preview video has already been
  /// watched all the way through. Once true, the hero video + "start
  /// course" CTA on the course-detail page collapse so the user
  /// lands directly on the lesson list.
  Future<bool> isCourseIntroWatched(String courseId);
  Future<void> setCourseIntroWatched(String courseId, bool value);
}

/// SharedPreferences-backed implementation. Storage layout:
/// - `active_enrolled_course` → string (or absent)
/// - `course_videos_watched_<courseId>` → JSON `{"watched":[...]}`
class LocalCourseEnrollmentRepository implements CourseEnrollmentRepository {
  LocalCourseEnrollmentRepository();

  static const _activeKey = 'active_enrolled_course';
  String _watchedKey(String courseId) => 'course_videos_watched_$courseId';
  String _introWatchedKey(String courseId) =>
      'course_intro_watched_$courseId';

  @override
  Future<String?> getActiveCourseId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_activeKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> setActiveCourseId(String? courseId) async {
    final prefs = await SharedPreferences.getInstance();
    if (courseId == null || courseId.isEmpty) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, courseId);
    }
  }

  @override
  Future<Set<String>> loadWatchedVideos(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_watchedKey(courseId));
    if (raw == null) return <String>{};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final list = (m['watched'] as List?)?.cast<String>() ?? const [];
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<Set<String>> markVideoWatched(
    String courseId,
    String lessonId,
  ) async {
    final current = await loadWatchedVideos(courseId);
    if (current.contains(lessonId)) return current;
    final updated = {...current, lessonId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _watchedKey(courseId),
      jsonEncode({'watched': updated.toList()}),
    );
    return updated;
  }

  @override
  Future<bool> isCourseIntroWatched(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introWatchedKey(courseId)) ?? false;
  }

  @override
  Future<void> setCourseIntroWatched(String courseId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_introWatchedKey(courseId), true);
    } else {
      await prefs.remove(_introWatchedKey(courseId));
    }
  }
}
