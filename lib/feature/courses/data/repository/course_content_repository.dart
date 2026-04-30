import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';

/// Abstract source of course content. Implementations decide where
/// the data physically lives — bundled assets, an HTTP API, a local
/// SQLite cache, etc.
///
/// The rest of the courses feature talks ONLY to this interface, so
/// the day the real backend ships we just register a different
/// implementation in `course_fixture_provider.dart` and nothing else
/// has to change.
abstract class CourseContentRepository {
  /// All courses available to the user.
  Future<List<CourseFixture>> loadAll();

  /// Fetch one course by id. Should throw if the id is unknown so
  /// the UI's error branch fires instead of silently rendering
  /// half-empty state.
  Future<CourseFixture> loadById(String id);
}

/// Provisional implementation that reads from the JSON files bundled
/// under `assets/courses/`. Used while the real API is in
/// development. Swap with [ApiCourseContentRepository] (TBD) once
/// the backend is online.
class AssetCourseContentRepository implements CourseContentRepository {
  AssetCourseContentRepository();

  static const _indexPath = 'assets/courses/index.json';
  String _coursePath(String id) => 'assets/courses/$id/course.json';

  @override
  Future<List<CourseFixture>> loadAll() async {
    final raw = await rootBundle.loadString(_indexPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final ids = (json['courses'] as List).cast<String>();
    return [for (final id in ids) await loadById(id)];
  }

  @override
  Future<CourseFixture> loadById(String id) async {
    final raw = await rootBundle.loadString(_coursePath(id));
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CourseFixture.fromJson(json);
  }
}
