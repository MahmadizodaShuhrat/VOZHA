// lib/core/services/word_repetition_service.dart
import 'dart:math';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

/// Сервис повторения слов (Такрор).
/// Зеркалит логику Unity: IsWordWithRepeat, UIGames.cs
class WordRepetitionService {
  /// Минимальное количество слов для активации режима повторения.
  /// Раньше было 10 — слишком высокий порог, активные юзеры с 5–9
  /// просроченными словами никогда не видели режим Repeat и слова
  /// продолжали накапливаться в долгу (а кнопка тихо не появлялась).
  /// Снижено до 4 — это минимальная разумная пачка (одна сессия игр
  /// 'Memoria' требует ровно 4 слова для нормального геймплея).
  static const int minRepeatCount = 10;

  /// Максимум слов в одной сессии повторения. Если у юзера больше слов
  /// готовых для повторения — он закроет сессию, синкнет, и кнопка снова
  /// предложит следующую пачку. Меньше = быстрее цикл +синк, больше =
  /// длиннее непрерывная сессия. 10 — баланс «стандартная Anki-сессия».
  static const int maxSessionSize = 10;

  static const String selectTranslationGame = 'Select translation';
  static const String memoriaGame = 'Memoria';
  static const String selectTranslationAudioGame = 'Select translation - audio';
  static const String writeTranslationGame = 'Write a translation';

  /// Названия игр, соответствующие GameStage
  static const List<String> allGameNames = [
    selectTranslationGame, // flashcards / GameStage index 1
    memoriaGame, // matching / GameStage index 2
    selectTranslationAudioGame, // sound / GameStage index 3
    writeTranslationGame, // keyboard / GameStage index 4
  ];

  /// Normalizes legacy and unsupported game names to repeat-safe games.
  static String normalizeGameForRepeat(
    String gameName, {
    required int wordCount,
  }) {
    switch (gameName) {
      case selectTranslationGame:
      case selectTranslationAudioGame:
        return gameName;
      case memoriaGame:
        return wordCount >= 2 ? memoriaGame : selectTranslationGame;
      case 'Write a word':
      case writeTranslationGame:
        return writeTranslationGame;
      case 'Select translation - voice':
      case 'Say the word':
      case 'Find the word':
        return selectTranslationGame;
      case 'True-False':
        return wordCount >= 2 ? memoriaGame : selectTranslationGame;
      default:
        return selectTranslationGame;
    }
  }

  /// Калимаи омӯхташуда (state ≥ 1) бо timeout-и гузашта — омодаи санҷиш
  /// тавассути бозиҳои Repeat (Memoria, Write a translation ва ғ.).
  /// Range-и state аз Unity (-3..3) ба [1..3] маҳдуд карда шуд: калимаҳои
  /// state ≤ 0 ҳанӯз "омӯхта нашудаанд" — онҳо ба `isWordWithRelearn`
  /// мепайвандад ва тавассути flashcards дар ҷараёни Learn боз пешниҳод
  /// мешаванд, на дар Repeat session.
  static bool isWordWithRepeat(WordProgress w) {
    final now = DateTime.now();
    return w.timeout.isBefore(now) &&
        w.state >= 1 &&
        w.state <= 3 &&
        w.firstDone == false;
  }

  /// Калимае, ки корбар нодуруст ҷавоб додааст ё ҳанӯз амиқ омӯхта нашуда
  /// (state ∈ [-3..0]) бо timeout-и гузашта. Ин калимаҳо ба ҷараёни Learn
  /// (flashcards) бар мегарданд, на ба Repeat — то корбар онҳоро аввал
  /// мустаҳкам кунад, баъд санҷиш кунад.
  static bool isWordWithRelearn(WordProgress w) {
    final now = DateTime.now();
    return w.timeout.isBefore(now) &&
        w.state >= -3 &&
        w.state <= 0 &&
        w.firstDone == false;
  }

  /// Возвращает список слов, нуждающихся в повторении.
  static List<WordProgress> getWordsForRepeat(List<WordProgress> all) {
    return all.where(isWordWithRepeat).toList();
  }

  /// Калимаҳое, ки барои бозомӯзӣ дар Learn-flow тайёранд.
  static List<WordProgress> getWordsForRelearn(List<WordProgress> all) {
    return all.where(isWordWithRelearn).toList();
  }

  /// Количество слов для повторения.
  static int getRepeatCount(List<WordProgress> all) {
    return getWordsForRepeat(all).length;
  }

  /// Шумораи калимаҳои барои бозомӯзӣ.
  static int getRelearnCount(List<WordProgress> all) {
    return getWordsForRelearn(all).length;
  }

  /// Нужно ли показывать кнопку "Такрор" (≥10 слов).
  static bool needsRepeat(List<WordProgress> all) {
    return getRepeatCount(all) >= minRepeatCount;
  }

  /// Выбирает до [count] слов для текущей сессии повторения.
  /// Unity: GetWordsIdWithRepeat берёт первые 10 из БД (детерминистически).
  /// Мы сортируем по timeout (самые просроченные первые), чтобы слова
  /// с наиболее давно истёкшим timeout всегда были в приоритете.
  /// Это предотвращает ситуацию когда одни и те же слова показываются
  /// повторно, а другие игнорируются.
  static List<WordProgress> pickWordsForSession(
    List<WordProgress> all, {
    int count = maxSessionSize,
  }) {
    final repeatWords = getWordsForRepeat(all);
    // Sort by timeout ascending: most overdue words first (longest expired)
    repeatWords.sort((a, b) => a.timeout.compareTo(b.timeout));
    final selected = repeatWords.take(count).toList();
    // Group by categoryId first, then sort by state within each category
    selected.sort((a, b) {
      final catCmp = a.categoryId.compareTo(b.categoryId);
      if (catCmp != 0) return catCmp;
      return a.state.compareTo(b.state);
    });
    return selected;
  }

