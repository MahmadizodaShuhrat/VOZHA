import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_content_repository.dart';

/// Source of course content. Currently bundled assets — replace this
/// override with an `ApiCourseContentRepository` (Dio-backed) once
/// the real backend ships, and every UI consumer keeps working
/// because they only depend on the [CourseContentRepository]
/// interface.
final courseContentRepositoryProvider = Provider<CourseContentRepository>(
  (_) => AssetCourseContentRepository(),
);

/// Backwards-compat alias so older imports
/// (`courseFixtureRepositoryProvider`) keep working while we migrate.
final courseFixtureRepositoryProvider = courseContentRepositoryProvider;

/// All courses listed in `assets/courses/index.json`. Used by the
/// Courses tab on the bottom nav.
final allCoursesProvider = FutureProvider<List<CourseFixture>>((ref) {
  return ref.read(courseContentRepositoryProvider).loadAll();
});

/// One course by id. Used by the course-detail page.
final courseByIdProvider =
    FutureProvider.family<CourseFixture, String>((ref, id) {
  return ref.read(courseContentRepositoryProvider).loadById(id);
});
