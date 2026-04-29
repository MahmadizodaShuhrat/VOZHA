// lib/feature/home/presentation/screens/repeat_flow_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/services/word_repetition_service.dart';
import 'package:vozhaomuz/core/services/word_text_cache.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/time_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/close_page.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import 'package:vozhaomuz/shared/widgets/like_ListTile.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Страница повторения слов (Такрор).
/// Показывает до 10 слов с истёкшим таймаутом и кнопку "Оғоз" (Начать).
class RepeatFlowPage extends ConsumerStatefulWidget {
  const RepeatFlowPage({super.key});

  @override
  ConsumerState<RepeatFlowPage> createState() => _RepeatFlowPageState();
}

class _RepeatFlowPageState extends ConsumerState<RepeatFlowPage> {
  late List<WordProgress> _repeatWords;
  late String _langKey;
  bool _isLoading = true;
  bool _loadStarted = false; // guard against double-loading
  String _loadingStatus = '';
  List<Word> _enrichedWords = [];

  /// Orphan-cleanup is PENDING until the user actually taps Start. This way,
  /// opening the repeat page and closing it with X doesn't silently mutate
  /// the home repeat count — the user sees the same count they came in with.
  Set<int> _pendingPostponeIds = {};
  Set<int> _pendingRemoveIds = {};

  /// Flush the pending orphan cleanup into `progressProvider`. Called from
  /// the Start-button handler so the repeat-count drop only happens when
  /// the user commits to the session.
  void _applyPendingOrphanCleanup() {
    if (_pendingPostponeIds.isEmpty && _pendingRemoveIds.isEmpty) return;

    if (_pendingPostponeIds.isNotEmpty) {
      try {
        final progress = ref.read(progressProvider);
        final futureTimeout = DateTime.now().add(const Duration(days: 7));
        for (final entry in progress.dirs.entries) {
          for (final wp in entry.value) {
            if (_pendingPostponeIds.contains(wp.wordId)) {
              wp.timeout = futureTimeout;
            }
          }
        }
        ref.read(progressProvider.notifier).updateDirs(progress.dirs);
        debugPrint(
          '✅ [RepeatFlowPage] Postponed ${_pendingPostponeIds.length} orphaned words by 7 days (on Start)',
        );
      } catch (e) {
        debugPrint('⚠️ [RepeatFlowPage] Error postponing orphaned words: $e');
      }
    }

    if (_pendingRemoveIds.isNotEmpty) {
      try {
        final progress = ref.read(progressProvider);
        final updatedDirs = <String, List<WordProgress>>{};
        for (final entry in progress.dirs.entries) {
          updatedDirs[entry.key] = entry.value
              .where((w) => !_pendingRemoveIds.contains(w.wordId))
              .toList();
        }
        ref.read(progressProvider.notifier).updateDirs(updatedDirs);
        debugPrint(
          '✅ [RepeatFlowPage] Removed ${_pendingRemoveIds.length} truly orphaned words from progress (on Start)',
        );
      } catch (e) {
        debugPrint('⚠️ [RepeatFlowPage] Error cleaning orphaned words: $e');
      }
    }

    _pendingPostponeIds = {};
    _pendingRemoveIds = {};
  }

  @override
  void initState() {
    super.initState();

    // Получаем слова для повторения
    final repeatState = ref.read(repeatStateProvider);
    _repeatWords = repeatState.wordsForRepeat;
    _langKey = repeatState.langKey;

    // Загружаем текст слов из ресурсов курса
    _loadWordDetails();
  }

