// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CourseManifest _$CourseManifestFromJson(Map<String, dynamic> json) =>
    _CourseManifest(
      id: json['id'] as String,
      title: json['title'] as String,
      language: json['language'] as String,
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      hash: json['hash'] as String? ?? '',
      exportDate: json['exportDate'] as String?,
      lessons:
          (json['lessons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$CourseManifestToJson(_CourseManifest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'language': instance.language,
      'description': instance.description,
      'version': instance.version,
      'hash': instance.hash,
      'exportDate': instance.exportDate,
      'lessons': instance.lessons,
    };

_LessonInfo _$LessonInfoFromJson(Map<String, dynamic> json) => _LessonInfo(
  id: json['id'] as String,
  name: json['name'] as String,
  title: json['title'] as String,
  description: json['description'] as String? ?? '',
  order: (json['order'] as num?)?.toInt() ?? 0,
  testing:
      (json['testing'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  learningWordsPath: json['learningWordsPath'] as String?,
);

Map<String, dynamic> _$LessonInfoToJson(_LessonInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'title': instance.title,
      'description': instance.description,
      'order': instance.order,
      'testing': instance.testing,
      'learningWordsPath': instance.learningWordsPath,
    };

_LearningWordsData _$LearningWordsDataFromJson(Map<String, dynamic> json) =>
    _LearningWordsData(
      title: json['title'] as String,
      learningLanguage: json['learningLanguage'] as String?,
      translationLanguage: json['translationLanguage'] as String?,
      translationLanguages:
          (json['translationLanguages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      words:
          (json['words'] as List<dynamic>?)
              ?.map((e) => CourseWord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LearningWordsDataToJson(_LearningWordsData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'learningLanguage': instance.learningLanguage,
      'translationLanguage': instance.translationLanguage,
      'translationLanguages': instance.translationLanguages,
      'words': instance.words,
    };

_CourseWord _$CourseWordFromJson(Map<String, dynamic> json) => _CourseWord(
  id: (json['id'] as num).toInt(),
  word: json['word'] as String,
  translation: json['translation'] as String,
  translations:
      (json['translations'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  transcription: json['transcription'] as String? ?? '',
  description: json['description'] as String? ?? '',
  photo: json['photo'] as String? ?? '',
  audio: json['audio'] as String? ?? '',
);

Map<String, dynamic> _$CourseWordToJson(_CourseWord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'word': instance.word,
      'translation': instance.translation,
      'translations': instance.translations,
      'transcription': instance.transcription,
      'description': instance.description,
      'photo': instance.photo,
      'audio': instance.audio,
    };
