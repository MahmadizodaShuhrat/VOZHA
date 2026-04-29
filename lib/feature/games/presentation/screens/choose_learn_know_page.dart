import 'dart:io';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/screens/navigation_bar.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/core/utils/zip_resource_loader.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/feature/home/data/categories_repository.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/trenirovka_page.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_lesson_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/close_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/shared/widgets/swipe_card_stack.dart';
import 'package:vozhaomuz/shared/widgets/word_card.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/selected_level_provider.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/core/services/word_repetition_service.dart';

// Загрузка субкатегорий из скачанной DB категории
final subcategoriesProvider = FutureProvider.family<List<Subcategory>, int>((
  ref,
  categoryId,
) async {
  // Watch locale so provider auto-invalidates when locale changes
  final locale = ref.watch(localeProvider);
  debugPrint(
    '📂 subcategoriesProvider: загрузка для категории $categoryId (locale: ${locale.languageCode})',
  );
  final subcategories = await CategoryDbHelper.getSubcategories(categoryId);
  debugPrint('✅ Загружено ${subcategories.length} субкатегорий');
  return subcategories;
});

// Загрузка слов из JSON курса по (categoryId, lessonIndex)
// lessonIndex — 0-based индекс урока
final wordsProvider =
    FutureProvider.family<List<Word>, ({int categoryId, int lessonIndex})>((
      ref,
      params,
    ) async {
      // Watch locale so provider auto-invalidates when locale changes
      final locale = ref.watch(localeProvider);
      debugPrint(
        '📂 wordsProvider: загрузка для категории ${params.categoryId}, урок ${params.lessonIndex} (locale: ${locale.languageCode})',
      );
      final words = await CategoryDbHelper.getWordsForLesson(
        params.categoryId,
        params.lessonIndex,
      );
      debugPrint('✅ Загружено ${words.length} слов');
      return words;
    });

class ChoseLearnKnowPage extends ConsumerStatefulWidget {
  final int categoryId;
  final List<Word>? preloadedWords;
  final bool viewOnly;
  final int? lessonIndex; // 0-based lesson index from CourseLessonPage
  final String? lessonTitle; // Title of the lesson (e.g. 'Unit 1')
  /// When true, clears 'learning' statuses on init (fresh session from home/category).
  /// When false (e.g. from "Учить ещё"), keeps them so previously selected words are skipped.
  final bool clearLearningOnInit;
  const ChoseLearnKnowPage({
    required this.categoryId,
    this.preloadedWords,
    this.viewOnly = false,
    this.lessonIndex,
    this.lessonTitle,
    this.clearLearningOnInit = true,
    Key? key,
  }) : super(key: key);
  @override
  ConsumerState<ChoseLearnKnowPage> createState() => _ChoseLearnKnowPageState();
}

class _ChoseLearnKnowPageState extends ConsumerState<ChoseLearnKnowPage> {
  late final AudioPlayer _player;
  late final FutureProvider<List<Word>> filteredWordsProvider;
  List<Word> _currentWords = [];
  // After the 4th swipe we push TrenirovkaPage. The swipe stack still reveals
  // the next (5th) card and fires onCardAppeared, which would play its audio.
  // This flag suppresses that last playback so the training starts silently.
  bool _suppressCardAudio = false;

