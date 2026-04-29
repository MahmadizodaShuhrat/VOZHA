import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/services/dummy_words_service.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';

/// Кэшированный пул дамми-слов для текущей тренировки.
///
/// Загружается один раз при старте тренировки и используется
/// всеми тренажёрами для подбора вариантов ответа.
///
/// Метод [prepareBatch] — распределяет уникальные дамми для каждого
/// слова раунда, чтобы пользователь не мог угадать методом исключения.
final dummyWordPoolProvider =
    NotifierProvider<DummyWordPoolNotifier, List<Word>>(
      DummyWordPoolNotifier.new,
    );

class DummyWordPoolNotifier extends Notifier<List<Word>> {
  /// Кэш назначений: wordId → дамми-слова для этого слова
  /// Пересчитывается при вызове [prepareBatch].
  Map<int, List<Word>> _batchAssignments = {};

  /// Текущий индекс урока (для приоритизации дамми из того же урока)
  int? _currentLessonIndex;

  @override
  List<Word> build() => [];

  void set(List<Word> pool) => state = pool;

  /// Загрузить пул дамми-слов для текущей категории и урока.
  Future<void> loadPool({
    required int categoryId,
    required int lessonIndex,
  }) async {
    _currentLessonIndex = lessonIndex;
    final learningWords = ref.read(learningWordsProvider);
    try {
      final pool = await DummyWordsService.loadDummyPool(
        categoryId: categoryId,
        lessonIndex: lessonIndex,
        excludeWords: learningWords,
      );
      state = pool;

      // Сразу распределяем уникальные дамми для батча
      _batchAssignments = DummyWordsService.pickUniqueForBatch(
        pool: pool,
        correctWords: learningWords,
        countPerWord: 3,
        currentLessonIndex: lessonIndex,
      );

      debugPrint(
        '✅ DummyWordPool загружен: ${pool.length} слов, '
        'назначения: ${_batchAssignments.length} слов',
      );
    } catch (e) {
      debugPrint('⚠️ DummyWordPool ошибка: $e');
      state = [];
      _batchAssignments = {};
    }
  }

  /// Получить 3 дамми для конкретного слова.
  /// Приоритет:
  /// 1. Из ТОГО ЖЕ урока (субкатегории) — напр. овощи→овощи
  /// 2. Из ТОЙ ЖЕ категории — напр. Еда→Еда
  /// 3. Из всего пула — fallback
  List<Word> pickForWord(Word targetWord, {int count = 3}) {
    if (state.isEmpty) return [];

    final targetTranslation = targetWord.translation.toLowerCase().trim();
    final targetWordText = targetWord.word.toLowerCase().trim();

    // Фильтруем пул: исключаем само слово по id, translation, word
    bool isValid(Word w) =>
        w.id != targetWord.id &&
        w.translation.toLowerCase().trim() != targetTranslation &&
        w.word.toLowerCase().trim() != targetWordText;

    // Калимаи бе категория — фавран аз пули умумӣ интихоб мекунем
    if (targetWord.categoryId <= 0) {
      debugPrint(
        '⚠️ pickForWord("${targetWord.word}") categoryId=${targetWord.categoryId}, using full pool',
      );
      final pool = state.where(isValid).toList()..shuffle();
      return pool.take(count).toList();
    }

    // 1. Сначала ищем в ТОМ ЖЕ уроке (субкатегории)
    if (targetWord.lessonIndex >= 0) {
      final sameLessonPool =
          state
              .where(
                (w) =>
                    w.categoryId == targetWord.categoryId &&
                    w.lessonIndex == targetWord.lessonIndex &&
                    isValid(w),
              )
              .toList()
            ..shuffle();

      if (sameLessonPool.length >= count) {
        final result = sameLessonPool.take(count).toList();
        debugPrint(
          '🎲 pickForWord("${targetWord.word}" L=${targetWord.lessonIndex}) → '
          'same lesson (${result.length})',
        );
        return result;
      }

      // Частично из урока + добираем из категории
      if (sameLessonPool.isNotEmpty) {
        final result = <Word>[...sameLessonPool];
        final usedIds = result.map((w) => w.id).toSet();
        final sameCatPool =
            state
                .where(
                  (w) =>
                      w.categoryId == targetWord.categoryId &&
                      isValid(w) &&
                      !usedIds.contains(w.id),
                )
                .toList()
              ..shuffle();
        for (final w in sameCatPool) {
          if (result.length >= count) break;
          result.add(w);
        }
        debugPrint(
          '🎲 pickForWord("${targetWord.word}" L=${targetWord.lessonIndex}) → '
          'mixed (${sameLessonPool.length} lesson + ${result.length - sameLessonPool.length} cat)',
        );
        return result;
      }
    }

    // 2. Из ТОЙ ЖЕ категории
    final sameCategoryPool =
        state
            .where((w) => w.categoryId == targetWord.categoryId && isValid(w))
            .toList()
          ..shuffle();

    if (sameCategoryPool.length >= count) {
      final result = sameCategoryPool.take(count).toList();
      debugPrint(
        '🎲 pickForWord("${targetWord.word}" cat=${targetWord.categoryId}) → '
        'same category (${result.length})',
      );
      return result;
    }

    // 3. Fallback — из всего пула
    final result = <Word>[...sameCategoryPool];
    final usedIds = result.map((w) => w.id).toSet();
    final otherPool =
        state.where((w) => isValid(w) && !usedIds.contains(w.id)).toList()
          ..shuffle();
    for (final w in otherPool) {
      if (result.length >= count) break;
      result.add(w);
    }
    debugPrint(
      '🎲 pickForWord("${targetWord.word}" cat=${targetWord.categoryId}) → '
      'fallback (${result.length})',
    );
    return result;
  }

  /// Пересчитать назначения для нового набора правильных слов.
  /// Вызывается если набор learningWords изменился.
  void prepareBatch({int countPerWord = 3}) {
    final learningWords = ref.read(learningWordsProvider);
    _batchAssignments = DummyWordsService.pickUniqueForBatch(
      pool: state,
      correctWords: learningWords,
      countPerWord: countPerWord,
      currentLessonIndex: _currentLessonIndex,
    );
    debugPrint(
      '🔄 DummyWordPool batch пересчитан: '
      '${_batchAssignments.length} слов, '
      'по $countPerWord дамми',
    );
  }
}
