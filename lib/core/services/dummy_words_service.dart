import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';

/// Сервис подбора слов-пустышек (дамми/distractor) для тренажёров.
///
/// Стратегия подбора (каскадный fallback):
/// 1. Слова из той же подкатегории (урока)
/// 2. Слова из соседних подкатегорий (±1, ±2, ...)
/// 3. Слова из всей категории
///
/// Гарантии:
/// - targetWord никогда не попадёт в результат
/// - Нет дублей по translation (чтобы два варианта не были «одинаковыми»)
/// - Результат перемешан случайным образом
class DummyWordsService {
  static final _random = Random();

  /// Подобрать [count] слов-пустышек для [targetWord].
  ///
  /// [categoryId] — ID категории (курса).
  /// [lessonIndex] — 0-based индекс урока (подкатегории).
  /// [count] — сколько дамми-слов нужно.
  /// [excludeWords] — дополнительные слова для исключения
  ///   (например, другие обучаемые слова из текущего батча).
  static Future<List<Word>> getDummyWords({
    required Word targetWord,
    required int categoryId,
    required int lessonIndex,
    required int count,
    List<Word> excludeWords = const [],
  }) async {
    if (count <= 0) return [];

    // Собираем множество ID, слов и переводов для исключения
    final excludeIds = <int>{targetWord.id, ...excludeWords.map((w) => w.id)};
    final excludeTranslations = <String>{
      targetWord.translation.toLowerCase().trim(),
      ...excludeWords.map((w) => w.translation.toLowerCase().trim()),
    };
    final excludeWordsText = <String>{
      targetWord.word.toLowerCase().trim(),
      ...excludeWords.map((w) => w.word.toLowerCase().trim()),
    };

    final candidates = <Word>[];

    // ─── Шаг 1: Слова из той же подкатегории ───
    try {
      final sameLesson = await CategoryDbHelper.getWordsForLesson(
        categoryId,
        lessonIndex,
      );
      _addUniqueCandidates(
        candidates,
        sameLesson,
        excludeIds,
        excludeTranslations,
        excludeWordsText,
      );
      debugPrint(
        '🎯 DummyWords: ${candidates.length} кандидатов из урока $lessonIndex',
      );
    } catch (e) {
      debugPrint('⚠️ DummyWords: ошибка загрузки урока $lessonIndex: $e');
    }

    // ─── Шаг 2: Соседние подкатегории (если не хватает) ───
    if (candidates.length < count) {
      try {
        final subcategories = await CategoryDbHelper.getSubcategories(
          categoryId,
        );
        final totalLessons = subcategories.length;

        // Расширяем радиус: ±1, ±2, ... пока не наберём достаточно
        for (
          int delta = 1;
          delta < totalLessons && candidates.length < count;
          delta++
        ) {
          for (final neighborIndex in [
            lessonIndex - delta,
            lessonIndex + delta,
          ]) {
            if (neighborIndex < 0 || neighborIndex >= totalLessons) continue;
            if (neighborIndex == lessonIndex) continue; // уже загружено

            try {
              final neighborWords = await CategoryDbHelper.getWordsForLesson(
                categoryId,
                neighborIndex,
              );
              _addUniqueCandidates(
                candidates,
                neighborWords,
                excludeIds,
                excludeTranslations,
                excludeWordsText,
              );
              debugPrint(
                '🔄 DummyWords: +${neighborWords.length} из урока $neighborIndex '
                '(итого ${candidates.length})',
              );
            } catch (e) {
              debugPrint(
                '⚠️ DummyWords: ошибка загрузки соседнего урока $neighborIndex: $e',
              );
            }

            if (candidates.length >= count) break;
          }
        }
      } catch (e) {
        debugPrint('⚠️ DummyWords: ошибка загрузки субкатегорий: $e');
      }
    }

    // ─── Шаг 3: Вся категория (последний fallback) ───
    if (candidates.length < count) {
      try {
        final allCategoryWords = await CategoryDbHelper.getWordsForCategory(
          categoryId,
        );
        _addUniqueCandidates(
          candidates,
          allCategoryWords,
          excludeIds,
          excludeTranslations,
          excludeWordsText,
        );
        debugPrint(
          '📦 DummyWords: fallback на всю категорию, итого ${candidates.length}',
        );
      } catch (e) {
        debugPrint('⚠️ DummyWords: ошибка загрузки категории: $e');
      }
    }

    // ─── Результат ───
    if (candidates.isEmpty) {
      debugPrint('⚠️ DummyWords: пул пуст, возвращаем пустой список');
      return [];
    }

    candidates.shuffle(_random);

    final result = candidates.take(count).toList();
    debugPrint(
      '✅ DummyWords: вернули ${result.length} из ${candidates.length} '
      'кандидатов для "${targetWord.word}"',
    );
    return result;
  }

