import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_fixture_repository.dart';

/// Single repository instance. Replace the body with a `Dio`-backed
/// implementation once the real backend is online — no consumers need
/// to change.
final courseFixtureRepositoryProvider = Provider<CourseFixtureRepository>((_) {
  return CourseFixtureRepository();
});

/// All courses listed in `assets/courses/index.json`. Used by the
/// Courses tab on the bottom nav.
final allCoursesProvider = FutureProvider<List<CourseFixture>>((ref) {
  return ref.read(courseFixtureRepositoryProvider).loadAll();
});

/// One course by id. Used by the course-detail page (which currently
/// hard-codes "english_a1" — switch this to a route argument once we
/// list more than one course).
final courseByIdProvider =
    FutureProvider.family<CourseFixture, String>((ref, id) {
  return ref.read(courseFixtureRepositoryProvider).loadById(id);
});
