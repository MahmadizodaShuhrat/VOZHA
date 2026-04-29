import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_progress_repository.dart';
import 'package:vozhaomuz/feature/courses/presentation/providers/course_fixture_provider.dart';

/// Single repository instance. Persists to SharedPreferences for now;
/// swap with an API-backed implementation when the backend ships.
final courseProgressRepositoryProvider =
    Provider<CourseProgressRepository>((_) => CourseProgressRepository());

/// Set of completed lesson IDs for a given course. The first time a
/// user opens a course, it seeds itself from the JSON's
/// `status: "completed"` lessons so the demo content reflects the
/// fixture. After that, the persisted set takes over.
///
/// Mutate via [markLessonCompleted] (it invalidates this provider so
/// every watcher rebuilds).
final courseProgressProvider =
    FutureProvider.family<Set<String>, String>((ref, courseId) async {
  final repo = ref.read(courseProgressRepositoryProvider);
  final stored = await repo.load(courseId);
  if (stored.isNotEmpty) return stored;

  // First-run seed from the fixture's hard-coded statuses so the
  // demo course doesn't appear with zero progress on the first run.
  try {
    final course = await ref.read(courseByIdProvider(courseId).future);
    final seed = <String>{
      for (final m in course.modules)
        for (final l in m.lessons)
          if (l.status == LessonStatus.completed) l.id,
    };
    if (seed.isNotEmpty) await repo.save(courseId, seed);
    return seed;
  } catch (_) {
    return <String>{};
  }
});

/// Mark a lesson completed (idempotent) and invalidate the progress
/// provider so every consumer rebuilds with the new status overlay.
Future<void> markLessonCompleted(
  WidgetRef ref,
  String courseId,
  String lessonId,
) async {
  final repo = ref.read(courseProgressRepositoryProvider);
  await repo.markCompleted(courseId, lessonId);
  ref.invalidate(courseProgressProvider(courseId));
}

/// Helper: rebuilds a [CourseModule] list with each lesson's
/// [LessonStatus] derived from the persisted completion set —
/// completed → completed, the first non-completed lesson → current,
/// the rest → locked. Use this on the course-detail page so the JSON
/// statuses become the seed and the user's actual progress takes
/// over thereafter.
List<CourseModule> applyProgress(
  List<CourseModule> modules,
  Set<String> completedIds,
) {
  bool currentMarked = false;
  final out = <CourseModule>[];
  for (final m in modules) {
    final lessons = <CourseLesson>[];
    for (final l in m.lessons) {
      final LessonStatus status;
      if (completedIds.contains(l.id)) {
        status = LessonStatus.completed;
      } else if (!currentMarked) {
        status = LessonStatus.current;
        currentMarked = true;
      } else {
        status = LessonStatus.locked;
      }
      lessons.add(CourseLesson(
        id: l.id,
        type: l.type,
        title: l.title,
        durationLabel: l.durationLabel,
        durationSeconds: l.durationSeconds,
        status: status,
        video: l.video,
        words: l.words,
        games: l.games,
        questions: l.questions,
        test: l.test,
      ));
    }
    out.add(CourseModule(
      id: m.id,
      title: m.title,
      lessons: lessons,
      mainVideo: m.mainVideo,
      finalTest: m.finalTest,
      subtitle: m.subtitle,
    ));
  }
  return out;
}