  /// Pre-cache images AND audio for the next 5 word cards from [startIndex].
  void _precacheUpcoming(int startIndex) {
    final end = (startIndex + 5).clamp(0, _currentWords.length);
    for (int i = startIndex; i < end; i++) {
      final w = _currentWords[i];
      if (w.photoPath != null &&
          w.photoPath!.isNotEmpty &&
          File(w.photoPath!).existsSync()) {
        precacheImage(FileImage(File(w.photoPath!)), context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Defer provider mutation: when this page is mounted via
    // pushAndRemoveUntil from ResultGamePage, initState runs DURING the
    // ancestor's build, and Riverpod forbids modifying state mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(allowGameFlowPopProvider.notifier).set(false);
      }
    });
    _player = AudioPlayer();
    _player.setPlayerMode(PlayerMode.lowLatency);

    // If preloaded words provided (e.g. error words), use them directly
    // Otherwise load from category DB (normal course flow)
    if (widget.preloadedWords != null) {
      filteredWordsProvider = FutureProvider<List<Word>>((ref) async {
        return widget.preloadedWords!;
      });
    } else {
      filteredWordsProvider = FutureProvider<List<Word>>((ref) async {
        final categoryIdNullable = ref.watch(selectedCategoryProvider);
        if (categoryIdNullable == null) return [];
        final categoryId = categoryIdNullable;
        final selectedSubId = ref.watch(selectedSubcategoryProvider);
        final subcategories = await ref.watch(
          subcategoriesProvider(categoryId).future,
        );

        // Use ref.read (not watch!) so swipes don't cause the entire list to rebuild
        final currentLearning = ref.read(learningWordsProvider);
        final learningIds = currentLearning.map((w) => w.id).toSet();

        // Use ref.read for progress too — we only need the snapshot, not reactivity
        final progress = ref.read(progressProvider);
        int learnedInCategory = 0;
        // Build set of word IDs that are fully learned on the server
        final learnedWordIds = <int>{};
        for (final entry in progress.dirs.values) {
          for (final wp in entry) {
            if (wp.categoryId == categoryId && wp.state > 0 && !wp.firstDone) {
              learnedInCategory++;
              learnedWordIds.add(wp.wordId);
            }
          }
        }

        // Get category level info
        final categories = await CategoriesRepository().getCategories();
        final catDto = categories.where((c) => c.id == categoryId).firstOrNull;
        final info = catDto?.parsedInfo;
        final lvl1 = info?.countWordsLevels[1] ?? 0;
        final lvl2 = info?.countWordsLevels[2] ?? 0;

        // Determine effective level: start from user's global level,
        // only auto-bump UP when a level's words are fully learned
        final userLevel = await SelectedLevelNotifier.getSavedLevelValue() ?? 1;
        int effectiveLevel = userLevel;
        // Use a small tolerance (1-2 words) to avoid getting stuck on stray
        // uncompleted words from other subcategories when using "Все" mode.
        const bumpTolerance = 2;
        if (lvl1 > 0 &&
            learnedInCategory >= lvl1 - bumpTolerance &&
            effectiveLevel < 2) {
          effectiveLevel = 2;
        }
        if (lvl1 > 0 &&
            lvl2 > 0 &&
            learnedInCategory >= lvl1 + lvl2 - bumpTolerance &&
            effectiveLevel < 3) {
          effectiveLevel = 3;
        }

        final activeLevel = effectiveLevel;

        // Load ALL words (in order from all lessons) to assign levels
        List<Word> allWords = [];
        // Always load from all subcategories to establish correct order
        for (int i = 0; i < subcategories.length; i++) {
          final words = await ref.read(
            wordsProvider((categoryId: categoryId, lessonIndex: i)).future,
          );
          allWords.addAll(words);
        }

        // Assign virtual levels based on word position and API count_words_levels.
        // API says: first lvl1 words → level 1, next lvl2 → level 2, rest → level 3.
        // If a word already has level from JSON (level != 0), respect that.
        // Only assign position-based level for words with level=0 (no level in JSON).
        final lvl3 = info?.countWordsLevels[3] ?? 0;
        final assignedLevel = <int, int>{}; // wordId → assigned level
        for (int idx = 0; idx < allWords.length; idx++) {
          final w = allWords[idx];
          // If word already has level from JSON, use it
          if (w.level > 0) {
            assignedLevel[w.id] = w.level;
            continue;
          }
          // Otherwise, assign based on position
          int level;
          if (lvl1 > 0 && idx < lvl1) {
            level = 1;
          } else if (lvl2 > 0 && idx < lvl1 + lvl2) {
            level = 2;
          } else if (lvl3 > 0) {
            level = 3;
          } else {
            // All words in one level or no level data — assign to first non-zero level
            if (lvl1 > 0)
              level = 1;
            else if (lvl2 > 0)
              level = 2;
            else
              level = 1; // fallback
          }
          assignedLevel[w.id] = level;
        }

        debugPrint(
          '🔍 [cat=$categoryId] Assigned levels: '
          'lvl1=${assignedLevel.values.where((l) => l == 1).length}, '
          'lvl2=${assignedLevel.values.where((l) => l == 2).length}, '
          'lvl3=${assignedLevel.values.where((l) => l == 3).length}',
        );

        // If a specific subcategory was selected, filter to only those words
        List<Word> wordsToFilter;
        if (selectedSubId != null) {
          final lessonIndex = selectedSubId - 1;
          final lessonWords = await ref.read(
            wordsProvider((
              categoryId: categoryId,
              lessonIndex: lessonIndex,
            )).future,
          );
          wordsToFilter = lessonWords;
        } else {
          wordsToFilter = allWords;
        }

        // Filter words:
        // 1. Exclude words marked 'known' by user (swipe left = already knows it)
        // 2. Exclude words fully completed on server (learnedWordIds)
        //    NOTE: Do NOT use status=='learning' — local status marks EVERY swiped word,
        //    blocking everything. Server progress tracks actually completed words.
        // 3. Exclude words currently in the active learning session
        // 4. Level filter: show words matching current effective level
        // 5. Auto-bump: if current level has 0 remaining words, try next level
        List<Word> filtered = [];
        int usedLevel = activeLevel;

        // When bumped to level 2+, include lower-level leftovers (<=) so
        // stray unlearned words from previous levels don't get skipped.
        for (int tryLevel = activeLevel; tryLevel <= 3; tryLevel++) {
          filtered = wordsToFilter
              .where(
                (w) =>
                    w.categoryId > 0 &&
                    w.status != 'known' &&
                    !learnedWordIds.contains(w.id) &&
                    !learningIds.contains(w.id) &&
                    (assignedLevel[w.id] ?? 1) <= tryLevel,
              )
              .toList();
          usedLevel = tryLevel;
          if (filtered.isNotEmpty) break;
          debugPrint(
            '🔄 [cat=$categoryId] Level $tryLevel has 0 remaining words, trying level ${tryLevel + 1}',
          );
        }

        // Diagnostic dump — surfaces exactly why the empty state fires
        // when users report a "200/481 yet 'all learned'" mismatch.
        // Lists the four exclusion buckets so it's clear which one is
        // pruning the un-touched words that should still be visible.
        if (filtered.isEmpty) {
          int badCategoryId = 0;
          int markedKnown = 0;
          int alreadyLearned = 0;
          int currentlyLearning = 0;
          int passedAllExceptLevel = 0;
          for (final w in wordsToFilter) {
            if (w.categoryId <= 0) {
              badCategoryId++;
              continue;
            }
            if (w.status == 'known') {
              markedKnown++;
              continue;
            }
            if (learnedWordIds.contains(w.id)) {
              alreadyLearned++;
              continue;
            }
            if (learningIds.contains(w.id)) {
              currentlyLearning++;
              continue;
            }
            passedAllExceptLevel++;
          }
          debugPrint(
            '🔎 [cat=$categoryId] filtered.isEmpty diagnostic:\n'
            '  total wordsToFilter = ${wordsToFilter.length}\n'
            '  excluded by categoryId<=0: $badCategoryId\n'
            '  excluded by status==known: $markedKnown\n'
            '  excluded by learnedWordIds: $alreadyLearned (size=${learnedWordIds.length})\n'
            '  excluded by learningIds: $currentlyLearning (size=${learningIds.length})\n'
            '  passed all but level filter: $passedAllExceptLevel\n'
            '  active level=$activeLevel, used=$usedLevel',
          );
        }

        // Fallback: if all levels empty, show remaining words without level filter
        if (filtered.isEmpty) {
          filtered = wordsToFilter
              .where(
                (w) =>
                    w.categoryId > 0 &&
                    w.status != 'known' &&
                    !learnedWordIds.contains(w.id) &&
                    !learningIds.contains(w.id),
              )
              .toList();
          if (filtered.isNotEmpty) {
            debugPrint(
              '🔄 [cat=$categoryId] All levels empty, fallback without level filter: ${filtered.length} words',
            );
          }
        }

        // End-of-unit top-up: ONLY when there are 1–3 unlearned words left
        // in the lesson — just enough to pad a batch of 4 with review words.
        // If filtered is empty (every word learned), we do NOT mix in review
        // — otherwise the user would cycle the same learned words forever.
        // The empty-filtered case falls through to the existing "all words
        // learned" completion screen with its achievement animation.
        const kGameBatchSize = 4;
        if (filtered.isNotEmpty && filtered.length < kGameBatchSize) {
          final existingIds = filtered.map((w) => w.id).toSet();
          final reviewPool = wordsToFilter
              .where(
                (w) =>
                    w.categoryId > 0 &&
                    !existingIds.contains(w.id) &&
                    !learningIds.contains(w.id) &&
                    (learnedWordIds.contains(w.id) || w.status == 'known'),
              )
              .toList()
            ..shuffle();
          final extras =
              reviewPool.take(kGameBatchSize - filtered.length).toList();
          if (extras.isNotEmpty) {
            debugPrint(
              '🔁 [cat=$categoryId] Short by ${kGameBatchSize - filtered.length} '
              '— adding ${extras.length} review word(s) to reach batch of 4',
            );
            filtered = [...filtered, ...extras];
          }
        }

        if (selectedSubId == null) {
          filtered.shuffle();
        }

        // Калимаҳои "барои бозомӯзӣ" (state ∈ [-3..0], timeout гузашта)
        // ба пеши рӯйхат гузошта мешаванд — то корбар онҳоро аввал
        // тавассути flashcards аз нав омӯзад. То 10 калима, то ки сессия
        // аз калимаҳои фрешу нав маҳрум нашавад.
        final relearnWordIds = <int>{};
        for (final dirWords in progress.dirs.values) {
          for (final wp in dirWords) {
            if (wp.categoryId == categoryId &&
                WordRepetitionService.isWordWithRelearn(wp)) {
              relearnWordIds.add(wp.wordId);
            }
          }
        }
        if (relearnWordIds.isNotEmpty) {
          final relearn = filtered
              .where((w) => relearnWordIds.contains(w.id))
              .take(10)
              .toList();
          if (relearn.isNotEmpty) {
            final relearnIdsTaken = relearn.map((w) => w.id).toSet();
            final rest = filtered
                .where((w) => !relearnIdsTaken.contains(w.id))
                .toList();
            filtered = [...relearn, ...rest];
            debugPrint(
              '🔁 [cat=$categoryId] Prepended ${relearn.length} relearn '
              'word(s) to learn session',
            );
          }
        }

        // Count known words for debugging
        final knownCount = wordsToFilter.where((w) => w.status == 'known').length;
        final learnedCount = wordsToFilter.where((w) => learnedWordIds.contains(w.id)).length;
        final learningCount = wordsToFilter.where((w) => learningIds.contains(w.id)).length;
        final zeroCatCount = wordsToFilter.where((w) => w.categoryId <= 0).length;

        debugPrint(
          '🎯 filteredWordsProvider: effectiveLevel=$effectiveLevel, usedLevel=$usedLevel, '
          'learnedInCategory=$learnedInCategory, learnedWordIds=${learnedWordIds.length}, '
          'allWords=${allWords.length}, wordsToFilter=${wordsToFilter.length}, '
          'known=$knownCount, learned=$learnedCount, learning=$learningCount, zeroCat=$zeroCatCount, '
          'subcategories=${subcategories.length}, selectedSubId=$selectedSubId, '
          'lvl1=$lvl1, lvl2=$lvl2, '
          'total=${filtered.length} words',
        );
        return filtered;
      });
    }

    Future.microtask(() async {
      final categoryId = widget.categoryId;

      // Тоза кардани state-ҳои пештара барои сессияи нав
      ref.read(learningWordsProvider.notifier).set([]);
      ref.read(learningPressCountProvider.notifier).set(0);
      ref.read(currentWordIndexProvider.notifier).set(0);

      // Always set category to the current page's categoryId
      ref.read(selectedCategoryProvider.notifier).set(categoryId);
      // If lessonIndex was passed from CourseLessonPage, set it as filter
      // Otherwise reset to null (show all words from the category)
      if (widget.lessonIndex != null) {
        ref.read(selectedSubcategoryProvider.notifier).set(widget.lessonIndex! + 1);
      } else {
        ref.read(selectedSubcategoryProvider.notifier).set(null);
      }

      // Set audio context so AudioHelper can find audio files from the course
      final coursePath = await CategoryResourceService.getCoursePath(
        categoryId,
      );
      if (coursePath != null) {
        AudioContext.currentLessonDir = coursePath;
        debugPrint('🔊 AudioContext.currentLessonDir = $coursePath');
      } else {
        debugPrint(
          '⚠️ Курс не найден для категории $categoryId — аудио может не работать',
        );
      }
    });
  }