  /// Маппинг слов на игры на основе errorInGames.
  /// Зеркалит Unity UIGames.cs OnEnable (lines 149-230):
  ///
  /// 1. Слова С ошибками → маршрутизируются в игры, где были ошибки.
  ///    - Ошибки 'Say the word'/'Find the word' → первая игра (Select translation)
  ///    - Ошибки 'Memoria'/'True-False' при кол-ве слов ≠ 4 → первая игра
  /// 2. Слова БЕЗ ошибок:
  ///    - Если есть игры с ошибками → добавляем в первую свободную игру
  ///    - Если нет свободных → в случайную существующую
  ///    - Если вообще нет ошибок → все в одну случайную игру
  static Map<String, List<WordProgress>> mapWordsToGames(
    List<WordProgress> words,
  ) {
    final rng = Random();
    final map = <String, List<WordProgress>>{};
    // Track which wordIds are already in each game to prevent duplicates
    final addedPerGame = <String, Set<int>>{};
    final wordsNoErrors = <WordProgress>[];

    for (final word in words) {
      if (word.errorInGames.isNotEmpty) {
        // Route each word to the FIRST game it failed in only. Previously we
        // added the same word to every entry in errorInGames, which could
        // turn a 10-word session into 20+ attempts if words had failed in
        // multiple games. Cap at one attempt per word per session.
        final targetGame = normalizeGameForRepeat(
          word.errorInGames.first,
          wordCount: words.length,
        );

        if (!map.containsKey(targetGame)) {
          map[targetGame] = [];
          addedPerGame[targetGame] = {};
        }
        if (!addedPerGame[targetGame]!.contains(word.wordId)) {
          map[targetGame]!.add(word);
          addedPerGame[targetGame]!.add(word.wordId);
        }
      } else {
        wordsNoErrors.add(word);
      }
    }

    if (map.isNotEmpty && wordsNoErrors.isNotEmpty) {
      // Unity: find first game NOT in map and add noError words there
      bool added = false;
      for (final game in allGameNames) {
        if (!map.containsKey(game)) {
          map[game] = wordsNoErrors;
          added = true;
          break;
        }
      }
      if (!added) {
        // Unity: random game from first 3, add to existing
        final validGames = allGameNames.take(3).toList();

        if (validGames.isNotEmpty) {
          final targetGame = validGames[rng.nextInt(validGames.length)];
          map[targetGame] = [...(map[targetGame] ?? []), ...wordsNoErrors];
        } else {
          // Fallback to first
          map[allGameNames[0]] = [
            ...(map[allGameNames[0]] ?? []),
            ...wordsNoErrors,
          ];
        }
      }
    } else if (map.isEmpty) {
      // Unity: no errors at all → all words go to one random game
      final validGames = allGameNames.take(3).toList();

      if (validGames.isNotEmpty) {
        final targetGame = validGames[rng.nextInt(validGames.length)];
        map[targetGame] = wordsNoErrors;
      } else {
        map[allGameNames[0]] = wordsNoErrors;
      }
    }

    return map;
  }

  /// Вычисляет новый state на основе текущего (зеркалит Unity UIResults.cs:180-301).
  ///
  /// Правильный ответ:
  ///   - isFirstDone=true → state = 4 (выучено сразу)
  ///   - state < 0 → сброс на 0, потом ++ → 1
  ///   - state >= 0 → state++
  ///   - state == 4 → остаётся 4 (выучено)
  ///
  /// Ошибка:
  ///   - state <= 0 → state--
  ///   - state > 0 → state не меняется, только timeout +1d
  static int computeNewState({
    required int currentState,
    required bool isCorrect,
    bool isFirstDone = false,
  }) {
    if (isCorrect) {
      if (isFirstDone) return 4;
      if (currentState == 4) return 4;
      if (currentState < 0) return 1; // reset to 0 then ++
      return currentState + 1;
    } else {
      // Ошибка
      if (currentState <= 0) return currentState - 1;
      // Если state > 0 и ошибка — в Unity state не меняется для уже
      // положительных слов при ошибке (timeout = +1d).
      // Но при состоянии <= 0 — уменьшаем.
      return currentState;
    }
  }

  /// Вычисляет таймаут (следующую дату повторения) на основе нового state.
  /// Зеркалит Unity UIResults.cs:213-250, 276.
  ///
  /// Правильный ответ:
  ///   state 1 → +2 дня
  ///   state 2 → +7 дней
  ///   state 3 → +14 дней
  ///   state 4 → now (выучено)
  ///
  /// Ошибка → +1 день
  static DateTime computeTimeout({
    required int newState,
    required bool isCorrect,
  }) {
    final now = DateTime.now();

    if (!isCorrect) {
      return now.add(const Duration(days: 1));
    }

    switch (newState) {
      case 1:
        return now.add(const Duration(days: 2));
      case 2:
        return now.add(const Duration(days: 7));
      case 3:
        return now.add(const Duration(days: 14));
      case 4:
        return now; // выучено
      default:
        return now.add(const Duration(days: 2));
    }
  }
}
