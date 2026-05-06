import 'package:vozhaomuz/feature/courses/data/repository/course_state_storage.dart';

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

/// JSON-file-backed implementation. Storage layout:
/// - `<docs>/courses/_active.json` → `{"activeCourseId": "..."}`
/// - `<docs>/courses/<courseId>.json` → per-course payload, this repo
///   owns the `watched` (list) and `introWatched` (bool) keys.
class LocalCourseEnrollmentRepository implements CourseEnrollmentRepository {
  LocalCourseEnrollmentRepository();

  CourseStateStorage get _storage => CourseStateStorage.instance;

  @override
  Future<String?> getActiveCourseId() => _storage.readActiveCourseId();

  @override
  Future<void> setActiveCourseId(String? courseId) =>
      _storage.writeActiveCourseId(courseId);

  @override
  Future<Set<String>> loadWatchedVideos(String courseId) async {
    final data = await _storage.readCourse(courseId);
    final list = (data['watched'] as List?)?.cast<String>() ?? const [];
    return list.toSet();
  }

  @override
  Future<Set<String>> markVideoWatched(
    String courseId,
    String lessonId,
  ) async {
    final current = await loadWatchedVideos(courseId);
    if (current.contains(lessonId)) return current;
    final updated = {...current, lessonId};
    await _storage.updateCourse(courseId, {'watched': updated.toList()});
    return updated;
  }

  @override
  Future<bool> isCourseIntroWatched(String courseId) async {
    final data = await _storage.readCourse(courseId);
    return (data['introWatched'] as bool?) ?? false;
  }

  @override
  Future<void> setCourseIntroWatched(String courseId, bool value) async {
    await _storage.updateCourse(courseId, {'introWatched': value});
  }
}
