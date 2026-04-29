import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/model_question.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/wrong_answer2.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/shared/widgets/like_ListTile.dart';
import 'package:vozhaomuz/shared/widgets/words_box.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';

import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';

class Flashcard extends ConsumerStatefulWidget {
  const Flashcard({super.key});

  @override
  ConsumerState<Flashcard> createState() => _FlashcardState();
}

final shuffledOptionsProvider =
    NotifierProvider<ShuffledOptionsNotifier, List<Word>>(
      ShuffledOptionsNotifier.new,
    );

class ShuffledOptionsNotifier extends Notifier<List<Word>> {
  @override
  List<Word> build() {
    final original = ref.watch(learningWordsProvider);
    final currentIndex = ref.watch(currentWordIndexProvider);
    final pool = ref.watch(dummyWordPoolProvider);

    if (pool.isNotEmpty && currentIndex < original.length) {
      final correctWord = original[currentIndex];
      final dummies = ref
          .read(dummyWordPoolProvider.notifier)
          .pickForWord(correctWord, count: 3);

      if (dummies.isNotEmpty) {
        final options = [correctWord, ...dummies]..shuffle();
        return options;
      }
    }

    final shuffled = [...original]..shuffle();
    return shuffled;
  }

  void set(List<Word> value) => state = value;
}

