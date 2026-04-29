import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/model_question.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/correct_incorrect_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/flashcard.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/keyboard_game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/match_game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/result_game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/sound_word_matching_game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/speech_game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/close_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';

import 'package:vozhaomuz/core/utils/audio_helper.dart';

class GamePage extends ConsumerStatefulWidget {
  final int categoryId;
  const GamePage({super.key, this.categoryId = 0});

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  bool _initialized = false;
  /// Guards against double-push of ResultGamePage. Build queues
  /// `_finishGame` via `Future.microtask` whenever `gameStage == result`,
  /// and any rebuild before the push lands (e.g. profile money sync after
  /// `_applySyncRewards`) queues a second microtask, stacking two
  /// ResultGamePages. Symptom: Exit needs two taps because the first only
  /// pops the duplicate. Reset back to false after the pushed route
  /// returns so a subsequent session can navigate again.
  bool _resultPushed = false;

  @override
  void initState() {
    super.initState();
    AudioHelper.preloadSfx(); // Preload SFX for instant feedback sounds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isRepeat = ref.read(isRepeatModeProvider);
      debugPrint('🎮 [GamePage] initState - isRepeat=$isRepeat');

      if (isRepeat) {
        // In repeat mode, game state is already set by repeat_flow_page
        // Reset result tracker AND gameState (correctAnswer must match current words)
        ref.read(gameResultProvider.notifier).reset();
        ref.read(gameStateProvider.notifier).reset();
        ref.read(gameModeProvider.notifier).set(GameMode.sound);
        debugPrint(
          '🎮 [GamePage] Repeat mode - keeping stage=${ref.read(gameStageProvider)}, '
          'words=${ref.read(learningWordsProvider).length}, '
          'dots=${ref.read(dotsProvider).dotColors.length}',
        );
      } else {
        // Normal learning flow — reset everything
        debugPrint('🎮 [GamePage] initState - Resetting ALL game states');
        ref.read(gameStageProvider.notifier).set(GameStage.flashcards);
        ref.read(currentWordIndexProvider.notifier).set(0);
        ref.read(gameResultProvider.notifier).reset();
        ref.read(gameStateProvider.notifier).reset();
        ref.read(dotsProvider.notifier).reset();
        ref.read(gameModeProvider.notifier).set(GameMode.sound);
        debugPrint(
          '🎮 [GamePage] Reset complete - stage=${ref.read(gameStageProvider)}, '
          'wordIndex=${ref.read(currentWordIndexProvider)}',
        );
      }
      setState(() {
        _initialized = true;
      });
    });
  }

  Future<void> _finishGame(BuildContext context, WidgetRef ref) async {
    if (_resultPushed) return;
    _resultPushed = true;
    final results = ref.read(gameResultProvider);
    final isRepeat = ref.read(isRepeatModeProvider);
    // In repeat mode, use allRepeatWordsProvider (full 10 words)
    // In normal mode, use learningWordsProvider
    final words = isRepeat
        ? ref.read(allRepeatWordsProvider)
        : ref.read(learningWordsProvider);

    final correctWordIds = results
        .where((r) => r.isCorrect)
        .map((r) => r.wordId)
        .toList();

    // Use widget.categoryId if set, otherwise get from first word
    final categoryId = widget.categoryId != 0
        ? widget.categoryId
        : (words.isNotEmpty ? words.first.categoryId : 0);

    debugPrint(
      '🎮 [GamePage] Finishing game with categoryId=$categoryId, isRepeat=$isRepeat',
    );

    // Pass lessonIndex so ResultPage → ChoseLearnKnowPage stays on the same unit
    final selectedSub = ref.read(selectedSubcategoryProvider);
    final lessonIdx = selectedSub != null ? selectedSub - 1 : null;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultGamePage(
          categoryId: categoryId,
          learnedWordIds: correctWordIds,
          lessonIndex: lessonIdx,
        ),
      ),
    );
    if (mounted) _resultPushed = false;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(getProfileInfoProvider);
    final dotsState = ref.watch(dotsProvider);
    final controller = ref.read(dotsProvider.notifier);
    final currentIndex = dotsState.currentIndex;
    final totalDots = dotsState.dotColors.length;
    final gameStage = ref.watch(gameStageProvider);

    return userAsync.when(
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF5FAFF),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress dots shimmer
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title shimmer
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 160,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle shimmer
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Word card shimmer
                Expanded(
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Bottom button shimmer
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Ошибка при загрузке: $err'))),
      data: (user) {
        final isPremium = user!.userType == 'pre';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(isPremiumProvider.notifier).set(isPremium);
        });
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              showExitConfirmationDialog(context);
            }
          },
          child: Scaffold(
            backgroundColor: Color(0xFFF5FAFF),
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            showExitConfirmationDialog(context);
                          },
                          icon: Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: dotsState.dotColors
                                        .map(
                                          (color) => Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "$currentIndex/$totalDots",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 5,
                      ),
                      child: Text(
                        gameStage == GameStage.flashcards
                            ? "Choose the translation".tr()
                            : gameStage == GameStage.matching
                            ? "Matching".tr()
                            : gameStage == GameStage.keyboard
                            ? "Make a word / Build a word".tr()
                            : gameStage == GameStage.trueFalse
                            ? "True False".tr()
                            : gameStage == GameStage.wordPuzzle
                            ? "Find the word".tr()
                            : gameStage == GameStage.sound
                            ? "Translation selection – audio".tr()
                            : "",
                        style: TextStyle(
                          color: Color(0xFF697586),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (gameStage == GameStage.keyboard) SizedBox(height: 30),
                    if (gameStage == GameStage.wordPuzzle) SizedBox(height: 24),
                    if (gameStage == GameStage.flashcards ||
                        gameStage == GameStage.matching ||
                        gameStage == GameStage.sound)
                      SizedBox(height: 20)
                    else
                      SizedBox.shrink(),
                    Expanded(
                      child: isPremium == false
                          ? gameStage == GameStage.flashcards
                                ? Flashcard()
                                : gameStage == GameStage.matching
                                ? MatchGamePage()
                                : gameStage == GameStage.trueFalse
                                ? CorrectIncorrectPage()
                                : gameStage == GameStage.sound
                                ? SoundWordMatchingGamePage()
                                : gameStage == GameStage.keyboard
                                ? KeyboardGamePage()
                                : gameStage == GameStage.result
                                ? Builder(
                                    builder: (_) {
                                      if (_initialized) {
                                        Future.microtask(
                                          () => _finishGame(context, ref),
                                        );
                                      }
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                  )
                                : SizedBox.shrink()
                          : gameStage == GameStage.flashcards
                          ? Flashcard()
                          : gameStage == GameStage.matching
                          ? MatchGamePage()
                          : gameStage == GameStage.trueFalse
                          ? CorrectIncorrectPage()
                          : gameStage == GameStage.sound
                          ? SoundWordMatchingGamePage()
                          : gameStage == GameStage.keyboard
                          ? KeyboardGamePage()
                          : gameStage == GameStage.speech
                          ? SpeechGamePage(categoryId: widget.categoryId)
                          : gameStage == GameStage.result
                          ? Builder(
                              builder: (_) {
                                if (_initialized) {
                                  Future.microtask(
                                    () => _finishGame(context, ref),
                                  );
                                }
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            )
                          : SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Maps Unity game name to GameStage
GameStage _gameNameToStage(String gameName) {
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

dynamic getNextStage(GameStage current, WidgetRef ref) {
  final isRepeat = ref.read(isRepeatModeProvider);

  if (isRepeat) {
    // Unity-style: advance to next game in repeatGameOrder
    final gameOrder = ref.read(repeatGameOrderProvider);
    final currentIdx = ref.read(repeatGameIndexProvider);
    final nextIdx = currentIdx + 1;

    debugPrint(
      '🔄 [getNextStage] Repeat: currentIdx=$currentIdx, nextIdx=$nextIdx, total=${gameOrder.length}',
    );

    if (nextIdx >= gameOrder.length) {
      // All games done → go to result
      debugPrint('🔄 [getNextStage] All repeat games done → result');
      return GameStage.result;
    }

    // Advance to next game
    ref.read(repeatGameIndexProvider.notifier).set(nextIdx);
    final nextGameName = gameOrder[nextIdx];
    final nextStage = _gameNameToStage(nextGameName);

    // Swap learningWordsProvider to the next game's words
    final gameMap = ref.read(repeatGameMapProvider);
    final nextWords = gameMap[nextGameName] ?? [];
    ref.read(learningWordsProvider.notifier).set(nextWords);
    ref.read(currentWordIndexProvider.notifier).set(0);
    // Reset gameState so correctAnswer uses the NEW game's words
    ref.read(gameStateProvider.notifier).reset();

    debugPrint(
      '🔄 [getNextStage] Repeat: $current → $nextStage ($nextGameName, ${nextWords.length} words)',
    );
    return nextStage;
  }

  // Normal learning flow
  //
  // NON-PREMIUM: flashcards → matching → sound → keyboard → trueFalse → result
  // PREMIUM:     flashcards → matching → sound → keyboard → speech → result
  //
  // Unity: Speech game (UIGame5 — Azure SDK) is premium-only.
  //        Non-premium users get True-False (UIGame7) instead.
  final isPremium = ref.read(isPremiumProvider);
  GameStage nextStage;
  switch (current) {
    case GameStage.flashcards:
      nextStage = GameStage.matching;
      break;
    case GameStage.matching:
      nextStage = GameStage.sound;
      break;
    case GameStage.sound:
      nextStage = GameStage.keyboard;
      break;
    case GameStage.keyboard:
      // Non-premium → trueFalse
      // Premium → speech
      nextStage = isPremium == false ? GameStage.trueFalse : GameStage.speech;
      break;
    case GameStage.trueFalse:
      // trueFalse is the last game for non-premium users
      nextStage = GameStage.result;
      break;
    default:
      nextStage = GameStage.result;
  }
  debugPrint('🔄 [getNextStage] $current → $nextStage (isPremium=$isPremium)');
  return nextStage;
}