  Future<void> _loadWordDetails() async {
    // Guard: prevent double-loading (widget rebuild)
    if (_loadStarted) return;
    _loadStarted = true;
    final wordIds = _repeatWords.map((wp) => wp.wordId).toSet();
    // Collect categoryIds from progress for better filtering
    final categoryIds = _repeatWords
        .map((wp) => wp.categoryId)
        .where((id) => id > 0)
        .toSet();

    debugPrint(
      '🔍 [RepeatFlowPage] Loading word details for wordIds=$wordIds, categoryIds=$categoryIds, langKey=$_langKey',
    );

    try {
      // 1. Ожидаем полной загрузки категорий из API (ключевой фикс!)
      if (mounted) {
        setState(() {
          _loadingStatus = 'loading_categories'.tr();
        });
      }

      final List<CategoryFlutterDto> categories;
      try {
        categories = await ref.read(categoriesFlutterProvider.future);
      } catch (e) {
        debugPrint('⚠️ [RepeatFlowPage] Failed to load categories: $e');
        _finishWithFallback();
        return;
      }

      debugPrint(
        '📁 [RepeatFlowPage] Got ${categories.length} categories from API: ${categories.map((c) => "${c.id}(${c.languageType})").join(", ")}',
      );

      if (categories.isEmpty) {
        debugPrint('⚠️ [RepeatFlowPage] No categories loaded from API');
        _finishWithFallback();
        return;
      }

      // 2. Ищем слова ТОЛЬКО в категориях, которые содержат repeat-слова
      final wordMap = <int, Word>{};

      // Filter categories to only those that have repeat words
      final relevantCats = categories
          .where((c) => categoryIds.contains(c.id))
          .toList();

      debugPrint(
        '🔍 [RepeatFlowPage] Only checking ${relevantCats.length} categories with repeat words (of ${categories.length} total)',
      );

      // First pass: search only already-downloaded relevant categories
      final undownloadedCats = <CategoryFlutterDto>[];
      for (final cat in relevantCats) {
        final hasRes = await CategoryResourceService.hasResources(cat.id);
        if (!hasRes) {
          undownloadedCats.add(cat);
          continue;
        }

        final courseWords = await CategoryDbHelper.getWordsForCategory(cat.id);
        for (final w in courseWords) {
          if (wordIds.contains(w.id)) {
            wordMap[w.id] = w;
          }
        }
        if (wordMap.length >= wordIds.length) break;
      }

      // 2b. If words still missing — download FIRST needed category only
      //     Next repeat session will download the next category
      if (wordMap.length < wordIds.length &&
          undownloadedCats.isNotEmpty &&
          mounted) {
        final missingIds = wordIds.difference(wordMap.keys.toSet());
        final catToDownload = undownloadedCats.first;

        debugPrint(
          '📥 [RepeatFlowPage] ${missingIds.length} words missing, '
          'downloading category ${catToDownload.id} (1/${undownloadedCats.length})',
        );

        final foundWords = await showDialog<Map<int, Word>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _RepeatDownloadDialog(
            category: catToDownload,
            missingWordIds: missingIds,
          ),
        );

        if (foundWords != null && foundWords.isNotEmpty) {
          wordMap.addAll(foundWords);
        }
      }

      debugPrint(
        '✅ [RepeatFlowPage] Found ${wordMap.length}/${wordIds.length} words in course resources',
      );

      // 3. Fallback: check WordTextCache for any remaining missing words
      if (wordMap.length < wordIds.length) {
        final stillMissing = wordIds.difference(wordMap.keys.toSet());
        debugPrint(
          '🔍 [RepeatFlowPage] Checking WordTextCache for ${stillMissing.length} missing words...',
        );
        final cached = await WordTextCache.instance.getWords(stillMissing);
        for (final entry in cached.entries) {
          wordMap[entry.key] = Word(
            id: entry.key,
            word: entry.value.word,
            translation: entry.value.translation,
            transcription: entry.value.transcription,
            status: 'repeat',
            categoryId: entry.value.categoryId,
          );
          debugPrint(
            '📦 [RepeatFlowPage] Found word ${entry.key} ("${entry.value.word}") in WordTextCache',
          );
        }
      }

      // 4. Создаём Word-объекты — ТОЛЬКО для найденных слов (пропускаем orphaned IDs)
      final enriched = <Word>[];
      final validRepeatWords = <WordProgress>[];
      final orphanedWordIds = <int>[];
      for (final wp in _repeatWords) {
        final courseWord = wordMap[wp.wordId];
        if (courseWord == null) {
          debugPrint(
            '⚠️ [RepeatFlowPage] Skipping orphaned wordId=${wp.wordId} (not found in any category or cache)',
          );
          orphanedWordIds.add(wp.wordId);
          continue; // Пропускаем — "Калима #XX" не показываем
        }
        enriched.add(
          Word(
            id: wp.wordId,
            word: courseWord.word,
            translation: courseWord.translation,
            transcription: courseWord.transcription,
            status: 'repeat',
            categoryId: courseWord.categoryId > 0
                ? courseWord.categoryId
                : wp.categoryId,
            lessonIndex: courseWord.lessonIndex,
            photoPath: courseWord.photoPath,
            audioPath: courseWord.audioPath,
          ),
        );

        // Backfill WordProgress text fields so future repeat sessions
        // always have word text cached (prevents "Слово #ID" fallback)
        if (wp.original.isEmpty && courseWord.word.isNotEmpty) {
          wp.original = courseWord.word;
        }
        if (wp.translate.isEmpty && courseWord.translation.isNotEmpty) {
          wp.translate = courseWord.translation;
        }
        if (wp.transcription.isEmpty && courseWord.transcription.isNotEmpty) {
          wp.transcription = courseWord.transcription;
        }

        validRepeatWords.add(wp);
      }

      // Калимаҳои бе категория (categoryId=0) нест мекунем
      final beforeFilter = enriched.length;
      enriched.removeWhere((w) => w.categoryId <= 0);
      validRepeatWords.removeWhere((wp) => wp.categoryId <= 0 && !enriched.any((w) => w.id == wp.wordId));
      if (enriched.length < beforeFilter) {
        debugPrint(
          '⚠️ [RepeatFlowPage] Removed ${beforeFilter - enriched.length} words with invalid categoryId',
        );
      }

      debugPrint(
        '✅ [RepeatFlowPage] ${enriched.length} valid words, ${orphanedWordIds.length} orphaned skipped',
      );

      // 4b. Auto-cleanup STAGING: compute which orphaned words we'd postpone
      //     (category exists in API but not downloaded yet) vs. remove (category
      //     gone entirely). The mutation of `progressProvider` is DEFERRED to
      //     `_applyPendingOrphanCleanup()` which only runs when the user taps
      //     Start — so closing the page with X doesn't silently drop the
      //     home-screen repeat count.
      _pendingPostponeIds = {};
      _pendingRemoveIds = {};
      if (orphanedWordIds.isNotEmpty) {
        final apiCategoryIds = categories.map((c) => c.id).toSet();
        for (final wordId in orphanedWordIds) {
          final wp = _repeatWords.where((w) => w.wordId == wordId).firstOrNull;
          if (wp != null &&
              wp.categoryId > 0 &&
              apiCategoryIds.contains(wp.categoryId)) {
            _pendingPostponeIds.add(wordId);
          } else {
            _pendingRemoveIds.add(wordId);
          }
        }
        debugPrint(
          '📋 [RepeatFlowPage] Staged orphan cleanup: '
          'postpone=${_pendingPostponeIds.length}, remove=${_pendingRemoveIds.length} '
          '(applied on Start)',
        );
      }

      // Агар камтар аз 10 калима бошад — аз боқимондаи progress пуркунӣ
      const targetCount = 10;
      if (enriched.length < targetCount) {
        final enrichedIds = enriched.map((w) => w.id).toSet();

        // Категорияҳои боргирифташуда (ки ресурс доранд)
        final downloadedCatIds = <int>{};
        for (final cat in categories) {
          final hasRes = await CategoryResourceService.hasResources(cat.id);
          if (hasRes) downloadedCatIds.add(cat.id);
        }

        debugPrint(
          '📦 [RepeatFlowPage] Downloaded categories for fill-up: $downloadedCatIds',
        );

        // Аз ҳамаи калимаҳои такрор — калимаҳоеро ки дар категорияи боргирифташуда ҳастанд
        final progress = ref.read(progressProvider);
        final allProgressWords = progress.dirs[_langKey] ?? [];
        final extraCandidates = WordRepetitionService.getWordsForRepeat(allProgressWords)
            .where((wp) =>
                !enrichedIds.contains(wp.wordId) &&
                !orphanedWordIds.contains(wp.wordId) &&
                wp.categoryId > 0 &&
                downloadedCatIds.contains(wp.categoryId))
            .toList()
          ..sort((a, b) => a.timeout.compareTo(b.timeout));

        // Аввал калимаҳоро аз wordMap мегирем (аллакай бор шудаанд)
        for (final wp in extraCandidates) {
          if (enriched.length >= targetCount) break;
          final courseWord = wordMap[wp.wordId];
          if (courseWord != null && courseWord.categoryId > 0) {
            enriched.add(Word(
              id: wp.wordId,
              word: courseWord.word,
              translation: courseWord.translation,
              transcription: courseWord.transcription,
              status: 'repeat',
              categoryId: courseWord.categoryId > 0 ? courseWord.categoryId : wp.categoryId,
              lessonIndex: courseWord.lessonIndex,
              photoPath: courseWord.photoPath,
              audioPath: courseWord.audioPath,
            ));
            validRepeatWords.add(wp);
            enrichedIds.add(wp.wordId);
            debugPrint('➕ [RepeatFlowPage] Added extra word: ${courseWord.word} (${wp.wordId})');
          }
        }

        // Агар ҳанӯз кам бошад — калимаҳоро аз категорияҳои нав бор мекунем
        if (enriched.length < targetCount) {
          final stillNeeded = extraCandidates
              .where((wp) => !enrichedIds.contains(wp.wordId))
              .toList();
          final neededCatIds = stillNeeded.map((wp) => wp.categoryId).toSet();

          for (final catId in neededCatIds) {
            if (enriched.length >= targetCount) break;
            if (!downloadedCatIds.contains(catId)) continue;

            final catWords = await CategoryDbHelper.getWordsForCategory(catId);
            final catWordMap = <int, Word>{};
            for (final w in catWords) {
              catWordMap[w.id] = w;
            }

            for (final wp in stillNeeded) {
              if (enriched.length >= targetCount) break;
              if (wp.categoryId != catId) continue;
              final courseWord = catWordMap[wp.wordId];
              if (courseWord != null && courseWord.categoryId > 0) {
                enriched.add(Word(
                  id: wp.wordId,
                  word: courseWord.word,
                  translation: courseWord.translation,
                  transcription: courseWord.transcription,
                  status: 'repeat',
                  categoryId: courseWord.categoryId > 0 ? courseWord.categoryId : wp.categoryId,
                  lessonIndex: courseWord.lessonIndex,
                  photoPath: courseWord.photoPath,
                  audioPath: courseWord.audioPath,
                ));
                validRepeatWords.add(wp);
                enrichedIds.add(wp.wordId);
                wordMap[wp.wordId] = courseWord;
                debugPrint('➕ [RepeatFlowPage] Added from cat $catId: ${courseWord.word} (${wp.wordId})');
              }
            }
          }
        }

        debugPrint(
          '📊 [RepeatFlowPage] After fill-up: ${enriched.length}/$targetCount words',
        );
      }

      // Обновляем _repeatWords чтобы mapWordsToGames работал синхронно
      _repeatWords = validRepeatWords;

      if (enriched.isEmpty) {
        debugPrint('⚠️ [RepeatFlowPage] No valid words for repeat, going back');
        if (mounted) Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      setState(() {
        _enrichedWords = enriched;
        _isLoading = false;
      });

      // ═══ Unity-style: map words to specific games ═══
      final gameMap = WordRepetitionService.mapWordsToGames(_repeatWords);

      // Convert WordProgress-based map to Word-based map
      final wordById = <int, Word>{};
      for (final w in enriched) {
        wordById[w.id] = w;
      }

      final wordGameMap = <String, List<Word>>{};
      int totalDots = 0;
      final gameOrder = <String>[];
      final assignedWordIds = <int>{};

      for (final gameName in WordRepetitionService.allGameNames) {
        final progressWords = gameMap[gameName] ?? [];
        if (progressWords.isEmpty) continue;

        final words = <Word>[];
        for (final wp in progressWords) {
          final w = wordById[wp.wordId];
          if (w != null) words.add(w);
        }
        if (words.isEmpty) continue;

        wordGameMap[gameName] = words;
        assignedWordIds.addAll(words.map((w) => w.id));
        totalDots += words.length;
        gameOrder.add(gameName);
      }

      final missingWords = enriched
          .where((w) => !assignedWordIds.contains(w.id))
          .toList();
      if (missingWords.isNotEmpty) {
        final fallbackGame = WordRepetitionService.selectTranslationGame;
        wordGameMap[fallbackGame] = [
          ...(wordGameMap[fallbackGame] ?? []),
          ...missingWords,
        ];
        totalDots += missingWords.length;
        if (!gameOrder.contains(fallbackGame)) {
          gameOrder.insert(0, fallbackGame);
        }
        debugPrint(
          '⚠️ [RepeatFlow] ${missingWords.length} words had unsupported game keys; '
          'routing them to $fallbackGame',
        );
      }

      // NOTE: the old Memoria-only warmup (added a pre-round of Select
      // translation with all 10 enriched words before Memoria itself)
      // is intentionally removed. It doubled the session to 20 dots
      // when the product rule is "10 questions per repeat session".
      // If Memoria feels too hard without a warmup we'll reintroduce
      // it with a mode that doesn't inflate the dot count.

      debugPrint('🎮 [RepeatFlow] Game map:');
      for (final entry in wordGameMap.entries) {
        debugPrint(
          '   ${entry.key}: ${entry.value.length} words (${entry.value.map((w) => w.word).join(", ")})',
        );
      }
      debugPrint(
        '🎮 [RepeatFlow] Total dots: $totalDots, game order: $gameOrder',
      );

      // Fallback: if no games have words, put all in flashcards
      if (gameOrder.isEmpty) {
        wordGameMap[WordRepetitionService.selectTranslationGame] = enriched;
        totalDots = enriched.length;
        gameOrder.add(WordRepetitionService.selectTranslationGame);
      }

      // Set repeat game providers
      ref.read(repeatGameMapProvider.notifier).set(wordGameMap);
      ref.read(repeatGameOrderProvider.notifier).set(gameOrder);
      ref.read(repeatGameIndexProvider.notifier).set(0);
      ref.read(allRepeatWordsProvider.notifier).set(enriched);

      // Cache original states at session start so _sendRepeatResults uses
      // the correct pre-session state, not stale live progress data
      final originalStates = <int, int>{};
      for (final wp in _repeatWords) {
        originalStates[wp.wordId] = wp.state;
      }
      ref.read(repeatOriginalStatesProvider.notifier).set(originalStates);
      debugPrint('📦 [RepeatFlow] Cached ${originalStates.length} original states');

      // Map game name → GameStage for the first game
      final firstGameName = gameOrder.first;
      final firstStage = _gameNameToStage(firstGameName);
      final firstWords = wordGameMap[firstGameName] ?? enriched;

      // Set providers for games
      ref.read(learningWordsProvider.notifier).set(firstWords);
      ref.read(isRepeatModeProvider.notifier).set(true);
      ref.read(gameStageProvider.notifier).set(firstStage);
      ref.read(currentWordIndexProvider.notifier).set(0);
      ref.read(dotsProvider.notifier).resetWithCount(totalDots);

      // Set AudioContext so sound game can find audio files
      final catIds = enriched.map((w) => w.categoryId).toSet();
      for (final catId in catIds) {
        final coursePath = await CategoryResourceService.getCoursePath(catId);
        if (coursePath != null) {
          AudioContext.currentLessonDir = coursePath;
          debugPrint(
            '🔊 [RepeatFlow] AudioContext.currentLessonDir = $coursePath',
          );
          break; // use the first found course path
        }
      }

      // Load dummy word pool
      await _loadDummyPool(enriched);
    } catch (e, st) {
      debugPrint('❌ [RepeatFlowPage] Error loading words: $e\n$st');
      _finishWithFallback();
    }
  }

