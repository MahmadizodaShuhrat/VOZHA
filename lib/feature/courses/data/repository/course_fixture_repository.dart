import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';

/// Reads course fixtures from the bundled JSON files under
/// `assets/courses/`. This stands in for a real HTTP backend until the
/// API is built — once the API is online, replace the `loadAll()` /
/// `loadById()` implementations with `Dio` calls and the rest of the
/// app keeps working.
class CourseFixtureRepository {
  CourseFixtureRepository();

  /// Read the index file and return one [CourseFixture] per id listed.
  Future<List<CourseFixture>> loadAll() async {
    final raw = await rootBundle.loadString('assets/courses/index.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final ids = (json['courses'] as List).cast<String>();
    final out = <CourseFixture>[];
    for (final id in ids) {
      out.add(await loadById(id));
    }
    return out;
  }

  /// Read a single course's `course.json`.
  Future<CourseFixture> loadById(String id) async {
    final raw =
        await rootBundle.loadString('assets/courses/$id/course.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CourseFixture.fromJson(json);
  }
}
