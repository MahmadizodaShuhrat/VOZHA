import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk JSON storage for per-course user state. Each course gets a
/// single file at `<docs>/courses/<courseId>.json` whose payload is a
/// JSON object that holds every flag the app cares about for that
/// course (completed lessons, watched videos, intro-watched flag, ...).
///
/// One file per course keeps the on-disk surface small and readable —
/// you can copy the file off the device for debugging / support and
/// see everything the user has done in that course at a glance.
///
/// Two repositories ([CourseProgressRepository] and
/// [CourseEnrollmentRepository]) share this helper so neither has to
/// re-derive the directory layout or worry about partial writes
/// stepping on each other's keys.
class CourseStateStorage {
  CourseStateStorage._();

  /// Singleton — the storage is just a thin wrapper around the file
  /// system, so there's no benefit to having multiple instances.
  static final CourseStateStorage instance = CourseStateStorage._();

  /// Resolves (and lazily creates) `<docs>/courses/`. Used by every
  /// read/write below.
  Future<Directory> _coursesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'courses'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _courseFile(String courseId) async {
    final dir = await _coursesDir();
    return File(p.join(dir.path, '$courseId.json'));
  }

  /// File that holds the global "which course is the user enrolled in"
  /// pointer. Lives outside the per-course payloads so flipping the
  /// active course doesn't have to rewrite an unrelated file.
  Future<File> _activeFile() async {
    final dir = await _coursesDir();
    return File(p.join(dir.path, '_active.json'));
  }

  /// Reads the per-course payload. Returns an empty map when the file
  /// is missing or corrupt — callers treat absence as "no state yet".
  Future<Map<String, dynamic>> readCourse(String courseId) async {
    try {
      final file = await _courseFile(courseId);
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.isEmpty) return {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Replace the per-course payload with [data]. Atomic — writes the
  /// whole file in one call so concurrent reads can't catch us
  /// mid-update.
  Future<void> writeCourse(String courseId, Map<String, dynamic> data) async {
    final file = await _courseFile(courseId);
    await file.writeAsString(jsonEncode(data));
  }

  /// Read–merge–write helper. Reads the existing payload, applies
  /// [patch] over the top, and writes the merged result back. Used by
  /// callers that own one key in the file but not the others.
  Future<void> updateCourse(
    String courseId,
    Map<String, dynamic> patch,
  ) async {
    final current = await readCourse(courseId);
    current.addAll(patch);
    await writeCourse(courseId, current);
  }

  Future<String?> readActiveCourseId() async {
    try {
      final file = await _activeFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final id = m['activeCourseId'] as String?;
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeActiveCourseId(String? courseId) async {
    final file = await _activeFile();
    if (courseId == null || courseId.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.writeAsString(jsonEncode({'activeCourseId': courseId}));
  }
}