  /// Воспроизводит аудио слова из скачанного курса (.ogg на диске).
  Future<void> _playWordAudio(Word word) async {
    if (word.audioPath != null && word.audioPath!.isNotEmpty) {
      final audioFile = File(word.audioPath!);
      if (audioFile.existsSync()) {
        try {
          await _player.stop();
          await _player.play(DeviceFileSource(audioFile.path));
          return;
        } catch (e) {
          debugPrint('⚠️ Ошибка воспроизведения аудио: $e');
        }
      } else {
        debugPrint('⚠️ Аудио файл не найден: ${word.audioPath}');
      }
    }
    // Fallback to old AudioHelper
    await _player.stop();
    await AudioHelper.playWord(
      _player,
      '',
      '${word.word}.mp3',
      categoryId: word.categoryId,
    );
  }

  @override
  void dispose() {
    ZipResourceLoader.clear(); // выгружаем архивы из RAM
    _player.dispose(); // если используете AudioPlayer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesFlutterProvider);
    final subcategoriesAsync = ref.watch(
      subcategoriesProvider(widget.categoryId),
    );
    return WillPopScope(
      onWillPop: () async {
        if (ref.read(allowGameFlowPopProvider)) return true;
        showExitConfirmationDialog(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (widget.preloadedWords != null || widget.lessonIndex != null) {
                // Course lesson or error/learned words flow → back to previous screen
                Navigator.pop(context);
              } else {
                // Regular category flow → pop only the imperative
                // routes stacked on top of the GoRouter /home page
                // (the predicate `r.settings is Page` stops popping at
                // the first Page-based route, so GoRouter's matchList
                // never empties), then ask GoRouter to assert /home as
                // the current location.
                //
                // popUntil(isFirst) used to trip go_router 14+'s
                // `currentConfiguration.isNotEmpty` assertion; plain
                // `context.go('/home')` left imperative pages on the
                // stack so stale ResultGamePages would still appear.
                Navigator.of(context).popUntil(
                  (route) => route.settings is Page,
                );
                if (context.mounted) {
                  context.go('/home');
                }
                ref.read(bottomNavProvider.notifier).setIndex(0);
              }
            },
            icon: Icon(Icons.close, color: Colors.black, size: 30),
          ),
          backgroundColor: const Color(0xFFF8FAFF),
          elevation: 0,
          centerTitle: true,
          title: categoriesAsync.when(
            data: (categories) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        "selected".tr(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        " ${ref.watch(learningPressCountProvider)} ",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "of ".tr(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "4",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 50),
                ],
              );
            },
            loading: () => const Text(''),
            error: (_, __) =>
                Text('Error'.tr(), style: TextStyle(color: Colors.red)),
          ),
        ),
        body: subcategoriesAsync.when(
          data: (subCategories) {
            final allOption = Subcategory(
              id: -1,
              name: 'all'.tr(),
              categoryId: 0,
            );
            final allSubCategories = [allOption, ...subCategories];
            final selectedSubId = ref.watch(selectedSubcategoryProvider);
            final wordsAsync = ref.watch(filteredWordsProvider);

            return Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hide categories header and subcategory chips when coming from error words or specific lesson
                  if (widget.preloadedWords == null && widget.lessonIndex == null) ...[
                    Text(
                      "Categories".tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: allSubCategories.length,
                              itemBuilder: (ctx, i) {
                                final sub = allSubCategories[i];
                                final isSel = sub.id == (selectedSubId ?? -1);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: GestureDetector(
                                    onTap: () async {
                                      ref
                                          .read(
                                            currentWordIndexProvider.notifier,
                                          )
                                          .set(0);
                                      if (sub.id == -1) {
                                        ref
                                            .read(
                                              selectedSubcategoryProvider
                                                  .notifier,
                                            )
                                            .set(null); // "Все"
                                      } else {
                                        // Check if lesson has tests/workbook → go to CourseLessonPage
                                        final lessonIndex =
                                            sub.id - 1; // 0-based
                                        debugPrint(
                                          '🔍 [ChipTap] categoryId=${widget.categoryId}, lessonIndex=$lessonIndex, subId=${sub.id}, subName=${sub.name}',
                                        );
                                        final meta =
                                            await CategoryDbHelper.getLessonMeta(
                                              widget.categoryId,
                                              lessonIndex,
                                            );
                                        debugPrint(
                                          '🔍 [ChipTap] meta: hasTests=${meta.hasTests}, hasWorkbook=${meta.hasWorkbook}, hasLearningWords=${meta.hasLearningWords}, testCount=${meta.testCount}',
                                        );
                                        if (meta.hasTests || meta.hasWorkbook) {
                                          if (context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CourseLessonPage(
                                                      categoryId:
                                                          widget.categoryId,
                                                      lessonIndex: lessonIndex,
                                                      lessonTitle: sub.name,
                                                    ),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        ref
                                            .read(
                                              selectedSubcategoryProvider
                                                  .notifier,
                                            )
                                            .set(sub.id);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? const Color(0xFF2E90FA)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Center(
                                        child: Text(
                                          sub.name,
                                          style: TextStyle(
                                            color: isSel
                                                ? Colors.white
                                                : Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 25),
                  ],
                  Expanded(
                    child: wordsAsync.when(
                      data: (filtered) {
                        // When preloadedWords is provided (e.g. error words),
                        // don't filter by status — those words already have
                        // 'known'/'learning' status from previous learning.
                        // filteredWordsProvider already handles all filtering
                        // (status, learned IDs, level). No need to re-filter here.
                        final filteredWords = filtered;
                        // Store for pre-caching access
                        _currentWords = filteredWords;
                        // Pre-cache images for first 5 cards
                        _precacheUpcoming(0);
                        if (filteredWords.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events_rounded,
                                      size: 52,
                                      color: Color(0xFF12B76A),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'all_words_learned_title'.tr(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D2939),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'all_words_learned_description'.tr(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF667085),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // Course flow (4000 essential
                                        // words etc) → just go back to
                                        // the unit list the user came
                                        // from. Sending them to /home
                                        // would feel like the app
                                        // bounced them out of the
                                        // course entirely.
                                        if (widget.preloadedWords != null ||
                                            widget.lessonIndex != null) {
                                          Navigator.pop(context);
                                          return;
                                        }
                                        // Regular category flow → pop
                                        // only the imperative routes
                                        // (predicate stops at first
                                        // Page-based GoRouter page) and
                                        // then assert /home via
                                        // GoRouter. See result_game_page
                                        // for the full reasoning behind
                                        // this two-step.
                                        Navigator.of(context).popUntil(
                                          (route) => route.settings is Page,
                                        );
                                        if (context.mounted) {
                                          context.go('/home');
                                        }
                                        ref
                                            .read(bottomNavProvider.notifier)
                                            .setIndex(0);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E90FA),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'go_home'.tr(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SwipeCardStack<Word>(
                          items: filteredWords,
                          onAudioTap: (word) => _playWordAudio(word),
                          cardBuilder: (context, word, index) {
                            return WordCard(
                              word: word,
                            );
                          },
                          onCardAppeared: (word) {
                            if (_suppressCardAudio) return;
                            _playWordAudio(word);
                            // Pre-cache next 5 from this card's position
                            final idx = _currentWords.indexOf(word);
                            if (idx >= 0) _precacheUpcoming(idx + 1);
                          },
                          onSwiped: (direction, word) async {
                            HapticFeedback.lightImpact();
                            // In viewOnly mode, just browse cards (Unity's UIViewWordsCard)
                            if (widget.viewOnly) return;

                            if (direction < 0) {
                              // ← LEFT = "Медонам" (already know)
                              await DatabaseHelper.markWordStatus(
                                word.id,
                                'known',
                              );
                            } else {
                              // → RIGHT = "Омӯзиш" (learn)
                              await DatabaseHelper.markWordStatus(
                                word.id,
                                'learning',
                              );
                              final currentList = ref.read(
                                learningWordsProvider,
                              );
                              if (!currentList.any((w) => w.id == word.id)) {
                                final updated = [...currentList, word];
                                ref
                                    .read(learningWordsProvider.notifier)
                                    .set(
                                      updated.length > 4
                                          ? updated.sublist(updated.length - 4)
                                          : updated,
                                    );
                              }
                              final count = ref.read(
                                learningPressCountProvider.notifier,
                              );
                              count.increment();
                              if (count.state >= 4) {
                                // Suppress the next onCardAppeared playback —
                                // the 5th card surfaces behind the swipe but
                                // we're leaving for TrenirovkaPage immediately.
                                _suppressCardAudio = true;
                                await _player.stop();
                                count.set(0);

                                // Загружаем пул дамми-слов для текущей категории/урока
                                final selectedSubId = ref.read(
                                  selectedSubcategoryProvider,
                                );
                                final lessonIdx = (selectedSubId != null)
                                    ? selectedSubId - 1
                                    : 0;
                                ref
                                    .read(dummyWordPoolProvider.notifier)
                                    .loadPool(
                                      categoryId: widget.categoryId,
                                      lessonIndex: lessonIdx,
                                    );

                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TrenirovkaPage(),
                                    ),
                                  ).whenComplete(() {
                                    if (mounted) _suppressCardAudio = false;
                                  });
                                }
                              }
                            }
                          },
                          onUndo: (word, direction) async {
                            HapticFeedback.lightImpact();
                            if (widget.viewOnly) return;

                            // Reset the word status back to null/unset
                            await DatabaseHelper.markWordStatus(
                              word.id,
                              'none',
                            );
                            // If it was a "learn" swipe, decrement counter & remove from list
                            if (direction > 0) {
                              final count = ref.read(
                                learningPressCountProvider.notifier,
                              );
                              if (count.state > 0) {
                                count.set(count.state - 1);
                              }
                              final currentList = ref.read(
                                learningWordsProvider,
                              );
                              final updated = currentList
                                  .where((w) => w.id != word.id)
                                  .toList();
                              ref
                                  .read(learningWordsProvider.notifier)
                                  .set(updated);
                            }
                          },
                        );
                      },
                      loading: () => Center(
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            width: double.infinity,
                            height: 400,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      error: (e, _) => Center(child: Text('Ошибка: $e')),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Row(
                    children: List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          width: 60,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: double.infinity,
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          error: (e, _) => Center(child: Text('Ошибка загрузки категорий: $e')),
        ),
      ),
    );
  }
}
