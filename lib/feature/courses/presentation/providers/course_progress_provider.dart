import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_enrollment_repository.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_progress_repository.dart';
import 'package:vozhaomuz/feature/courses/presentation/providers/course_fixture_provider.dart';

/// Number of lesson videos the user can watch in a course before the
/// auto-enrollment popup triggers. The 4th unique lesson video they
/// open is the one that flips them to "enrolled".
const int kFreePreviewVideos = 3;

/// Single repository instance. Persists to SharedPreferences for now;
/// swap the override with a remote-backed implementation when the
/// backend ships and consumers don't need to change.
final courseProgressRepositoryProvider =
    Provider<CourseProgressRepository>((_) => LocalCourseProgressRepository());

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

// ─────────────────────────── Enrollment ───────────────────────────

/// Single repository instance for enrollment + video-watch tracking.
final courseEnrollmentRepositoryProvider =
    Provider<CourseEnrollmentRepository>(
        (_) => LocalCourseEnrollmentRepository());

/// The course ID the user is currently enrolled in (auto-set on the
/// 4th video they watch). Null when the user has no active enrollment
/// or just finished their last enrolled course.
///
/// Mutate via [enrollInCourse] / [clearActiveCourse]; both invalidate
/// this provider so every consumer rebuilds.
final activeCourseIdProvider = FutureProvider<String?>((ref) async {
  final repo = ref.read(courseEnrollmentRepositoryProvider);
  return repo.getActiveCourseId();
});

/// Set of lesson IDs the user has opened (counted as "watched") for
/// the given course. Combined with [kFreePreviewVideos] this drives
/// the auto-enrollment popup trigger inside the player page.
final watchedVideosProvider =
    FutureProvider.family<Set<String>, String>((ref, courseId) async {
  final repo = ref.read(courseEnrollmentRepositoryProvider);
  return repo.loadWatchedVideos(courseId);
});

/// Whether the course's intro/preview video has been watched all the
/// way through. Once true, the course-detail screen collapses the
/// hero video + heading + "Continue" CTA so the user lands directly
/// on the lesson list.
final courseIntroWatchedProvider =
    FutureProvider.family<bool, String>((ref, courseId) async {
  final repo = ref.read(courseEnrollmentRepositoryProvider);
  return repo.isCourseIntroWatched(courseId);
});

/// Whether a specific lesson's video has been watched to the end at
/// least once. Backed by the same SharedPreferences flag the lesson
/// player flips inside `_markWatchedOnce()`. Drives the cascade-lock
/// gates on the lesson hub: until the module's main video is fully
/// watched, sub-lessons stay locked.
///
/// Invalidate this provider from anywhere that flips the underlying
/// preference (currently the player on video end) so consumers
/// rebuild without having to remount.
final videoFullyWatchedProvider =
    FutureProvider.family<bool, String>((ref, lessonId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('lesson_video_watched_$lessonId') ?? false;
});

/// Mark the course intro as watched and rebuild every consumer of
/// [courseIntroWatchedProvider] so the detail screen collapses.
Future<void> markCourseIntroWatched(WidgetRef ref, String courseId) async {
  final repo = ref.read(courseEnrollmentRepositoryProvider);
  await repo.setCourseIntroWatched(courseId, true);
  ref.invalidate(courseIntroWatchedProvider(courseId));
}

/// True when every lesson in [courseId] is marked completed.
/// Used to decide whether the user can move on to a new course
/// without paying.
final isCourseCompletedProvider =
    FutureProvider.family<bool, String>((ref, courseId) async {
  final completed = await ref.watch(courseProgressProvider(courseId).future);
  final course = await ref.watch(courseByIdProvider(courseId).future);
  if (course.totalLessons == 0) return false;
  return completed.length >= course.totalLessons;
});

/// Whether the user can start [targetCourseId] for free.
///
/// Rules:
///   - No active enrollment → free
///   - Active enrollment IS [targetCourseId] → free (just continue)
///   - Active enrollment was completed → free (unlocks any new course)
///   - Active enrollment is incomplete → blocked (must pay extra)
final canStartCourseProvider =
    FutureProvider.family<bool, String>((ref, targetCourseId) async {
  final activeId = await ref.watch(activeCourseIdProvider.future);
  if (activeId == null) return true;
  if (activeId == targetCourseId) return true;
  final activeDone = await ref.watch(
    isCourseCompletedProvider(activeId).future,
  );
  return activeDone;
});

/// Record that the user opened a lesson video in [courseId]. Returns
/// the new watched-set length so callers can decide whether to fire
/// the enrollment celebration popup (length crossing
/// [kFreePreviewVideos] is the trigger).
///
/// Idempotent — re-watching the same lesson does not bump the count.
Future<int> recordVideoWatched(
  WidgetRef ref,
  String courseId,
  String lessonId,
) async {
  final repo = ref.read(courseEnrollmentRepositoryProvider);
  final updated = await repo.markVideoWatched(courseId, lessonId);
  ref.invalidate(watchedVideosProvider(courseId));
  return updated.length;
}

/// Enroll the user in [courseId] and set it as the active course.
/// Called after the celebration popup is shown on the 4th video.
Future<void> enrollInCourse(WidgetRef ref, String courseId) async {
  final repo = ref.read(courseEnrollmentRepositoryProvider);
  await repo.setActiveCourseId(courseId);
  ref.invalidate(activeCourseIdProvider);
}

/// Clear the active enrollment. Currently only called for testing /
/// "reset" UX; production code lets the active course flip when the
/// next enrollment lands.
Future<void> clearActiveCourse(WidgetRef ref) async {
  final repo = ref.read(courseEnrollmentRepositoryProvider);
  await repo.setActiveCourseId(null);
  ref.invalidate(activeCourseIdProvider);
}

// ─────────────────────────── Module lock ───────────────────────────

/// True when every sub-lesson in [module] is completed. Used by the
/// cascade-lock logic on the course-detail page to decide whether the
/// next module should still be locked.
///
/// We deliberately don't require the `finalTest` to be marked
/// complete — the test card right now doesn't write a completion
/// record, and gating the next module on something that can't be
/// satisfied would strand users. Re-add the test gate once
/// `CourseTestPage` records `${module.id}_final_test` on a passing
/// run.
bool isModuleCompleted(CourseModule module, Set<String> completedIds) {
  if (module.lessons.isEmpty) return false;
  for (final l in module.lessons) {
    if (!completedIds.contains(l.id)) return false;
  }
  return true;
}

/// Indices of modules the user is allowed to open. The first module
/// is always open; every subsequent module is gated on the previous
/// one being [isModuleCompleted].
Set<int> unlockedModuleIndices(
  List<CourseModule> modules,
  Set<String> completedIds,
) {
  final out = <int>{};
  for (int i = 0; i < modules.length; i++) {
    if (i == 0) {
      out.add(i);
      continue;
    }
    if (isModuleCompleted(modules[i - 1], completedIds)) {
      out.add(i);
    } else {
      break;
    }
  }
  return out;
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
