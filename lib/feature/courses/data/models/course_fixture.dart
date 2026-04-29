import 'package:vozhaomuz/core/database/data_base_helper.dart' show Word;
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';

/// Plain Dart models for the provisional asset-backed "backend" used
/// while the real one is being built. They mirror the shape of
/// `assets/courses/english_a1/course.json` and are intentionally not
/// freezed-codegened so we can iterate on the schema quickly.
///
/// Once the real backend ships, swap the loader behind
/// `courseFixtureProvider` and the rest of the UI keeps working.

class CourseFixture {
  final String id;
  final String title;
  final String subtitle;
  final String level;
  final double rating;
  final int students;
  final int totalMinutes;
  final String description;
  final CourseInstructor instructor;
  final String? coverUrl;
  final String? previewUrl;
  final String publishedAt;
  final List<CourseModule> modules;

  const CourseFixture({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.rating,
    required this.students,
    required this.totalMinutes,
    required this.description,
    required this.instructor,
    required this.coverUrl,
    required this.previewUrl,
    required this.publishedAt,
    required this.modules,
  });

  factory CourseFixture.fromJson(Map<String, dynamic> j) {
    return CourseFixture(
      id: j['id'] as String,
      title: j['title'] as String,
      subtitle: (j['subtitle'] ?? '') as String,
      level: (j['level'] ?? '') as String,
      rating: ((j['rating'] ?? 0) as num).toDouble(),
      students: (j['students'] ?? 0) as int,
      totalMinutes: (j['totalMinutes'] ?? 0) as int,
      description: (j['description'] ?? '') as String,
      instructor: CourseInstructor.fromJson(
          (j['instructor'] ?? const {}) as Map<String, dynamic>),
      coverUrl: j['coverUrl'] as String?,
      previewUrl: j['previewUrl'] as String?,
      publishedAt: (j['publishedAt'] ?? '') as String,
      modules: ((j['modules'] ?? const []) as List)
          .cast<Map<String, dynamic>>()
          .map(CourseModule.fromJson)
          .toList(),
    );
  }

  /// Total number of lessons across all modules — handy for progress bars.
  int get totalLessons =>
      modules.fold(0, (sum, m) => sum + m.lessons.length);

  /// Lessons whose `status == "completed"` — also progress-bar input.
  int get completedLessons => modules
      .expand((m) => m.lessons)
      .where((l) => l.status == LessonStatus.completed)
      .length;
}

class CourseInstructor {
  final String name;
  final String role;
  final String? avatarUrl;

  const CourseInstructor({
    required this.name,
    required this.role,
    required this.avatarUrl,
  });

