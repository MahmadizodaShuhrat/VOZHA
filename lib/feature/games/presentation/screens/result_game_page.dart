import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/screens/navigation_bar.dart' show bottomNavProvider;
import 'package:vozhaomuz/feature/games/presentation/screens/choose_learn_know_page.dart'
    show ChoseLearnKnowPage, subcategoriesProvider, wordsProvider;
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/close_page.dart';
import 'package:vozhaomuz/feature/games/data/providers/remember_new_words_provider.dart';
import 'package:vozhaomuz/feature/games/data/models/remember_word_dto.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';
import 'package:vozhaomuz/core/services/word_repetition_service.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import 'package:vozhaomuz/feature/games/data/models/user_words_with_upload.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/learning_session_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/core/services/words_sync_service.dart';
import 'package:vozhaomuz/core/services/review_service.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/result_speech_game_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/achievements_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/learning_streak_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/user_activity_provider.dart';
import 'package:vozhaomuz/core/services/streak_service.dart';
import 'package:vozhaomuz/core/services/notification_service.dart';
import 'package:vozhaomuz/shared/widgets/premium_bonus_dialog.dart';
import 'package:vozhaomuz/shared/widgets/streak_popup.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';

final showFullResultsProvider = NotifierProvider<ShowFullResultsNotifier, bool>(
  ShowFullResultsNotifier.new,
);

class ShowFullResultsNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class ResultGamePage extends ConsumerStatefulWidget {
  final int categoryId;
  final List<int> learnedWordIds;
  final int? lessonIndex;
  final String? lessonTitle;

  const ResultGamePage({
    super.key,
    required this.categoryId,
    required this.learnedWordIds,
    this.lessonIndex,
    this.lessonTitle,
  });

  @override
  ConsumerState<ResultGamePage> createState() => _ResultGamePageState();
}

class _ResultGamePageState extends ConsumerState<ResultGamePage> {
  Future<RememberNewWordsResponse>? _apiCall;
  bool _apiCalled = false;
  bool _wasRepeatMode = false;
  /// PopScope's `canPop` reads this so programmatic `popUntil` /
  /// `pushAndRemoveUntil` from Exit / Learn more aren't mistaken for a
  /// back-gesture and shown the exit-confirmation dialog.
  bool _intentionalExit = false;
  final playerr = AudioPlayer();