  /// Maps Unity game name strings to Flutter GameStage enum
  static GameStage _gameNameToStage(String gameName) {
    switch (gameName) {
      case 'Select translation':
      case 'Select translation - voice':
        return GameStage.flashcards;
      case 'Memoria':
        return GameStage.matching;
      case 'True-False':
        return GameStage.trueFalse;
      case 'Select translation - audio':
        return GameStage.sound;
      case 'Write a translation':
      case 'Write a word':
        return GameStage.keyboard;
      default:
        return GameStage.flashcards;
    }
  }

  /// Завершает загрузку, используя fallback-тексты.
  void _finishWithFallback() {
    final enriched = <Word>[];
    for (final wp in _repeatWords) {
      // Skip words with no text — never show "Слово #ID"
      if (wp.original.isEmpty) {
        debugPrint('⚠️ [Fallback] Skipping wordId=${wp.wordId} — no text available');
        continue;
      }
      // Калимаи бе категория — гузаронидан
      if (wp.categoryId <= 0) {
        debugPrint('⚠️ [Fallback] Skipping wordId=${wp.wordId} — invalid categoryId=${wp.categoryId}');
        continue;
      }
      enriched.add(
        Word(
          id: wp.wordId,
          word: wp.original,
          translation: wp.translate,
          transcription: wp.transcription,
          status: 'repeat',
          categoryId: wp.categoryId,
        ),
      );
    }

    if (!mounted) return;

    // Агар калимаҳо холӣ бошанд — бозгашт
    if (enriched.isEmpty) {
      debugPrint('⚠️ [RepeatFlowPage Fallback] No valid words for repeat, going back');
      Navigator.pop(context);
      return;
    }

    setState(() {
      _enrichedWords = enriched;
      _isLoading = false;
    });

    // Unity-style game mapping even in fallback
    final gameMap = WordRepetitionService.mapWordsToGames(_repeatWords);
    final wordById = <int, Word>{};
    for (final w in enriched) {
      wordById[w.id] = w;
    }

    final wordGameMap = <String, List<Word>>{};
    int totalDots = 0;
    final gameOrder = <String>[];
    final assignedWordIds = <int>{};

    for (final gameName in WordRepetitionService.allGameNames) {
      final progressWords = gameMap[gameName] ?? [];
      if (progressWords.isEmpty) continue;
      final words = <Word>[];
      for (final wp in progressWords) {
        final w = wordById[wp.wordId];
        if (w != null) words.add(w);
      }
      if (words.isEmpty) continue;
      wordGameMap[gameName] = words;
      assignedWordIds.addAll(words.map((w) => w.id));
      totalDots += words.length;
      gameOrder.add(gameName);
    }

    final missingWords = enriched
        .where((w) => !assignedWordIds.contains(w.id))
        .toList();
    if (missingWords.isNotEmpty) {
      final fallbackGame = WordRepetitionService.selectTranslationGame;
      wordGameMap[fallbackGame] = [
        ...(wordGameMap[fallbackGame] ?? []),
        ...missingWords,
      ];
      totalDots += missingWords.length;
      if (!gameOrder.contains(fallbackGame)) {
        gameOrder.insert(0, fallbackGame);
      }
      debugPrint(
        '⚠️ [RepeatFlow Fallback] ${missingWords.length} words had unsupported '
        'game keys; routing them to $fallbackGame',
      );
    }

    // Fallback: if no games have words, put all in flashcards
    if (gameOrder.isEmpty) {
      wordGameMap[WordRepetitionService.selectTranslationGame] = enriched;
      totalDots = enriched.length;
      gameOrder.add(WordRepetitionService.selectTranslationGame);
    }

    ref.read(repeatGameMapProvider.notifier).set(wordGameMap);
    ref.read(repeatGameOrderProvider.notifier).set(gameOrder);
    ref.read(repeatGameIndexProvider.notifier).set(0);
    ref.read(allRepeatWordsProvider.notifier).set(enriched);

    final firstStage = _gameNameToStage(gameOrder.first);
    final firstWords = wordGameMap[gameOrder.first] ?? enriched;

    ref.read(learningWordsProvider.notifier).set(firstWords);
    ref.read(isRepeatModeProvider.notifier).set(true);
    ref.read(gameStageProvider.notifier).set(firstStage);
    ref.read(currentWordIndexProvider.notifier).set(0);
    ref.read(dotsProvider.notifier).resetWithCount(totalDots);
  }