  /// Маппинг wordId → lessonIndex (для отладки: откуда пришёл дамми)
  static final Map<int, int> _wordLessonMap = {};

  /// Получить номер урока из которого пришёл дамми-спрос (для логов)
  static int? getLessonForWord(int wordId) => _wordLessonMap[wordId];

  /// Загрузить полный пул дамми-слов для категории/урока.
  ///
  /// Используется для кэширования — один раз загрузить пул и потом
  /// выбирать из него для каждого слова.
  static Future<List<Word>> loadDummyPool({
    required int categoryId,
    required int lessonIndex,
    List<Word> excludeWords = const [],
  }) async {
    final excludeIds = excludeWords.map((w) => w.id).toSet();
    final excludeTranslations = excludeWords
        .map((w) => w.translation.toLowerCase().trim())
        .toSet();
    final excludeWordsText = excludeWords
        .map((w) => w.word.toLowerCase().trim())
        .toSet();

    _wordLessonMap.clear();
    final pool = <Word>[];

    // ─── Загружаем КАЖДЫЙ урок отдельно (чтобы знать источник) ───
    try {
      final subcategories = await CategoryDbHelper.getSubcategories(categoryId);
      final totalLessons = subcategories.length;
      debugPrint(
        '📂 DummyPool: категория $categoryId, $totalLessons уроков, текущий урок: $lessonIndex',
      );

      // Сначала текущий урок
      try {
        final currentLessonWords = await CategoryDbHelper.getWordsForLesson(
          categoryId,
          lessonIndex,
        );
        // Маппим ВСЕ слова этого урока (включая excludeWords) чтобы знать их реальный урок
        for (final w in currentLessonWords) {
          _wordLessonMap[w.id] = lessonIndex;
        }
        final poolSizeBefore = pool.length;
        _addUniqueCandidates(
          pool,
          currentLessonWords,
          excludeIds,
          excludeTranslations,
          excludeWordsText,
        );
        debugPrint(
          '  📗 Урок $lessonIndex (текущий): '
          '${currentLessonWords.length} слов в уроке, '
          '${pool.length - poolSizeBefore} добавлено в пул',
        );
      } catch (e) {
        debugPrint('  ⚠️ Ошибка загрузки урока $lessonIndex: $e');
      }

      // Затем остальные уроки
      for (int i = 0; i < totalLessons; i++) {
        if (i == lessonIndex) continue;
        try {
          final lessonWords = await CategoryDbHelper.getWordsForLesson(
            categoryId,
            i,
          );
          // Маппим ВСЕ слова этого урока (включая excludeWords)
          for (final w in lessonWords) {
            // Не перетираем если уже замаплено (приоритет текущего урока)
            _wordLessonMap.putIfAbsent(w.id, () => i);
          }
          final poolSizeBefore = pool.length;
          _addUniqueCandidates(
            pool,
            lessonWords,
            excludeIds,
            excludeTranslations,
            excludeWordsText,
          );
          if (pool.length > poolSizeBefore) {
            debugPrint(
              '  📘 Урок $i: '
              '${lessonWords.length} слов в уроке, '
              '${pool.length - poolSizeBefore} добавлено в пул',
            );
          }
        } catch (_) {}
      }

      // Логируем реальный урок каждого excludeWord
      for (final w in excludeWords) {
        final realLesson = _wordLessonMap[w.id];
        debugPrint(
          '  🏷️ Правильное слово "${w.word}" (id=${w.id}) → реальный урок: ${realLesson ?? "??"}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ DummyPool: ошибка при загрузке уроков: $e');
      // Fallback: загрузить всю категорию
      try {
        final allWords = await CategoryDbHelper.getWordsForCategory(categoryId);
        _addUniqueCandidates(
          pool,
          allWords,
          excludeIds,
          excludeTranslations,
          excludeWordsText,
        );
      } catch (_) {}
    }

    pool.shuffle(_random);
    debugPrint(
      '📦 DummyWords pool ИТОГО: ${pool.length} слов для категории $categoryId',
    );
    return pool;
  }

  /// Выбрать [count] случайных дамми из предзагруженного [pool],
  /// исключая [targetWord].
  static List<Word> pickFromPool({
    required List<Word> pool,
    required Word targetWord,
    required int count,
  }) {
    final targetTranslation = targetWord.translation.toLowerCase().trim();
    final targetWordText = targetWord.word.toLowerCase().trim();
    final filtered = pool
        .where(
          (w) =>
              w.id != targetWord.id &&
              w.translation.toLowerCase().trim() != targetTranslation &&
              w.word.toLowerCase().trim() != targetWordText,
        )
        .toList();

    if (filtered.isEmpty) return [];

    filtered.shuffle(_random);
    return filtered.take(count).toList();
  }

  /// Подобрать УНИКАЛЬНЫЕ дамми для каждого слова в батче.
  ///
  /// Для батча из [correctWords] (напр. 4 обучаемых слова) назначает
  /// каждому слову [countPerWord] дамми так, что:
  /// - **Приоритет**: слова из того же урока что и конкретное правильное слово
  /// - Никакой дамми не повторяется между словами (если пул позволяет)
  /// - Пользователь не может угадать правильный ответ методом исключения
  ///
  /// [currentLessonIndex] — fallback если урок слова неизвестен.
  ///
  /// Возвращает Map: correctWord.id → List<Word> (дамми для этого слова)
  static Map<int, List<Word>> pickUniqueForBatch({
    required List<Word> pool,
    required List<Word> correctWords,
    int countPerWord = 3,
    int? currentLessonIndex,
  }) {
    final result = <int, List<Word>>{};
    if (pool.isEmpty || correctWords.isEmpty) {
      for (final w in correctWords) {
        result[w.id] = [];
      }
      return result;
    }

    // Исключаем все правильные слова из пула по ID и переводу
    final correctIds = correctWords.map((w) => w.id).toSet();
    final correctTranslations = correctWords
        .map((w) => w.translation.toLowerCase().trim())
        .toSet();

    final availablePool = pool
        .where(
          (w) =>
              !correctIds.contains(w.id) &&
              !correctTranslations.contains(w.translation.toLowerCase().trim()),
        )
        .toList();

    if (availablePool.isEmpty) {
      for (final w in correctWords) {
        result[w.id] = [];
      }
      return result;
    }

    // ─── Группируем пул по урокам ───
    final poolByLesson = <int, List<Word>>{};
    final unknownLessonPool = <Word>[];
    for (final w in availablePool) {
      final lesson = _wordLessonMap[w.id];
      if (lesson != null) {
        poolByLesson.putIfAbsent(lesson, () => []).add(w);
      } else {
        unknownLessonPool.add(w);
      }
    }
    // Перемешиваем каждую группу
    for (final list in poolByLesson.values) {
      list.shuffle(_random);
    }
    unknownLessonPool.shuffle(_random);

    // ─── Назначаем дамми для каждого слова из ЕГО урока ───
    final usedIds = <int>{}; // Для уникальности между словами

    for (final word in correctWords) {
      final wordTranslation = word.translation.toLowerCase().trim();
      final wordLesson = _wordLessonMap[word.id] ?? currentLessonIndex;
      final candidates = <Word>[];

      // 1. Сначала берём из того же урока что и это конкретное слово
      if (wordLesson != null) {
        final sameLessonWords = poolByLesson[wordLesson] ?? [];
        for (final w in sameLessonWords) {
          if (candidates.length >= countPerWord) break;
          if (usedIds.contains(w.id)) continue;
          if (w.id == word.id) continue;
          if (w.translation.toLowerCase().trim() == wordTranslation) continue;
          candidates.add(w);
          usedIds.add(w.id);
        }
      }

      // 2. Если не хватило — добираем из других уроков
      if (candidates.length < countPerWord) {
        for (final w in availablePool) {
          if (candidates.length >= countPerWord) break;
          if (usedIds.contains(w.id)) continue;
          if (w.id == word.id) continue;
          final wLesson = _wordLessonMap[w.id];
          if (wLesson == wordLesson) continue; // уже обработали
          if (w.translation.toLowerCase().trim() == wordTranslation) continue;
          candidates.add(w);
          usedIds.add(w.id);
        }
      }

      result[word.id] = candidates;
    }

    final totalNeeded = countPerWord * correctWords.length;
    debugPrint(
      '🎯 DummyWords batch: ${correctWords.length} слов, '
      'по $countPerWord дамми каждому '
      '(пул: ${availablePool.length}, уникальность: ${usedIds.length >= totalNeeded ? "полная" : "частичная"})',
    );

    // ─── Подробные логи: для каждого правильного слова показать его дамми ───
    for (final word in correctWords) {
      final dummies = result[word.id] ?? [];
      final wordLesson = _wordLessonMap[word.id] ?? currentLessonIndex;
      debugPrint(
        '  🔹 "${word.word}" (id=${word.id}, урок=$wordLesson) → дамми:',
      );
      for (final d in dummies) {
        final fromLesson = _wordLessonMap[d.id];
        final sameFlag = (fromLesson == wordLesson) ? ' ✅СВОЙ' : ' ⚠️ЧУЖОЙ';
        debugPrint(
          '     ▸ "${d.word}" / "${d.translation}" (id=${d.id}, урок: ${fromLesson ?? "??"}$sameFlag)',
        );
      }
    }

    return result;
  }

  // ─── Приватные хелперы ───

  /// Добавить уникальных кандидатов в список, исключая по ID, слову и переводу.
  static void _addUniqueCandidates(
    List<Word> candidates,
    List<Word> newWords,
    Set<int> excludeIds,
    Set<String> excludeTranslations, [
    Set<String> excludeWordsText = const {},
  ]) {
    // Собираем уже добавленные переводы и слова для уникальности
    final existingTranslations = candidates
        .map((w) => w.translation.toLowerCase().trim())
        .toSet();
    final existingWords = candidates
        .map((w) => w.word.toLowerCase().trim())
        .toSet();

    for (final word in newWords) {
      final normalizedTranslation = word.translation.toLowerCase().trim();
      final normalizedWord = word.word.toLowerCase().trim();

      // Пропускаем если:
      // 1. ID в списке исключений
      // 2. Перевод совпадает с исключённым (= с правильным ответом)
      // 3. Английское слово совпадает с исключённым
      // 4. Перевод уже есть среди кандидатов (дубль перевода)
      // 5. Слово уже есть среди кандидатов (дубль слова)
      // 6. Пустой перевод или пустое слово
      if (excludeIds.contains(word.id)) continue;
      if (excludeTranslations.contains(normalizedTranslation)) continue;
      if (excludeWordsText.contains(normalizedWord)) continue;
      if (existingTranslations.contains(normalizedTranslation)) continue;
      if (existingWords.contains(normalizedWord)) continue;
      if (normalizedTranslation.isEmpty) continue;
      if (normalizedWord.isEmpty) continue;

      candidates.add(word);
      existingTranslations.add(normalizedTranslation);
      existingWords.add(normalizedWord);
    }
  }
}
