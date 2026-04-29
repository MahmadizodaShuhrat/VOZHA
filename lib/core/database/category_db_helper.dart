import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/core/utils/app_locale_utils.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/core/database/db_lang_column.dart';

/// Помощник для загрузки данных курса из JSON файлов (manifest → lessons → words).
/// Заменяет SQLite подход — теперь данные берутся из скачанного и извлечённого ZIP курса.
class CategoryDbHelper {
  /// Загрузить субкатегории (= lessons) из manifest.json курса.
  static Future<List<Subcategory>> getSubcategories(
    int categoryId, {
    String? langCode,
  }) async {
    debugPrint('📂 subcategoriesProvider: загрузка для категории $categoryId');

    final coursePath = await CategoryResourceService.getCoursePath(categoryId);
    if (coursePath == null) {
      debugPrint('! Курс для категории $categoryId не найден');
      return [];
    }

    try {
      // Читаем manifest.json
      final manifestFile = File(p.join(coursePath, 'manifest.json'));
      if (!manifestFile.existsSync()) {
        debugPrint('❌ manifest.json не найден в $coursePath');
        return [];
      }

      final manifestJson = jsonDecode(await manifestFile.readAsString());
      final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);

      debugPrint('📋 Найдено ${lessonPaths.length} уроков в manifest');

      // Read saved locale for subcategory title selection
      final prefs = await SharedPreferences.getInstance();
      final localeStr = prefs.getString('locale');
      final savedLocale = localeStr != null && localeStr.isNotEmpty
          ? localeStr.split('_').first
          : 'tg';
      // Map locale code → titles key in lesson.json
      final titlesKey = switch (savedLocale) {
        'tg' => 'Таджикский',
        'ru' => 'Русский',
        'en' => 'English',
        _ => 'Таджикский',
      };

      final effectiveTitlesKey = lessonTitlesKeyForLanguage(
        langCode ?? savedLocale,
      );

      final subcategories = <Subcategory>[];

      for (int i = 0; i < lessonPaths.length; i++) {
        final lessonFilePath = p.join(coursePath, lessonPaths[i]);
        final lessonFile = File(lessonFilePath);

        String lessonTitle = 'Дарс ${i + 1}';
        if (lessonFile.existsSync()) {
          try {
            final lessonJson = jsonDecode(await lessonFile.readAsString());
            // Try localized titles first
            if (lessonJson['titles'] is Map) {
              final titles = Map<String, dynamic>.from(lessonJson['titles']);
              lessonTitle =
                  (titles[effectiveTitlesKey] ??
                          titles.values.firstWhere(
                            (v) => v is String && v.toString().isNotEmpty,
                            orElse: () => lessonTitle,
                          ))
                      .toString();
            } else {
              lessonTitle =
                  lessonJson['title'] ?? lessonJson['name'] ?? lessonTitle;
            }
          } catch (e) {
            debugPrint('⚠️ Ошибка парсинга lesson.json: $e');
          }
        }

        subcategories.add(
          Subcategory(id: i + 1, name: lessonTitle, categoryId: categoryId),
        );
      }

      debugPrint('✅ Загружено ${subcategories.length} субкатегорий (уроков)');
      return subcategories;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки субкатегорий: $e');
      return [];
    }
  }

  /// Загрузить слова из learning_words.json для конкретного урока (subcategoryId = lessonIndex, 1-based).
  static Future<List<Word>> getWords(int? subcategoryId) async {
    if (subcategoryId == null) return [];

    // Ищем во всех категориях
    final catId = await _findCategoryIdForSubcategory(subcategoryId);
    final base = await CategoryResourceService.getCoursePath(catId);
    if (base == null) return [];

    return await _loadWordsForLesson(base, subcategoryId - 1, catId);
  }

  /// Загрузить слова для конкретной категории (все уроки).
  static Future<List<Word>> getWordsForCategory(int categoryId) async {
    final coursePath = await CategoryResourceService.getCoursePath(categoryId);
    if (coursePath == null) return [];

    try {
      final manifestFile = File(p.join(coursePath, 'manifest.json'));
      if (!manifestFile.existsSync()) return [];

      final manifestJson = jsonDecode(await manifestFile.readAsString());
      final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);

      final allWords = <Word>[];
      for (int i = 0; i < lessonPaths.length; i++) {
        final lessonWords = await _loadWordsForLesson(
          coursePath,
          i,
          categoryId,
        );
        allWords.addAll(lessonWords);
      }

      debugPrint('✅ Всего ${allWords.length} слов для категории $categoryId');
      return allWords;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки слов: $e');
      return [];
    }
  }

  /// Получить [count] случайных ID слов из категории.
  /// Как Unity: `WordsManager.GetRandomWordFromCategory(categoryId, countWord)`
  /// SQL: `SELECT Id FROM words ORDER BY RANDOM() LIMIT {count}`
  static Future<List<int>> getRandomWordIds(int categoryId, int count) async {
    final allWords = await getWordsForCategory(categoryId);
    if (allWords.isEmpty) return [];

    final shuffled = List<Word>.from(allWords)..shuffle();
    final selected = shuffled.take(count).map((w) => w.id).toList();
    debugPrint(
      '🎲 getRandomWordIds: category=$categoryId, '
      'count=$count, selected=$selected',
    );
    return selected;
  }

  /// Загрузить слова для конкретного урока по categoryId и lessonIndex (0-based).
  static Future<List<Word>> getWordsForLesson(
    int categoryId,
    int lessonIndex,
  ) async {
    final coursePath = await CategoryResourceService.getCoursePath(categoryId);
    if (coursePath == null) return [];
    return await _loadWordsForLesson(coursePath, lessonIndex, categoryId);
  }

  /// Внутренний метод: загрузить слова из learning_words.json для урока.
  static Future<List<Word>> _loadWordsForLesson(
    String coursePath,
    int lessonIndex,
    int categoryId,
  ) async {
    try {
      final manifestFile = File(p.join(coursePath, 'manifest.json'));
      if (!manifestFile.existsSync()) return [];

      final manifestJson = jsonDecode(await manifestFile.readAsString());
      final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);

      if (lessonIndex < 0 || lessonIndex >= lessonPaths.length) return [];

      // Читаем lesson.json
      final lessonFilePath = p.join(coursePath, lessonPaths[lessonIndex]);
      final lessonFile = File(lessonFilePath);
      if (!lessonFile.existsSync()) return [];

      final lessonJson = jsonDecode(await lessonFile.readAsString());
      final learningWordsPath = lessonJson['learning_words'] as String?;

      if (learningWordsPath == null || learningWordsPath.isEmpty) return [];

      // Путь к learning_words.json относительно папки урока
      final lessonDir = p.dirname(lessonFilePath);
      final wordsFilePath = p.join(lessonDir, learningWordsPath);
      final wordsFile = File(wordsFilePath);

      if (!wordsFile.existsSync()) {
        debugPrint('❌ learning_words.json не найден: $wordsFilePath');
        return [];
      }

      final wordsJson = jsonDecode(await wordsFile.readAsString());
      final wordsList = List<Map<String, dynamic>>.from(
        wordsJson['words'] ?? [],
      );

      // Базовый путь для sprites и audios
      final wordsDir = p.dirname(wordsFilePath);

      final words = <Word>[];

      // Determine locale-based translation column
      // EasyLocalization saves locale under key 'locale'
      final prefs = await SharedPreferences.getInstance();
      // Try reading EasyLocalization saved locale
      String savedLocale = 'tg'; // default
      final localeStr = prefs.getString('locale');
      if (localeStr != null && localeStr.isNotEmpty) {
        // EasyLocalization saves as language code e.g. 'tg', 'ru', 'en'
        savedLocale = localeStr.split('_').first; // handle 'tg_TJ' format
      }
      final langColumn = dbLangColumn(Locale(savedLocale));
      debugPrint('🌐 Translation column: $langColumn (locale: $savedLocale)');

      for (final w in wordsList) {
        // Select translation by current locale
        String translation = '';
        if (w['translations'] is Map) {
          final translations = Map<String, dynamic>.from(w['translations']);
          // Try locale-specific translation first, then fallback
          translation =
              (translations[langColumn] ??
                      translations.values.firstWhere(
                        (v) => v is String && v.isNotEmpty,
                        orElse: () => '',
                      ))
                  .toString();
        }
        if (translation.isEmpty) {
          translation = (w['translation'] ?? '').toString();
        }

        // Строим полные пути к ресурсам
        final photoRelative = w['photo'] as String? ?? '';
        final audioRelative = w['audio'] as String? ?? '';
        final photoPath = photoRelative.isNotEmpty
            ? p.join(wordsDir, photoRelative)
            : null;
        final audioPath = audioRelative.isNotEmpty
            ? p.join(wordsDir, audioRelative)
            : null;

        final wordId = w['id'] is int ? w['id'] : (words.length + 1);
        final wordLevel = w['level'] is int ? w['level'] as int : 0;
        final savedStatus = await DatabaseHelper.getWordStatus(wordId);

        words.add(
          Word(
            id: wordId,
            word: (w['word'] ?? '').toString().trim(),
            translation: translation.trim(),
            transcription: (w['transcription'] ?? '').toString().trim(),
            status: savedStatus,
            categoryId: categoryId,
            level: wordLevel,
            lessonIndex: lessonIndex,
            photoPath: photoPath,
            audioPath: audioPath,
          ),
        );
      }

      debugPrint('✅ Загружено ${words.length} слов из урока $lessonIndex');
      return words;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки слов из урока $lessonIndex: $e');
      return [];
    }
  }

  // Кэш: subcategoryId → categoryId (для обратного поиска)
  static final Map<int, int> _subToCatMap = {};

  /// Сохранить маппинг subcategoryId → categoryId.
  static void registerMapping(int categoryId, int subcategoryCount) {
    for (int i = 1; i <= subcategoryCount; i++) {
      _subToCatMap[i] = categoryId;
    }
  }

  /// Найти categoryId для subcategoryId.
  static Future<int> _findCategoryIdForSubcategory(int subcategoryId) async {
    return _subToCatMap[subcategoryId] ?? 1;
  }

  /// Закрыть / очистить кэш (для совместимости).
  static Future<void> closeAll() async {
    _subToCatMap.clear();
  }

  // ─────────────────────────────────────────────────
  //  Course Tests / Workbook loading
  // ─────────────────────────────────────────────────

  /// Load test data for a specific lesson (by categoryId and 0-based lessonIndex).
  /// Returns a list of [CourseTestData] parsed from the JSON files referenced in
  /// the lesson's `testing` field.
  static Future<List<CourseTestData>> getTestsForLesson(
    int categoryId,
    int lessonIndex,
  ) async {
    final lessonJson = await _readLessonJson(categoryId, lessonIndex);
    if (lessonJson == null) return [];

    final testingPaths = List<String>.from(lessonJson['testing'] ?? []);
    if (testingPaths.isEmpty) return [];

    final coursePath = await CategoryResourceService.getCoursePath(categoryId);
    if (coursePath == null) return [];

    final manifestJson = jsonDecode(
      await File(p.join(coursePath, 'manifest.json')).readAsString(),
    );
    final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);
    if (lessonIndex < 0 || lessonIndex >= lessonPaths.length) return [];

    final lessonDir = p.dirname(p.join(coursePath, lessonPaths[lessonIndex]));

    final results = <CourseTestData>[];
    for (final testPath in testingPaths) {
      final testFilePath = p.join(lessonDir, testPath);
      final testFile = File(testFilePath);
      if (!testFile.existsSync()) continue;
      try {
        final json = jsonDecode(await testFile.readAsString());
        final testDir = p.dirname(testFilePath);
        final testData = CourseTestData.fromJson(json as Map<String, dynamic>, testDir);
        results.add(testData);
      } catch (e) {
        debugPrint('⚠️ Failed to parse test file $testFilePath: $e');
      }
    }

    debugPrint(
      '✅ Loaded ${results.length} tests for category $categoryId, lesson $lessonIndex',
    );
    return results;
  }

  /// Load workbook data for a specific lesson.
  static Future<CourseTestData?> getWorkbookForLesson(
    int categoryId,
    int lessonIndex,
  ) async {
    final lessonJson = await _readLessonJson(categoryId, lessonIndex);
    if (lessonJson == null) return null;

    final workBookPath = lessonJson['work_book'] as String?;
    if (workBookPath == null || workBookPath.isEmpty) return null;

    final coursePath = await CategoryResourceService.getCoursePath(categoryId);
    if (coursePath == null) return null;

    final manifestJson = jsonDecode(
      await File(p.join(coursePath, 'manifest.json')).readAsString(),
    );
    final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);
    if (lessonIndex < 0 || lessonIndex >= lessonPaths.length) return null;

    final lessonDir = p.dirname(p.join(coursePath, lessonPaths[lessonIndex]));
    final wbFilePath = p.join(lessonDir, workBookPath);
    final wbFile = File(wbFilePath);
    if (!wbFile.existsSync()) return null;

    try {
      final json = jsonDecode(await wbFile.readAsString());
      final wbDir = p.dirname(wbFilePath);
      debugPrint(
        '✅ Loaded workbook for category $categoryId, lesson $lessonIndex',
      );
      return CourseTestData.fromJson(json as Map<String, dynamic>, wbDir);
    } catch (e) {
      debugPrint('⚠️ Failed to parse workbook $wbFilePath: $e');
      return null;
    }
  }

  /// Returns metadata about what a lesson has (learning words, tests, workbook).
  static Future<LessonMeta> getLessonMeta(
    int categoryId,
    int lessonIndex,
  ) async {
    final lessonJson = await _readLessonJson(categoryId, lessonIndex);
    if (lessonJson == null) {
      return LessonMeta(
        hasLearningWords: false,
        hasTests: false,
        hasWorkbook: false,
        testCount: 0,
      );
    }

    final learningWords = lessonJson['learning_words'] as String?;
    final testingPaths = List<String>.from(lessonJson['testing'] ?? []);
    final workBook = lessonJson['work_book'] as String?;

    return LessonMeta(
      hasLearningWords: learningWords != null && learningWords.isNotEmpty,
      hasTests: testingPaths.isNotEmpty,
      hasWorkbook: workBook != null && workBook.isNotEmpty,
      testCount: testingPaths.length,
    );
  }

  /// Internal: read and parse lesson.json for a specific lesson.
  static Future<Map<String, dynamic>?> _readLessonJson(
    int categoryId,
    int lessonIndex,
  ) async {
    final coursePath = await CategoryResourceService.getCoursePath(categoryId);
    debugPrint('🔍 [_readLessonJson] categoryId=$categoryId, lessonIndex=$lessonIndex, coursePath=$coursePath');
    if (coursePath == null) return null;

    try {
      final manifestFile = File(p.join(coursePath, 'manifest.json'));
      if (!manifestFile.existsSync()) {
        debugPrint('❌ [_readLessonJson] manifest.json not found at ${manifestFile.path}');
        return null;
      }

      final manifestJson = jsonDecode(await manifestFile.readAsString());
      final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);
      debugPrint('🔍 [_readLessonJson] ${lessonPaths.length} lessons in manifest');

      if (lessonIndex < 0 || lessonIndex >= lessonPaths.length) {
        debugPrint('❌ [_readLessonJson] lessonIndex $lessonIndex out of range');
        return null;
      }

      final lessonFilePath = p.join(coursePath, lessonPaths[lessonIndex]);
      final lessonFile = File(lessonFilePath);
      if (!lessonFile.existsSync()) {
        debugPrint('❌ [_readLessonJson] lesson file not found: $lessonFilePath');
        return null;
      }

      final json = jsonDecode(await lessonFile.readAsString())
          as Map<String, dynamic>;
      debugPrint('🔍 [_readLessonJson] lesson keys: ${json.keys.toList()}');
      debugPrint('🔍 [_readLessonJson] testing=${json['testing']}, work_book=${json['work_book']}, learning_words=${json['learning_words']}');
      return json;
    } catch (e) {
      debugPrint('⚠️ _readLessonJson error: $e');
      return null;
    }
  }

  /// Check if ANY lesson in a category has tests or workbook.
  /// Used to decide navigation: CourseLessonsPage vs ChoseLearnKnowPage.
  static Future<bool> categoryHasTestsOrWorkbook(int categoryId) async {
    final coursePath = await CategoryResourceService.getCoursePath(categoryId);
    if (coursePath == null) return false;

    try {
      final manifestFile = File(p.join(coursePath, 'manifest.json'));
      if (!manifestFile.existsSync()) return false;

      final manifestJson = jsonDecode(await manifestFile.readAsString());
      final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);

      for (int i = 0; i < lessonPaths.length; i++) {
        final lessonFilePath = p.join(coursePath, lessonPaths[i]);
        final lessonFile = File(lessonFilePath);
        if (!lessonFile.existsSync()) continue;

        try {
          final json = jsonDecode(await lessonFile.readAsString())
              as Map<String, dynamic>;
          final testingPaths = List<String>.from(json['testing'] ?? []);
          final workBook = json['work_book'] as String?;

          if (testingPaths.isNotEmpty ||
              (workBook != null && workBook.isNotEmpty)) {
            debugPrint(
              '✅ categoryHasTestsOrWorkbook($categoryId): found at lesson $i',
            );
            return true;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ categoryHasTestsOrWorkbook error: $e');
    }

    debugPrint('❌ categoryHasTestsOrWorkbook($categoryId): no tests/workbook');
    return false;
  }
}

/// Metadata about what a lesson contains.
class LessonMeta {
  final bool hasLearningWords;
  final bool hasTests;
  final bool hasWorkbook;
  final int testCount;

  LessonMeta({
    required this.hasLearningWords,
    required this.hasTests,
    required this.hasWorkbook,
    required this.testCount,
  });
}