  /// Загружает dummy-пул: ВСЕ слова из ВСЕХ категорий repeat-слов.
  /// pickForWord потом фильтрует по categoryId правильного слова.
  Future<void> _loadDummyPool(List<Word> enrichedWords) async {
    try {
      var categoryIds = enrichedWords
          .map((w) => w.categoryId)
          .where((id) => id > 0)
          .toSet();

      // Агар ҳеҷ категорияи дуруст нест — аз categoryId-ҳои progress мегирем
      if (categoryIds.isEmpty && enrichedWords.isNotEmpty) {
        debugPrint(
          '⚠️ [RepeatFlowPage] No valid categoryIds in enriched words, using progress categoryIds',
        );
        categoryIds = _repeatWords
            .map((wp) => wp.categoryId)
            .where((id) => id > 0)
            .toSet();
      }

      debugPrint(
        '🎲 [RepeatFlowPage] Loading dummy pool from categories: $categoryIds',
      );

      final excludeIds = enrichedWords.map((w) => w.id).toSet();
      final excludeTranslations = enrichedWords
          .map((w) => w.translation.toLowerCase().trim())
          .toSet();

      final allDummyWords = <Word>[];

      for (final catId in categoryIds) {
        try {
          final catWords = await CategoryDbHelper.getWordsForCategory(catId);
          for (final w in catWords) {
            if (!excludeIds.contains(w.id) &&
                !excludeTranslations.contains(
                  w.translation.toLowerCase().trim(),
                )) {
              allDummyWords.add(w);
            }
          }
        } catch (e) {
          debugPrint(
            '⚠️ [RepeatFlowPage] Error loading cat $catId for dummy: $e',
          );
        }
      }

      debugPrint(
        '✅ [RepeatFlowPage] Dummy pool: ${allDummyWords.length} words '
        'from ${categoryIds.length} categories',
      );

      if (allDummyWords.isNotEmpty) {
        ref.read(dummyWordPoolProvider.notifier).set(allDummyWords);
      }
    } catch (e) {
      debugPrint('⚠️ [RepeatFlowPage] Error loading dummy pool: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showExitConfirmationDialog(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAFF),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: const Color(0xFFF5FAFF),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 30),
            onPressed: () {
              ref.read(isRepeatModeProvider.notifier).set(false);
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            "Repeat".tr(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202939),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Информация о количестве слов для повторения
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.replay,
                      color: Color(0xFFF9A628),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "repeat_count".tr(args: [_repeatWords.length.toString()]),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF856404),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Список слов для повторения (scrollable)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              if (_loadingStatus.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _loadingStatus,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF697586),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                              bottom: BorderSide(
                                color: Color(0xFFEEF2F6),
                                width: 6,
                              ),
                              right: BorderSide(
                                color: Color(0xFFEEF2F6),
                                width: 2,
                              ),
                              left: BorderSide(
                                color: Color(0xFFEEF2F6),
                                width: 2,
                              ),
                              top: BorderSide(
                                color: Color(0xFFEEF2F6),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Жёлтый заголовок
                              Container(
                                height: 65,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    topRight: Radius.circular(10),
                                  ),
                                  color: Color(0xFFFCD60D),
                                ),
                                child: Center(
                                  child: Text(
                                    "Review_these_Words".tr(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xff697586),
                                    ),
                                  ),
                                ),
                              ),
                              // Прокручиваемый список слов
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _enrichedWords.length,
                                  separatorBuilder: (_, __) => Divider(
                                    color: Colors.grey.shade200,
                                    height: 0,
                                  ),
                                  itemBuilder: (_, i) => likeListTile(
                                    _enrichedWords[i].word,
                                    transcription:
                                        _enrichedWords[i].transcription,
                                    translation: _enrichedWords[i].translation,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              // Кнопка "Оғоз" (Начать)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MyButton(
                  width: double.infinity,
                  buttonColor: _enrichedWords.isNotEmpty
                      ? const Color(0xFFFCD60D)
                      : const Color(0xFFE3E8EF),
                  backButtonColor: _enrichedWords.isNotEmpty
                      ? const Color(0xFFEAB308)
                      : const Color(0xFFCDD5DF),
                  borderRadius: 10,
                  onPressed: _enrichedWords.isNotEmpty
                      ? () {
                          HapticFeedback.lightImpact();
                          // Commit orphan cleanup now that the user is
                          // actually starting the session — if they had
                          // bailed out with X, nothing would have been
                          // mutated and the home repeat count would have
                          // stayed intact.
                          _applyPendingOrphanCleanup();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CountdownPage()),
                          );
                        }
                      : null,
                  child: Center(
                    child: Text(
                      "Start".tr(),
                      style: AppTextStyles.whiteTextStyle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _enrichedWords.isNotEmpty
                            ? Colors.black
                            : const Color(0xFF9AA4B2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Download dialog for repeat flow
// Downloads ONE category and searches for missing words in it
// ═══════════════════════════════════════════════════════════════════
class _RepeatDownloadDialog extends StatefulWidget {
  const _RepeatDownloadDialog({
    required this.category,
    required this.missingWordIds,
  });
  final CategoryFlutterDto category;
  final Set<int> missingWordIds;

  @override
  State<_RepeatDownloadDialog> createState() => _RepeatDownloadDialogState();
}

class _RepeatDownloadDialogState extends State<_RepeatDownloadDialog> {
  double _progress = 0;
  bool _downloading = false;
  bool _hasError = false;
  final Map<int, Word> _foundWords = {};

  Future<void> _startDownload() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _hasError = false;
      _progress = 0;
    });

    try {
      final result = await CategoryResourceService.downloadAndExtract(
        widget.category,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      ); // No external timeout — Dio has its own 10-min receiveTimeout

      if (result != null) {
        final courseWords = await CategoryDbHelper.getWordsForCategory(
          widget.category.id,
        );
        for (final w in courseWords) {
          if (widget.missingWordIds.contains(w.id)) {
            _foundWords[w.id] = w;
            debugPrint(
              '✅ Found word ${w.id} ("${w.word}") in category ${widget.category.id}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Category ${widget.category.id} download failed: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _downloading = false;
        });
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(_foundWords.isNotEmpty ? _foundWords : null);
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
    final locale = Localizations.localeOf(context);
    final langCode = locale.languageCode == 'tg' ? 'tj' : locale.languageCode;
    final catName = widget.category.getLocalizedName(langCode);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'download_please_wait'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            // Category icon in circular progress
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _downloading
                        ? (_progress > 0 ? _progress : null)
                        : 0,
                    strokeWidth: 10,
                    backgroundColor: Colors.blue.shade50,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ),
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.category.icon,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(
                      width: 60,
                      height: 60,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      _hasError ? Icons.error_outline : Icons.download_rounded,
                      size: 40,
                      color: _hasError ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Category name
            Text(
              catName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF314456),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _hasError
                  ? 'download_error'.tr()
                  : _downloading
                  ? 'download_preparing'.tr()
                  : 'download_start_prompt'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (_downloading || _hasError)
              Text(
                _hasError
                    ? 'download_please_retry'.tr()
                    : 'download_progress'.tr(args: [percent]),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 24),
            MyButton(
              depth: (_downloading && !_hasError) ? 0 : 4,
              buttonColor: const Color(0xFFFDE047),
              backButtonColor: const Color(0xFFEAB308),
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              onPressed: _downloading && !_hasError ? null : _startDownload,
              child: Text(
                _hasError
                    ? 'download_retry'.tr()
                    : 'download_ready_button'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 10),
            MyButton(
              depth: 4,
              buttonColor: const Color(0xFFE3E8EF),
              backButtonColor: const Color(0xFFCDD5DF),
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'download_cancel_button'.tr(),
                style: const TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