class _FlashcardState extends ConsumerState<Flashcard>
    with TickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();

  // ── Smooth repeat timer (Unity UIGame1.cs) ──
  AnimationController? _timerController;
  bool _timerExpired = false;
  bool _answerLocked = false;
  // Real-time fallback so MIUI / developer-options "Animator duration scale"
  // (e.g. 0.1x on Redmi 12C → 10s timer collapses to ~1s) cannot cheat the
  // user out of their reply window. The AnimationController still drives
  // the smooth progress bar; whichever of the two fires first wins.
  Timer? _wallClockTimer;
  static const Duration _repeatTimeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimerIfRepeat();
    });
  }

  @override
  void dispose() {
    _timerController?.dispose();
    _wallClockTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  void _startTimerIfRepeat() {
    final isRepeat = ref.read(isRepeatModeProvider);
    if (!isRepeat) return;

    _timerController?.dispose();
    _wallClockTimer?.cancel();
    _timerController = AnimationController(
      vsync: this,
      duration: _repeatTimeout,
    );

    setState(() {
      _timerExpired = false;
      _answerLocked = false;
    });

    // forward: 0.0 → 1.0 (empty → full), we show (1.0 - value) as remaining.
    // NOTE: we deliberately do NOT listen to `AnimationStatus.completed` —
    // on devices with a reduced "Animator duration scale" (e.g. MIUI's
    // battery-saver, or a user-set 0.1x in Developer Options) the
    // controller fires up to 10× early, which is exactly the Redmi 12C
    // bug we saw. The `Timer` below is the sole source of truth for
    // expiration; the controller is kept only for the visual progress bar.
    _timerController!.forward(from: 0.0);

    // Wall-clock deadline — Dart's Timer uses real time and is immune
    // to Android animation scaling.
    _wallClockTimer = Timer(_repeatTimeout, _onTimerExpired);
  }

  /// Timer expired — auto-answer wrong (Unity: TimeLess())
  void _onTimerExpired() async {
    if (!mounted || _answerLocked) return;
    setState(() {
      _timerExpired = true;
      _answerLocked = true;
    });

    debugPrint('⏰ [Flashcard] Timer expired — auto-answering wrong');

    try {
      await AudioHelper.playWrong();
    } catch (_) {}

    final words = ref.read(learningWordsProvider);
    final index = ref.read(currentWordIndexProvider);
    if (index < words.length) {
      final word = words[index];
      ref.read(dotsProvider.notifier).markAnswer(isCorrect: false);
      ref.read(gameResultProvider.notifier).addResult(
            word: word.word,
            translation: word.translation,
            isCorrect: false,
            gameIndex: 1,
            wordId: word.id,
            gameName: GameNames.selectTranslation,
          );
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    ref.read(currentWordIndexProvider.notifier).increment();
    ref.read(showCorrectnessLabelProvider.notifier).set(null);

    final nextIndex = ref.read(currentWordIndexProvider);
    final pool = ref.read(dummyWordPoolProvider);
    if (pool.isNotEmpty && nextIndex < words.length) {
      final nextCorrect = words[nextIndex];
      final dummies = ref
          .read(dummyWordPoolProvider.notifier)
          .pickForWord(nextCorrect, count: 3);
      if (dummies.isNotEmpty) {
        final options = [nextCorrect, ...dummies]..shuffle();
        ref.read(shuffledOptionsProvider.notifier).set(options);
      } else {
        ref.read(shuffledOptionsProvider.notifier).set([...words]..shuffle());
      }
    } else {
      ref.read(shuffledOptionsProvider.notifier).set([...words]..shuffle());
    }

    final flashIndex = ref.read(gameStateProvider).currentQuestionIndex;
    final stage = ref.read(gameStageProvider);
    if (flashIndex < words.length - 1) {
      ref.read(gameStateProvider.notifier).nextQuestion();
    } else {
      ref.read(currentWordIndexProvider.notifier).set(0);
      ref.read(gameStateProvider.notifier).reset();
      ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
      return;
    }

    _startTimerIfRepeat();
  }

  @override
  Widget build(BuildContext context) {
    final dotsState = ref.watch(dotsProvider);
    final currentIndex = dotsState.currentIndex;
    final words = ref.watch(learningWordsProvider);
    final isRepeat = ref.watch(isRepeatModeProvider);

    // Агар калимаҳо холӣ бошанд — паёми хатогӣ нишон медиҳем
    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            "no_words_available".tr(),
            style: const TextStyle(fontSize: 16, color: Color(0xFF697586)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // ── Timer bar pinned to top ──
          if (isRepeat) ...[
            const SizedBox(height: 4),
            _buildTimerBar(),
            const SizedBox(height: 8),
          ],
          // ── Game centered vertically ──
          Expanded(
            child: Center(
              child: WordsBox(
              isVolume: false,
              topColorContainer: Color.fromARGB(255, 232, 237, 241),
              topWidthContainer: 100,
              topTextContainer: "Choose the correct translation".tr(),
              topWordContainer: Text(
                (currentIndex < words.length && currentIndex >= 0)
                    ? words[currentIndex].displayWord
                    : "",
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              isIcon: true,
              onPressed: () {
                HapticFeedback.lightImpact();
              },
              child: Consumer(
                builder: (context, ref, _) {
                  final shuffledOptions = ref.watch(shuffledOptionsProvider);
                  final correctAnswer =
                      ref.watch(gameStateProvider).correctAnswer;
                  if (shuffledOptions.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      Divider(color: Colors.white, height: 0),
                      for (int i = 0;
                          i < shuffledOptions.length - 1;
                          i++) ...[
                        _buildLikeTile(
                          shuffledOptions[i].word,
                          shuffledOptions[i].translation,
                          ref,
                          0,
                          context,
                          correctAnswer: correctAnswer,
                        ),
                        Divider(color: Color(0xFFEEF2F6), height: 0),
                      ],
                      _buildLikeTile(
                        shuffledOptions[shuffledOptions.length - 1].word,
                        shuffledOptions[shuffledOptions.length - 1].translation,
                        ref,
                        1,
                        context,
                        correctAnswer: correctAnswer,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  /// Smooth timer bar with AnimatedBuilder
  Widget _buildTimerBar() {
    if (_timerController == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _timerController!,
      builder: (context, _) {
        final remaining = 1.0 - _timerController!.value; // 1.0 → 0.0
        final seconds = (10 * remaining).ceil().clamp(0, 10);
        final timeStr = '00:${seconds.toString().padLeft(2, '0')}';
        final isLow = seconds <= 3;

        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: remaining,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isLow ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isLow
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF697586),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLikeTile(
    String englishWord,
    String translation,
    WidgetRef ref,
    int isLast,
    BuildContext context, {
    required String correctAnswer,
  }) {
    final selectedAnswer = ref.watch(selectedAnswerProvider);

    Color tileColor = Colors.white;

    if (_timerExpired) {
      if (translation == correctAnswer) {
        tileColor = const Color(0xFF22C55E);
      }
    } else if (selectedAnswer != null) {
      if (translation == correctAnswer && translation == selectedAnswer) {
        tileColor = const Color(0xFF22C55E);
      } else if (translation == selectedAnswer &&
          translation != correctAnswer) {
        tileColor = const Color(0xFFEF4444);
      }
    }

    return GestureDetector(
      onTap: _answerLocked
          ? null
          : () async {
              setState(() => _answerLocked = true);
              // Stop both the visual animation and the wall-clock fallback
              // so the user isn't auto-marked wrong after they tapped.
              _timerController?.stop();
              _wallClockTimer?.cancel();

              ref.read(selectedAnswerProvider.notifier).set(translation);

              final isCorrect = translation == correctAnswer;

              try {
                if (isCorrect) {
                  await AudioHelper.playCorrect();
                } else {
                  await AudioHelper.playWrong();
                }
              } catch (e) {
                debugPrint('Audio error (ignored): $e');
              }

              await Future.delayed(const Duration(milliseconds: 200));

              if (!isCorrect) {
                final words = ref.read(learningWordsProvider);
                final shuffledOptions = ref.read(shuffledOptionsProvider);
                final allSearchable = [...words, ...shuffledOptions];
                final correctWordObj =
                    allSearchable.cast<Word?>().firstWhere(
                          (w) => w?.translation == correctAnswer,
                          orElse: () => null,
                        );

                if (correctWordObj != null) {
                  await showAnswerFeedback(
                    context,
                    userAnswer: englishWord,
                    userTranslation: translation,
                    correctAnswer: correctWordObj.word,
                    correctTranslation: correctWordObj.translation,
                    categoryId: correctWordObj.categoryId,
                  );
                }
              }

              if (!mounted) return;
              ref.read(selectedAnswerProvider.notifier).set(null);
              ref.read(showCorrectnessLabelProvider.notifier).set(true);

              ref
                  .read(dotsProvider.notifier)
                  .markAnswer(isCorrect: isCorrect);
              final words = ref.read(learningWordsProvider);
              final index = ref.read(currentWordIndexProvider);

              if (index < words.length) {
                final word = words[index];
                ref.read(gameResultProvider.notifier).addResult(
                      word: word.word,
                      translation: word.translation,
                      isCorrect: isCorrect,
                      gameIndex: 1,
                      wordId: word.id,
                      gameName: GameNames.selectTranslation,
                    );
              }

              ref.read(currentWordIndexProvider.notifier).increment();
              ref.read(showCorrectnessLabelProvider.notifier).set(null);

              final nextIndex = ref.read(currentWordIndexProvider);
              final pool = ref.read(dummyWordPoolProvider);
              if (pool.isNotEmpty && nextIndex < words.length) {
                final nextCorrect = words[nextIndex];
                final dummies = ref
                    .read(dummyWordPoolProvider.notifier)
                    .pickForWord(nextCorrect, count: 3);
                if (dummies.isNotEmpty) {
                  final options = [nextCorrect, ...dummies]..shuffle();
                  ref.read(shuffledOptionsProvider.notifier).set(options);
                } else {
                  ref.read(shuffledOptionsProvider.notifier).set(
                      [...words]..shuffle());
                }
              } else {
                ref.read(shuffledOptionsProvider.notifier).set(
                    [...words]..shuffle());
              }
              final flashIndex =
                  ref.read(gameStateProvider).currentQuestionIndex;
              final stage = ref.read(gameStageProvider);
              if (flashIndex < words.length - 1) {
                ref.read(gameStateProvider.notifier).nextQuestion();
                setState(() => _answerLocked = false);
                _startTimerIfRepeat();
              } else {
                ref.read(currentWordIndexProvider.notifier).set(0);
                ref.read(gameStateProvider.notifier).reset();
                ref
                    .read(gameStageProvider.notifier)
                    .set(getNextStage(stage, ref));
              }
            },
      child: likeListTile(translation, colorr: tileColor, isLasstt: isLast),
    );
  }
}
