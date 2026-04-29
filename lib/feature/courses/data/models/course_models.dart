/// Course data models for parsing ZIP structure
import 'package:freezed_annotation/freezed_annotation.dart';

part 'course_models.freezed.dart';
part 'course_models.g.dart';

@freezed
abstract class CourseManifest with _$CourseManifest {
  const factory CourseManifest({
    required String id,
    required String title,
    required String language,
    @Default('') String description,
    @Default('1.0') String version,
    @Default('') String hash,
    String? exportDate,
    @Default([]) List<String> lessons,
  }) = _CourseManifest;

  factory CourseManifest.fromJson(Map<String, dynamic> json) =>
      _$CourseManifestFromJson(json);
}

@freezed
abstract class LessonInfo with _$LessonInfo {
  const factory LessonInfo({
    required String id,
    required String name,
    required String title,
    @Default('') String description,
    @Default(0) int order,
    @Default([]) List<String> testing,
    String? learningWordsPath,
  }) = _LessonInfo;

  factory LessonInfo.fromJson(Map<String, dynamic> json) =>
      _$LessonInfoFromJson(_normalizeKeys(json));
}

/// Pre-process JSON keys for LessonInfo (snake_case → camelCase)
Map<String, dynamic> _normalizeKeys(Map<String, dynamic> json) {
  final m = Map<String, dynamic>.from(json);
  if (m.containsKey('learning_words')) {
    m['learningWordsPath'] = m.remove('learning_words');
  }
  return m;
}

@freezed
abstract class LearningWordsData with _$LearningWordsData {
  const factory LearningWordsData({
    required String title,
    String? learningLanguage,
    String? translationLanguage,
    @Default([]) List<String> translationLanguages,
    @Default([]) List<CourseWord> words,
  }) = _LearningWordsData;

  factory LearningWordsData.fromJson(Map<String, dynamic> json) =>
      _$LearningWordsDataFromJson(json);
}

@freezed
abstract class CourseWord with _$CourseWord {
  const factory CourseWord({
    required int id,
    required String word,
    required String translation,
    @Default({}) Map<String, String> translations,
    @Default('') String transcription,
    @Default('') String description,
    @Default('') String photo,
    @Default('') String audio,
  }) = _CourseWord;

  factory CourseWord.fromJson(Map<String, dynamic> json) =>
      _$CourseWordFromJson(json);
}