  factory CourseInstructor.fromJson(Map<String, dynamic> j) => CourseInstructor(
        name: (j['name'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

class CourseModule {
  final String id;
  final String title;
  final List<CourseLesson> lessons;

  /// Big intro video shown at the top of the lesson-hub page. The
  /// user has to watch it (initially) before the sub-lessons unlock.
  /// Optional — modules without their own intro video just show the
  /// sub-lesson list directly.
  final LessonVideo? mainVideo;

  /// "Пройти тест" — final test that ties together every sub-lesson
  /// in this module. Locked until all sub-lessons are completed.
  final CourseTestData? finalTest;

  /// Optional human-friendly subtitle for the hub page header
  /// (e.g. "Новичок — Урок 1").
  final String? subtitle;

  const CourseModule({
    required this.id,
    required this.title,
    required this.lessons,
    required this.mainVideo,
    required this.finalTest,
    required this.subtitle,
  });

  factory CourseModule.fromJson(Map<String, dynamic> j) => CourseModule(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        mainVideo: j['mainVideo'] == null
            ? null
            : LessonVideo.fromJson(j['mainVideo'] as Map<String, dynamic>),
        finalTest: j['finalTest'] == null
            ? null
            : CourseTestData.fromJson(
                j['finalTest'] as Map<String, dynamic>,
                '',
              ),
        lessons: ((j['lessons'] ?? const []) as List)
            .cast<Map<String, dynamic>>()
            .map(CourseLesson.fromJson)
            .toList(),
      );

  /// Total words across every sub-lesson (used for the
  /// "Изучать слова X/Y" progress bar on the hub page).
  int get totalWords =>
      lessons.fold(0, (sum, l) => sum + l.words.length);
}

enum LessonType { video, videoWithWords, pronunciation, quiz, words }
enum LessonStatus { completed, current, locked }

class CourseLesson {
  final String id;
  final LessonType type;
  final String title;
  final String durationLabel;
  final int durationSeconds;
  final LessonStatus status;
  final LessonVideo? video;
  final List<CourseFixtureWord> words;
  final List<String> games;
  final List<QuizQuestion> questions;

  /// Optional structured test for the lesson — when present, the
  /// lesson player hands this off to [CourseTestPage], which already
  /// knows how to render every game type listed in
  /// `lib/feature/courses/presentation/widgets/games/`.
  final CourseTestData? test;

  const CourseLesson({
    required this.id,
    required this.type,
    required this.title,
    required this.durationLabel,
    required this.durationSeconds,
    required this.status,
    required this.video,
    required this.words,
    required this.games,
    required this.questions,
    required this.test,
  });

  factory CourseLesson.fromJson(Map<String, dynamic> j) => CourseLesson(
        id: j['id'] as String,
        type: _parseType((j['type'] ?? 'video') as String),
        title: j['title'] as String,
        durationLabel: (j['durationLabel'] ?? '') as String,
        durationSeconds: (j['durationSeconds'] ?? 0) as int,
        status: _parseStatus((j['status'] ?? 'locked') as String),
        video: j['video'] == null
            ? null
            : LessonVideo.fromJson(j['video'] as Map<String, dynamic>),
        words: ((j['words'] ?? const []) as List)
            .cast<Map<String, dynamic>>()
            .map(CourseFixtureWord.fromJson)
            .toList(),
        games: ((j['games'] ?? const []) as List).cast<String>(),
        questions: ((j['questions'] ?? const []) as List)
            .cast<Map<String, dynamic>>()
            .map(QuizQuestion.fromJson)
            .toList(),
        test: j['test'] == null
            ? null
            : CourseTestData.fromJson(
                j['test'] as Map<String, dynamic>,
                // No on-disk basePath for asset-bundled fixtures; the
                // games that need one (image/audio loaders) treat an
                // empty string as "no media".
                '',
              ),
      );
}

LessonType _parseType(String s) {
  switch (s) {
    case 'video_with_words':
      return LessonType.videoWithWords;
    case 'pronunciation':
      return LessonType.pronunciation;
    case 'quiz':
      return LessonType.quiz;
    case 'words':
      return LessonType.words;
    case 'video':
    default:
      return LessonType.video;
  }
}

LessonStatus _parseStatus(String s) {
  switch (s) {
    case 'completed':
      return LessonStatus.completed;
    case 'current':
      return LessonStatus.current;
    case 'locked':
    default:
      return LessonStatus.locked;
  }
}

class LessonVideo {
  final String? url;
  final String? assetPath;
  final String? thumbnail;

  const LessonVideo({this.url, this.assetPath, this.thumbnail});

  factory LessonVideo.fromJson(Map<String, dynamic> j) {
    final raw = (j['url'] ?? '') as String;
    if (raw.startsWith('asset:')) {
      return LessonVideo(
        assetPath: raw.replaceFirst('asset:', ''),
        thumbnail: j['thumbnail'] as String?,
      );
    }
    return LessonVideo(
      url: raw.isEmpty ? null : raw,
      thumbnail: j['thumbnail'] as String?,
    );
  }
}

/// Word in a lesson's vocabulary set. Exposes a `toGameWord()` helper
/// that converts to the `Word` type that the existing 4000-essential
/// games (flashcard, match, speech, keyboard, ...) consume via
/// `learningWordsProvider`.
class CourseFixtureWord {
  final int id;
  final String word;
  final String translation;
  final String transcription;

  /// Example sentence in the target language showing the word in
  /// context. Empty string when the fixture omits it.
  final String example;

  /// Translation of [example] in the user's UI language.
  final String exampleTranslation;

  const CourseFixtureWord({
    required this.id,
    required this.word,
    required this.translation,
    required this.transcription,
    required this.example,
    required this.exampleTranslation,
  });

  factory CourseFixtureWord.fromJson(Map<String, dynamic> j) =>
      CourseFixtureWord(
        id: j['id'] as int,
        word: j['word'] as String,
        translation: j['translation'] as String,
        transcription: (j['transcription'] ?? '') as String,
        example: (j['example'] ?? '') as String,
        exampleTranslation: (j['exampleTranslation'] ?? '') as String,
      );

  /// Conversion into the in-app `Word` model so the existing game pages
  /// can iterate over a course lesson's words without any branching.
  Word toGameWord({int categoryId = -1, int lessonIndex = 0}) => Word(
        id: id,
        word: word,
        translation: translation,
        transcription: transcription,
        status: '',
        categoryId: categoryId,
        level: 1,
        lessonIndex: lessonIndex,
      );
}

class QuizQuestion {
  final String id;
  final String kind;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'multi_choice') as String,
        prompt: j['prompt'] as String,
        options: ((j['options'] ?? const []) as List).cast<String>(),
        correctIndex: (j['correctIndex'] ?? 0) as int,
      );
}
