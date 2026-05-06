import 'package:vozhaomuz/feature/courses/data/repository/course_state_storage.dart';

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

/// JSON-file-backed implementation used while the backend's
/// user-progress API is in development.
///
/// Each course gets a single file at
/// `<application docs>/courses/<courseId>.json`. The `completed` key
/// inside that JSON object holds the lesson-id list this repository
/// owns; other repositories (enrollment, intro flag) write to other
/// keys in the same file via [CourseStateStorage].
class LocalCourseProgressRepository implements CourseProgressRepository {
  LocalCourseProgressRepository();

  CourseStateStorage get _storage => CourseStateStorage.instance;

  @override
  Future<Set<String>> load(String courseId) async {
    final data = await _storage.readCourse(courseId);
    final list = (data['completed'] as List?)?.cast<String>() ?? const [];
    return list.toSet();
  }

  @override
  Future<void> save(String courseId, Set<String> completed) async {
    await _storage.updateCourse(courseId, {'completed': completed.toList()});
  }

  @override
  Future<Set<String>> markCompleted(String courseId, String lessonId) async {
    final current = await load(courseId);
    final updated = {...current, lessonId};
    await save(courseId, updated);
    return updated;
  }
}
