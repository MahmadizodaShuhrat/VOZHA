import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_models.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_loader.dart';

/// Provider for the currently loaded course manifest
final currentCourseProvider = NotifierProvider<CurrentCourseNotifier, CourseManifest?>(CurrentCourseNotifier.new);
class CurrentCourseNotifier extends Notifier<CourseManifest?> {
  @override
  CourseManifest? build() => null;
  void set(CourseManifest? value) => state = value;
}

final currentLessonProvider = NotifierProvider<CurrentLessonNotifier, LessonInfo?>(CurrentLessonNotifier.new);
class CurrentLessonNotifier extends Notifier<LessonInfo?> {
  @override
  LessonInfo? build() => null;
  void set(LessonInfo? value) => state = value;
}

final currentWordsProvider = NotifierProvider<CurrentWordsNotifier, List<CourseWord>>(CurrentWordsNotifier.new);
class CurrentWordsNotifier extends Notifier<List<CourseWord>> {
  @override
  List<CourseWord> build() => [];
  void set(List<CourseWord> value) => state = value;
}

final currentCourseWordIndexProvider = NotifierProvider<CurrentCourseWordIndexNotifier, int>(CurrentCourseWordIndexNotifier.new);
class CurrentCourseWordIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}

/// Provider for loading course from ZIP
final courseLoaderProvider = Provider<CourseLoaderService>((ref) {
  return CourseLoaderService(ref);
});

class CourseLoaderService {
  final Ref ref;

  CourseLoaderService(this.ref);

  /// Load a course from ZIP file path
  Future<bool> loadCourse(String zipPath) async {
    final manifest = await CourseLoader.loadCourse(zipPath);
    if (manifest == null) return false;
    
    ref.read(currentCourseProvider.notifier).set(manifest);
    return true;
  }

  /// Load a specific lesson by index
  Future<bool> loadLesson(int index) async {
    final manifest = ref.read(currentCourseProvider);
    if (manifest == null || index >= manifest.lessons.length) return false;

    final lessonPath = manifest.lessons[index];
    final lesson = await CourseLoader.loadLesson(lessonPath);
    if (lesson == null) return false;

    ref.read(currentLessonProvider.notifier).set(lesson);

    // Load words if available
    if (lesson.learningWordsPath != null) {
      final lessonDir = lessonPath.replaceAll('lesson.json', '');
      final wordsData = await CourseLoader.loadLearningWords(
        lessonDir,
        lesson.learningWordsPath!,
      );
      if (wordsData != null) {
        ref.read(currentWordsProvider.notifier).set(wordsData.words);
      }
    }

    return true;
  }

  /// Get audio for current word
  Future<dynamic> getCurrentWordAudio() async {
    final lesson = ref.read(currentLessonProvider);
    final words = ref.read(currentWordsProvider);
    final index = ref.read(currentCourseWordIndexProvider);

    if (lesson == null || words.isEmpty || index >= words.length) return null;

    final word = words[index];
    if (word.audio.isEmpty) return null;

    final manifest = ref.read(currentCourseProvider);
    if (manifest == null) return null;

    // Find lesson directory
    final lessonPath = manifest.lessons.firstWhere(
      (l) => l.contains(lesson.name),
      orElse: () => '',
    );
    if (lessonPath.isEmpty) return null;

    final lessonDir = lessonPath.replaceAll('lesson.json', '');
    return CourseLoader.getWordAudio(lessonDir, word.audio);
  }

  /// Clear all course data
  void clear() {
    CourseLoader.clear();
    ref.read(currentCourseProvider.notifier).set(null);
    ref.read(currentLessonProvider.notifier).set(null);
    ref.read(currentWordsProvider.notifier).set([]);
    ref.read(currentCourseWordIndexProvider.notifier).set(0);
  }
}
