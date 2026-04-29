// lib/models/user_words_with_upload.dart
import 'package:json_annotation/json_annotation.dart';

/// Модель слова для отправки на сервер (как в Unity)
class UserWordsWithUpload {
  @JsonKey(name: 'category_id')
  final int categoryId;

  @JsonKey(name: 'word_id')
  final int wordId;

  @JsonKey(name: 'current_learning_state')
  final int currentLearningState;

  @JsonKey(name: 'is_first_submit_is_learning')
  final bool isFirstSubmitIsLearning;

  @JsonKey(name: 'learning_language')
  final String learningLanguage;

  @JsonKey(name: 'timeout')
  final String timeout;

  @JsonKey(name: 'error_in_games')
  final List<String> errorInGames;

  @JsonKey(name: 'write_time')
  final String writeTime;

  @JsonKey(name: 'word_original')
  final String wordOriginal;

  @JsonKey(name: 'word_translate')
  final String wordTranslate;

  UserWordsWithUpload({
    required this.categoryId,
    required this.wordId,
    required this.currentLearningState,
    required this.isFirstSubmitIsLearning,
    required this.learningLanguage,
    required this.timeout,
    required this.errorInGames,
    required this.writeTime,
    this.wordOriginal = '',
    this.wordTranslate = '',
  });

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'word_id': wordId,
    'current_learning_state': currentLearningState,
    'is_first_submit_is_learning': isFirstSubmitIsLearning,
    'learning_language': learningLanguage,
    'timeout': timeout,
    'error_in_games': errorInGames,
    'write_time': writeTime,
    if (wordOriginal.isNotEmpty) 'word_original': wordOriginal,
    if (wordTranslate.isNotEmpty) 'word_translate': wordTranslate,
  };

  factory UserWordsWithUpload.fromJson(Map<String, dynamic> json) {
    return UserWordsWithUpload(
      categoryId: json['category_id'] as int,
      wordId: json['word_id'] as int,
      currentLearningState: json['current_learning_state'] as int? ?? 1,
      isFirstSubmitIsLearning: json['is_first_submit_is_learning'] as bool? ?? true,
      learningLanguage: json['learning_language'] as String? ?? 'EnToRu',
      timeout: json['timeout'] as String? ?? '',
      errorInGames: (json['error_in_games'] as List<dynamic>?)?.cast<String>() ?? [],
      writeTime: json['write_time'] as String? ?? '',
      wordOriginal: json['word_original'] as String? ?? '',
      wordTranslate: json['word_translate'] as String? ?? '',
    );
  }

  /// Создать для нового выученного слова
  /// isFirstSubmitIsLearning = false means user chose LEARN (not KNOW/skip)
  factory UserWordsWithUpload.forNewWord({
    required int categoryId,
    required int wordId,
    String learningLanguage = 'EnToRu',
  }) {
    final now = DateTime.now();
    return UserWordsWithUpload(
      categoryId: categoryId,
      wordId: wordId,
      currentLearningState: 1,
      isFirstSubmitIsLearning: false,  // User chose LEARN, not KNOW
      learningLanguage: learningLanguage,
      timeout: now.toIso8601String(),
      errorInGames: [],
      writeTime: now.toIso8601String(),
    );
  }

  /// Создать для слова с ошибкой (state = -1)
  factory UserWordsWithUpload.forWrongWord({
    required int categoryId,
    required int wordId,
    String learningLanguage = 'EnToRu',
  }) {
    final now = DateTime.now();
    return UserWordsWithUpload(
      categoryId: categoryId,
      wordId: wordId,
      currentLearningState: -1,  // Wrong answer
      isFirstSubmitIsLearning: false,
      learningLanguage: learningLanguage,
      timeout: now.toIso8601String(),
      errorInGames: [],
      writeTime: now.toIso8601String(),
    );
  }
}