  @override
  void dispose() {
    playerr.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Read synchronously: reading in postFrame would let the first
    // build() flash the "+N coins" box before `false` propagates.
    _wasRepeatMode = ref.read(isRepeatModeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _callApiOnce();
      ReviewService.instance.trackAndRequestReview();
    });
  }

  void _callApiOnce() {
    if (_apiCalled) return;
    _apiCalled = true;

    final wasRepeatMode = _wasRepeatMode;
    ref.read(isRepeatModeProvider.notifier).set(false);

    final notifier = ref.read(gameResultProvider.notifier);
    final correctWordIds = notifier.getCorrectWordIds().toList();
    final wrongWordIds = notifier.getWrongWordIds().toList();
    final errorInGames = notifier.buildErrorInGames();

    final repo = ref.read(rememberNewWordsRepositoryProvider);

    if (wasRepeatMode) {
      _sendRepeatResults(repo, correctWordIds, wrongWordIds, errorInGames);
    } else {
      _sendLearnResults(repo, correctWordIds, wrongWordIds, errorInGames);
    }

    _sendSessionActivity(
      repo: repo,
      correctWordIds: correctWordIds,
      wrongWordIds: wrongWordIds,
      wasRepeatMode: wasRepeatMode,
    );

    ref.read(energyProvider.notifier).consume(
          mistakes: wrongWordIds.length,
          completed: true,
        );
  }

  /// Fold sync-user-progress-words rewards into local coin balance.
  /// Server has already credited `count` + `streakCoins` +
  /// `newAchievements.coinsEarned` to `user.money`; we patch locally to
  /// avoid a `/get-profile` round-trip for a single number.
  void _applySyncRewards(dynamic response) {
    try {
      // Repeat must not credit coins (spaced-repetition is its own
      // reward). Achievements still process — earning a trophy during
      // repeat is legitimate.
      if (_wasRepeatMode) {
        final ach = (response?.newAchievements as List?) ?? const [];
        if (ach.isEmpty) return;
      }
      final wordCoins =
          _wasRepeatMode ? 0 : ((response?.count as int?) ?? 0);
      final streakCoins =
          _wasRepeatMode ? 0 : ((response?.streakCoins as int?) ?? 0);
      final newAchievements =
          (response?.newAchievements as List?) ?? const [];
      final achievementCoins = newAchievements.fold<int>(
        0,
        (sum, a) => sum + ((a?.coinsEarned as int?) ?? 0),
      );
      final total = wordCoins + streakCoins + achievementCoins;
      if (total <= 0 && newAchievements.isEmpty) return;

      final profile = ref.read(getProfileInfoProvider).value;
      if (profile != null && total > 0) {
        final current = profile.money ?? 0;
        ref
            .read(getProfileInfoProvider.notifier)
            .syncMoneyFromServer(current + total);
      }
    } catch (_) {}
  }

  /// Re-arms inactivity (10-day "come back") + active-streak (tomorrow
  /// morning) notifications. Streak is read from `/user/activity`
  /// because `profile-rating.days_active` can lag behind.
  Future<void> _refreshActivityPushes() async {
    try {
      await NotificationService.instance.refreshInactivityReminders();
      final now = DateTime.now();
      final activity = await ref.read(
        userActivityProvider((year: now.year, month: now.month)).future,
      );
      final streak = activity?.currentStreak ?? 0;
      await NotificationService.instance.scheduleActiveStreakPush(streak);
    } catch (_) {}
  }

  /// Show the Duolingo-style streak celebration once per local day. The
  /// SharedPreferences date stamp ties the popup to the "streak +1"
  /// moment because the backend only increments on the first session of
  /// a new day.
  Future<void> _maybeShowStreakPopup() async {
    if (!mounted) return;
    if (!StreakService.shouldShowToday()) return;
    final now = DateTime.now();
    // `/user/activity.currentStreak` — `profile-rating.days_active` can
    // be missing on some backend variants and silently yields 0.
    final activityKey = (year: now.year, month: now.month);
    // ИНТИЗОР МЕШАВЕМ маълумоти ТОЗА — invalidate-и қаблӣ providerро ба
    // loading мегузаронад, лекин `.asData?.value` метавонад қимати кӯҳнаро
    // нигоҳ дорад (streak=1 дирӯз). `await .future`-ро мустақим истифода
    // мебарем то аз рӯи маълумоти imrūz нишон диҳем.
    UserActivity? activity;
    try {
      activity = await ref
          .read(userActivityProvider(activityKey).future)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (!mounted) return;
    int streak = activity?.currentStreak ?? 0;
    // We're here only after a successful sync, so the user definitely
    // played today. If backend still returns 0 (race with sendActivity,
    // stale aggregate), fall back to 1 — backend reconciles next fetch.
    if (streak <= 0) streak = 1;
    final activeDates = activity?.activeDates ?? const <DateTime>{};
    try {
      await StreakPopup.show(context, streak, activeDates: activeDates);
      // Mark AFTER show: if it throws, we stay "not yet celebrated"
      // instead of swallowing the whole day's celebration.
      await StreakService.markShownToday();
    } catch (_) {}
  }

  /// POST /api/v1/users/activity
  void _sendSessionActivity({
    required IRememberNewWordsRepository repo,
    required List<int> correctWordIds,
    required List<int> wrongWordIds,
    required bool wasRepeatMode,
  }) {
    final endTime = DateTime.now();
    final startTime =
        ref.read(learningSessionProvider.notifier).endSession() ?? endTime;

    repo
        .sendActivity(
      startTime: startTime,
      endTime: endTime,
      learned: wasRepeatMode ? [] : correctWordIds,
      errors: wrongWordIds,
      repeated: wasRepeatMode ? correctWordIds : [],
    )
        .then((bonus) async {
      // TZ §1: when activity crosses a streak milestone the response
      // ships a `premium_bonus` block. Show the dialog and refresh the
      // profile so `userType`/`tariff_expired_at` reflect the new
      // bonus subscription.
      if (!mounted || bonus == null) return;
      await showPremiumBonusDialog(context, bonus: bonus);
      if (!mounted) return;
      await ref.read(getProfileInfoProvider.notifier).getProfile();
    });
  }

  /// Optimistic local progress + `syncProgress` + post-sync invalidate
  /// pipeline. Shared by learn and repeat paths.
  void _applyOptimisticAndSync(
    IRememberNewWordsRepository repo,
    String langKey,
    List<UserWordsWithUpload> wordsToUpload,
  ) {
    final progress = ref.read(progressProvider);
    if (!progress.dirs.containsKey(langKey)) {
      progress.dirs[langKey] = [];
    }
    final allWordsMutable = progress.dirs[langKey]!;
    for (final upload in wordsToUpload) {
      final wp = allWordsMutable.where((w) => w.wordId == upload.wordId).firstOrNull;
      if (wp != null) {
        wp.state = upload.currentLearningState;
        wp.timeout = DateTime.parse(upload.timeout).toUtc();
        wp.errorInGames = upload.errorInGames;
      } else {
        allWordsMutable.add(WordProgress(
          categoryId: upload.categoryId,
          wordId: upload.wordId,
          state: upload.currentLearningState,
          timeout: DateTime.parse(upload.timeout).toUtc(),
          firstDone: false,
          errorInGames: upload.errorInGames,
          original: upload.wordOriginal,
          translate: upload.wordTranslate,
        ));
      }
    }
    ref.read(progressProvider.notifier).updateDirs(progress.dirs);
    ref.read(progressProvider.notifier).markPendingProgressSync(
          langKey: langKey,
          words: wordsToUpload,
        );

    setState(() {
      final future = repo.syncProgress(words: wordsToUpload);
      _apiCall = future;
      future.then((response) async {
        _applySyncRewards(response);
        // TZ §1: same `premium_bonus` block can be returned by the
        // sync endpoint when this batch tipped the streak past a
        // milestone. Show the dialog before the streak popup so the
        // user sees the high-value reward first.
        if (mounted && response.premiumBonus != null) {
          await showPremiumBonusDialog(context, bonus: response.premiumBonus!);
          if (!mounted) return;
          await ref.read(getProfileInfoProvider.notifier).getProfile();
        }
        // 800ms lets the backend persist before we refetch, while still
        // feeling immediate to the user.
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          ref.read(progressProvider.notifier).fetchProgressFromBackend();
          ref.invalidate(achievementsProvider);
          ref.invalidate(profileRatingProvider);
          ref.invalidate(userActivityProvider);
          ref.invalidate(learningStreakProvider);
          await _maybeShowStreakPopup();
          await _refreshActivityPushes();
        });
      }).catchError((_) {
        // On sync failure skip the streak popup — celebrating a streak
        // that never reached the server would flip the local "shown
        // today" stamp and silently swallow tomorrow's popup too.
      });
    });
  }

  /// Repeat-mode upload: state computed via WordRepetitionService
  /// (mirrors Unity UIResults.cs).
  void _sendRepeatResults(
    IRememberNewWordsRepository repo,
    List<int> correctWordIds,
    List<int> wrongWordIds,
    Map<int, List<String>> errorInGames,
  ) {
    final progress = ref.read(progressProvider);
    final langKey = StorageService.instance.getTableWords();
    final allWords = progress.dirs[langKey] ?? [];
    final now = DateTime.now();

    // Original states cached at session start, not live progress —
    // fetchProgressFromBackend may have rewritten live during session.
    final originalStates = ref.read(repeatOriginalStatesProvider);

    final gameResults = ref.read(gameResultProvider);
    final textMap = <int, WordResult>{};
    for (final r in gameResults) {
      textMap[r.wordId] = r;
    }

    final List<UserWordsWithUpload> wordsToUpload = [];
    // Words that crossed state 4 this session — feed into the home
    // counter optimistically so "Омӯхташуда" bumps up before the
    // 800 ms backend refetch lands.
    int newlyLearnedCount = 0;
    const int learnedThreshold = 4;

    for (final wordId in correctWordIds) {
      final wp = allWords.where((w) => w.wordId == wordId).firstOrNull;
      final currentState = originalStates[wordId] ?? wp?.state ?? 0;
      final isFirstDone = wp?.firstDone ?? false;
      final wr = textMap[wordId];

      final newState = WordRepetitionService.computeNewState(
        currentState: currentState,
        isCorrect: true,
        isFirstDone: isFirstDone,
      );
      final timeout = WordRepetitionService.computeTimeout(
        newState: newState,
        isCorrect: true,
      );

      if (currentState < learnedThreshold && newState >= learnedThreshold) {
        newlyLearnedCount++;
      }

      wordsToUpload.add(
        UserWordsWithUpload(
          categoryId: wp?.categoryId ?? widget.categoryId,
          wordId: wordId,
          currentLearningState: newState,
          isFirstSubmitIsLearning: false,
          learningLanguage: langKey,
          timeout: timeout.toIso8601String(),
          errorInGames: errorInGames[wordId] ?? [],
          writeTime: now.toIso8601String(),
          wordOriginal: wr?.word ?? wp?.original ?? '',
          wordTranslate: wr?.translation ?? wp?.translate ?? '',
        ),
      );
    }

    if (newlyLearnedCount > 0) {
      ref
          .read(profileRatingProvider.notifier)
          .optimisticIncrementLearnedWords(newlyLearnedCount);
    }

    for (final wordId in wrongWordIds) {
      final wp = allWords.where((w) => w.wordId == wordId).firstOrNull;
      final currentState = originalStates[wordId] ?? wp?.state ?? 0;
      final wr = textMap[wordId];

      final newState = WordRepetitionService.computeNewState(
        currentState: currentState,
        isCorrect: false,
      );
      final timeout = WordRepetitionService.computeTimeout(
        newState: newState,
        isCorrect: false,
      );

      wordsToUpload.add(
        UserWordsWithUpload(
          categoryId: wp?.categoryId ?? widget.categoryId,
          wordId: wordId,
          currentLearningState: newState,
          isFirstSubmitIsLearning: false,
          learningLanguage: langKey,
          timeout: timeout.toIso8601String(),
          errorInGames: errorInGames[wordId] ?? [],
          writeTime: now.toIso8601String(),
          wordOriginal: wr?.word ?? wp?.original ?? '',
          wordTranslate: wr?.translation ?? wp?.translate ?? '',
        ),
      );
    }

    _applyOptimisticAndSync(repo, langKey, wordsToUpload);
  }

  /// Learn-mode upload: correct → state=1, +2d; wrong → state=-1, +1d.
  void _sendLearnResults(
    IRememberNewWordsRepository repo,
    List<int> correctWordIds,
    List<int> wrongWordIds,
    Map<int, List<String>> errorInGames,
  ) {
    final langKey = StorageService.instance.getTableWords();
    final now = DateTime.now();
    final correctTimeout = now.add(const Duration(days: 2));
    final wrongTimeout = now.add(const Duration(days: 1));

    final results = ref.read(gameResultProvider);
    final textMap = <int, WordResult>{};
    for (final r in results) {
      textMap[r.wordId] = r;
    }

    final List<UserWordsWithUpload> wordsToUpload = [];

    for (final wordId in correctWordIds) {
      final wr = textMap[wordId];
      wordsToUpload.add(
        UserWordsWithUpload(
          categoryId: widget.categoryId,
          wordId: wordId,
          currentLearningState: 1,
          isFirstSubmitIsLearning: false,
          learningLanguage: langKey,
          timeout: correctTimeout.toIso8601String(),
          errorInGames: errorInGames[wordId] ?? [],
          writeTime: now.toIso8601String(),
          wordOriginal: wr?.word ?? '',
          wordTranslate: wr?.translation ?? '',
        ),
      );
    }

    for (final wordId in wrongWordIds) {
      final wr = textMap[wordId];
      wordsToUpload.add(
        UserWordsWithUpload(
          categoryId: widget.categoryId,
          wordId: wordId,
          currentLearningState: -1,
          isFirstSubmitIsLearning: false,
          learningLanguage: langKey,
          timeout: wrongTimeout.toIso8601String(),
          errorInGames: errorInGames[wordId] ?? [],
          writeTime: now.toIso8601String(),
          wordOriginal: wr?.word ?? '',
          wordTranslate: wr?.translation ?? '',
        ),
      );
    }

    _applyOptimisticAndSync(repo, langKey, wordsToUpload);
  }

  /// Exit destinations: course learn → CourseLessonsPage; everything
  /// else (Учить слова, Repeat) → Home.
  ///
  /// Post-frame deferral lets PopScope's `canPop = _intentionalExit`
  /// rebuild settle before popUntil — otherwise the first pop no-ops
  /// against a stale `canPop=false`.
  void _exitFromResult() {
    final goesToCourse =
        widget.lessonIndex != null && !_wasRepeatMode;

    // Reset stage so a re-rendered GamePage doesn't push a fresh
    // ResultGamePage from its `gameStage == result` Builder.
    ref.read(allowGameFlowPopProvider.notifier).set(true);
    ref.read(gameStageProvider.notifier).set(GameStage.flashcards);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final router = GoRouter.of(context);

      if (goesToCourse) {
        navigator.popUntil(
          (route) =>
              route.settings.name == 'CourseLessonsPage' || route.isFirst,
        );
        return;
      }

      // Pop every imperative route. `route.isFirst` always matches the
      // bottom-most route (GoRouter's `/home`), so the matchList never
      // empties — empty matchList renders a blank white screen, which
      // was the bug in repeat-flow Exit. The `Page` check is a belt-and-
      // suspenders fallback for any future intermediate Page route.
      navigator.popUntil(
        (route) => route.isFirst || route.settings is Page,
      );
      ref.read(bottomNavProvider.notifier).setIndex(0);
      router.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final showFullResults = ref.watch(showFullResultsProvider);
    final results = ref.watch(gameResultProvider);

    return PopScope(
      canPop: _intentionalExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _intentionalExit) return;
        showExitConfirmationDialog(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F7FF),
        body: _apiCall == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<RememberNewWordsResponse>(
                future: _apiCall,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Sync failure shouldn't block UI — still render results.
                  if (snapshot.hasError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('sync_failed'.tr()),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    });
                  }

                  final resp =
                      snapshot.data ??
                      RememberNewWordsResponse(count: 0, status: 'ok');
                  return Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: showFullResults
                              ? _buildGameResultsByGameIndex(context)
                              : SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 40),
                                      if (!_wasRepeatMode) ...[
                                        _buildScoreBox(resp.count),
                                        const SizedBox(height: 20),
                                      ] else ...[
                                        ElevatedButton(
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            ref.read(showFullResultsProvider.notifier).set(true);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2F80ED),
                                            shape: const StadiumBorder(),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            child: Text(
                                              "My_workout_results".tr(),
                                              style: const TextStyle(color: Colors.white, fontSize: 14),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                      _buildOverallResults(results),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                        ),
                        Column(
                          children: [
                            if (!_wasRepeatMode) ...[
                              const SizedBox(height: 10),
                              Text(
                                'descrip_result_game'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.start,
                              ),
                              const SizedBox(height: 10),
                              MyButton(
                                backButtonColor: Colors.blue.shade800,
                                buttonColor: Colors.blue.shade500,
                                child: Text(
                                  "Learn_more".tr(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _intentionalExit = true);
                                  ref.read(allowGameFlowPopProvider.notifier).set(true);
                                  ref.read(learningWordsProvider.notifier).set([]);
                                  ref.read(learningPressCountProvider.notifier).set(0);
                                  ref.read(currentWordIndexProvider.notifier).set(0);
                                  ref.read(gameStageProvider.notifier).set(GameStage.flashcards);
                                  ref.read(dotsProvider.notifier).reset();
                                  ref.read(gameResultProvider.notifier).reset();
                                  ref.read(showCorrectnessLabelProvider.notifier).set(null);
                                  ref.read(dummyWordPoolProvider.notifier).set([]);
                                  ref.read(showFullResultsProvider.notifier).set(false);
                                  ref.read(isRepeatModeProvider.notifier).set(false);
                                  ref.read(selectedCategoryProvider.notifier).set(null);
                                  ref.invalidate(subcategoriesProvider(widget.categoryId));
                                  if (widget.lessonIndex != null) {
                                    ref.invalidate(wordsProvider((
                                      categoryId: widget.categoryId,
                                      lessonIndex: widget.lessonIndex!,
                                    )));
                                  }
                                  // pushAndRemoveUntil clears all old game pages
                                  // up to the root so the navigator stack stays bounded.
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChoseLearnKnowPage(
                                        categoryId: widget.categoryId,
                                        lessonIndex: widget.lessonIndex,
                                        lessonTitle: widget.lessonTitle,
                                        clearLearningOnInit: false,
                                      ),
                                    ),
                                    (route) => route.isFirst,
                                  );
                                },
                              ),
                              SizedBox(height: 25),
                            ],
                            MyButton(
                              backButtonColor: Colors.red.shade300,
                              buttonColor: Colors.red.shade400,
                              child: Text(
                                "Exit".tr(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() => _intentionalExit = true);
                                _exitFromResult();
                                // Don't reset gameResultProvider here:
                                // go_router pops async, ResultGamePage
                                // would rebuild with empty results and
                                // flash "+0 coins". Next session resets
                                // them at start anyway.
                              },
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// Overall correct + wrong lists with status dots and next-repeat time.
  Widget _buildOverallResults(List<WordResult> results) {
    final correct = results.where((r) => r.isCorrect).toList();
    final wrong = results.where((r) => !r.isCorrect).toList();

    // Build state lookup from progress for repeat-time display
    final langKey = StorageService.instance.getTableWords();
    final progress = ref.read(progressProvider);
    final allWords = progress.dirs[langKey] ?? [];
    final stateMap = <int, int>{};
    for (final wp in allWords) {
      stateMap[wp.wordId] = wp.state;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (correct.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: 4,
              ),
              child: Text(
                "List_of_correct_words".tr(),
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            for (var word in correct)
              _buildWordItemWithRepeat(word, stateMap[word.wordId] ?? 1, true),
          ],
          if (correct.isNotEmpty && wrong.isNotEmpty)
            const Divider(height: 20, indent: 16, endIndent: 16),
          if (wrong.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 16, right: 16, top: 8, bottom: 4,
              ),
              child: Text(
                "List_of_errors".tr(),
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            for (var word in wrong)
              _buildWordItemWithRepeat(word, stateMap[word.wordId] ?? -1, false),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWordItemWithRepeat(WordResult word, int state, bool isCorrect) {
    String repeatTime = '';
    if (state < 4) {
      final timeout = WordRepetitionService.computeTimeout(
        newState: state,
        isCorrect: isCorrect,
      );
      final diff = timeout.difference(DateTime.now());
      final hours = diff.inHours;
      if (hours >= 24) {
        repeatTime = 'time_days'.tr(args: ['${hours ~/ 24}']);
      } else if (hours > 0) {
        repeatTime = 'time_hours'.tr(args: ['$hours']);
      } else {
        repeatTime = 'time_minutes'.tr(args: ['${diff.inMinutes}']);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel_outlined,
            color: isCorrect ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.displayWord,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  word.translation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (word.pronScore != null)
            _buildPronScoreBadge(word.pronScore!),
          const SizedBox(width: 6),
          _buildStatusDots(state),
          const SizedBox(width: 6),
          if (state >= 4)
            const Icon(Icons.check_circle, color: Color(0xFF20CD7F), size: 18)
          else if (repeatTime.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCorrect
                    ? const Color(0xFF20CD7F).withValues(alpha: 0.12)
                    : const Color(0xFFE6394F).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                repeatTime,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? const Color(0xFF20CD7F) : const Color(0xFFE6394F),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 3 colored dots indicating learning state.
  Widget _buildStatusDots(int state) {
    Color dot1, dot2, dot3;
    const green = Color(0xFF20CD7F);
    const red = Color(0xFFE6394F);
    const grey = Color(0xFFD4DAE5);

    switch (state) {
      case -3:
        dot1 = red; dot2 = red; dot3 = red; break;
      case -2:
        dot1 = red; dot2 = grey; dot3 = red; break;
      case -1:
        dot1 = red; dot2 = grey; dot3 = grey; break;
      case 1:
        dot1 = green; dot2 = grey; dot3 = grey; break;
      case 2:
        dot1 = green; dot2 = grey; dot3 = green; break;
      case 3:
      case 4:
        dot1 = green; dot2 = green; dot3 = green; break;
      default:
        dot1 = grey; dot2 = grey; dot3 = grey; break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(dot1), const SizedBox(width: 3),
        _dot(dot2), const SizedBox(width: 3),
        _dot(dot3),
      ],
    );
  }

  Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _buildGameResultsByGameIndex(BuildContext context) {
    // Group by game NAME with ALL attempts (not aggregated state) so a
    // word that appeared in multiple games shows up under each.
    final notifier = ref.read(gameResultProvider.notifier);
    final allAttempts = notifier.getAllAttempts();

    final groupedByGame = <String, List<WordResult>>{};
    for (var r in allAttempts) {
      final name = r.gameName.isNotEmpty ? r.gameName : 'Game ${r.gameIndex}';
      groupedByGame.putIfAbsent(name, () => []).add(r);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20, top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    ref.read(showFullResultsProvider.notifier).set(false);
                  },
                  child: Icon(Icons.close, size: 33),
                ),
                Center(
                  child: Text(
                    "Results_by_training_modules".tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 10),
              ],
            ),
          ),
          for (var entry in groupedByGame.entries)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildWordCard(entry.key.tr(), entry.value),
                const SizedBox(height: 20),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBox(int score) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 20),
              Text(
                "You_earned_it".tr(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                "+$score ",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Image.asset("assets/images/coin.png", width: 30),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(showFullResultsProvider.notifier).set(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F80ED),
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "My_workout_results".tr(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget buildWordCard(String title, List<WordResult> words) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...words.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                children: [
                  Icon(
                    e.isCorrect ? Icons.check_circle : Icons.cancel_outlined,
                    color: e.isCorrect ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.word,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.translation,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (e.pronScore != null) ...[
                    _buildPronScoreBadge(e.pronScore!),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () {
                      final allWords = ref.read(learningWordsProvider);
                      final wordObj = allWords.cast<Word?>().firstWhere(
                        (w) => w?.word == e.word,
                        orElse: () => null,
                      );
                      AudioHelper.playWord(
                        playerr,
                        '',
                        '${e.word}.mp3',
                        categoryId: wordObj?.categoryId,
                      );
                    },
                    child: Icon(Icons.volume_up, color: Colors.blue, size: 30),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPronScoreBadge(int score) {
    final color = getColorForScore(score);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          '$score',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
