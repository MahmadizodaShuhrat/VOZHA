import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/model_question.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/verno_neverno.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';

class CorrectIncorrectPage extends ConsumerStatefulWidget {
  const CorrectIncorrectPage({super.key});

  @override
  ConsumerState<CorrectIncorrectPage> createState() =>
      _CorrectIncorrectPageState();
}

final randomTranslationProvider =
    NotifierProvider<RandomTranslationNotifier, String?>(
      RandomTranslationNotifier.new,
    );

class RandomTranslationNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

class _CorrectIncorrectPageState extends ConsumerState<CorrectIncorrectPage>
    with TickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  final AudioPlayer _ciCorrectPlayer = AudioPlayer()..setPlaybackRate(1.2);
  final AudioPlayer _ciWrongPlayer = AudioPlayer()..setPlaybackRate(1.2);

  // ── Smooth repeat timer (Unity UIGame7.cs) ──
  // AnimationController drives the progress-bar UI; a real wall-clock
  // Timer is the source of truth for expiry. AnimationController alone
  // fires early on devices with reduced Animator duration scale
  // (e.g. Redmi 12C MIUI power-save), making the 10s countdown appear
  // as 1s for the user.
  AnimationController? _timerController;
  Timer? _wallClockTimer;
  static const Duration _repeatTimeout = Duration(seconds: 10);
  bool _timerExpired = false;
  bool _answerLocked = false;
  Widget _imagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F0FE), Color(0xFFF0E6FF), Color(0xFFE8F0FE)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 48,
          color: Color(0xFF98A2B3),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentWordIndexProvider.notifier).set(0);
      _startTimerIfRepeat();
    });

    final words = ref.read(learningWordsProvider).take(4).toList();
    final random = Random();
    String newRandom;
    if (words.isNotEmpty) {
      if (random.nextBool()) {
        newRandom = words[0].translation;
      } else {
        final wrongOptions = words.where((w) => w.translation != words[0].translation).toList();
        if (wrongOptions.isNotEmpty) {
          newRandom = wrongOptions[random.nextInt(wrongOptions.length)].translation;
        } else {
          newRandom = words[0].translation;
        }
      }
    } else {
      newRandom = '';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(randomTranslationProvider.notifier).set(newRandom);
    });
  }

  @override
  void dispose() {
    _wallClockTimer?.cancel();
    _timerController?.dispose();
    player.dispose();
    _ciCorrectPlayer.dispose();
    _ciWrongPlayer.dispose();
    super.dispose();
  }

  void _startTimerIfRepeat() {
    final isRepeat = ref.read(isRepeatModeProvider);
    if (!isRepeat) return;

    _wallClockTimer?.cancel();
    _timerController?.dispose();
    _timerController = AnimationController(
      vsync: this,
      duration: _repeatTimeout,
    );

    setState(() {
      _timerExpired = false;
      _answerLocked = false;
    });

    _timerController!.forward(from: 0.0);
    _wallClockTimer = Timer(_repeatTimeout, _onTimerExpired);
  }

  void _onTimerExpired() async {
    if (!mounted || _answerLocked) return;
    setState(() { _timerExpired = true; _answerLocked = true; });
    try { await AudioHelper.playWrong(); } catch (_) {}

    final words = ref.read(learningWordsProvider).take(4).toList();
    final index = ref.read(currentWordIndexProvider);
    if (index < words.length) {
      ref.read(dotsProvider.notifier).markAnswer(isCorrect: false);
      ref.read(gameResultProvider.notifier).addResult(
        word: words[index].word,
        translation: words[index].translation,
        isCorrect: false, gameIndex: 5,
        wordId: words[index].id,
        gameName: GameNames.trueFalse,
      );
    }
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    checkAndAdvanceGame(ref);
    _startTimerIfRepeat();
  }

  Widget _buildTimerBar() {
    if (_timerController == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _timerController!,
      builder: (context, _) {
        final remaining = 1.0 - _timerController!.value;
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
            Text(timeStr, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: isLow ? const Color(0xFFEF4444) : const Color(0xFF697586),
            )),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRepeat = ref.watch(isRepeatModeProvider);
    final currentIndexx = ref.watch(currentWordIndexProvider);
    final wordss = ref.watch(learningWordsProvider);
    final limitedWords = wordss.take(4).toList();
    final wordData = (currentIndexx < limitedWords.length)
        ? limitedWords[currentIndexx]
        : null;
    final wordd = wordData?.word ?? '';
    final transciptionn = wordData?.transcription ?? '';
    final isShow = ref.watch(showCorrectnessLabelProvider);
    String getRandomTajikTranslation() {
      final random = Random();
      final options = [...limitedWords.map((e) => e.translation)];
      options.shuffle();
      return options[random.nextInt(options.length)];
    }

    final randomTajikTranslation =
        ref.watch(randomTranslationProvider) ?? getRandomTajikTranslation();
    final isCorrectTranslation = (currentIndexx < limitedWords.length)
        ? randomTajikTranslation == limitedWords[currentIndexx].translation
        : false;

    // Image / spacing sizes scale with screen height so small phones
    // (iPhone SE, Honor 5.5" at 1.15x font scale, etc.) don't clip the
    // Incorrect button off the bottom of the screen. Clamp keeps tall
    // phones from looking empty and short phones from overflowing.
    final screenH = MediaQuery.of(context).size.height;
    final imageH = (screenH * 0.26).clamp(140.0, 220.0);
    final innerPad = (screenH * 0.06).clamp(24.0, 50.0);
    final topPad = (screenH * 0.05).clamp(16.0, 40.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      // Scroll fallback — if a device ends up with inputs we didn't
      // anticipate (extra-large font scale, split-screen) the user can
      // still reach the Incorrect button instead of it hiding below
      // the navigation bar.
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenH -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom -
                100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isRepeat) _buildTimerBar(),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(height: topPad),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border(
                        bottom:
                            BorderSide(color: Color(0xFFEEF2F6), width: 6),
                        right:
                            BorderSide(color: Color(0xFFEEF2F6), width: 2),
                        left:
                            BorderSide(color: Color(0xFFEEF2F6), width: 2),
                        top: BorderSide(color: Color(0xFFEEF2F6), width: 2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(height: innerPad),
                        if (currentIndexx >= 0 &&
                            currentIndexx < limitedWords.length)
                          Builder(
                            builder: (context) {
                              final word = limitedWords[currentIndexx];
                              final hasImage = word.photoPath != null &&
                                  word.photoPath!.isNotEmpty &&
                                  File(word.photoPath!).existsSync();
                              if (hasImage) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(word.photoPath!),
                                    height: imageH,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        _imagePlaceholder(),
                                  ),
                                );
                              }
                              return _imagePlaceholder();
                            },
                          )
                        else
                          SizedBox.shrink(),
                        SizedBox(height: innerPad),
                        Divider(color: Color(0xFFEEF2F6)),
                        SizedBox(height: 5),
                    Text(
                      wordd,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      transciptionn,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        randomTajikTranslation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      //SizedBox(height: 50),
                      SizedBox(
                        height: 38,
                        child: isShow != null
                            ? vernoNeverno(isShow)
                            : SizedBox(),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                  SizedBox(height: 12),
                  MyButton(
                    depth: 4,
                    width: double.infinity,
                    height: 48,
                    borderRadius: 10,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    buttonColor: Color(0xFF22C55E),
                    backButtonColor: Color(0xFF16A34A),
                    child: Center(
                      child: Text(
                        '  ${'correct'.tr()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    onPressed: _answerLocked ? null : () async {
                      setState(() => _answerLocked = true);
                      _wallClockTimer?.cancel();
                      _timerController?.stop();
                      HapticFeedback.lightImpact();
                      try {
                        if (isCorrectTranslation == true) {
                          await AudioHelper.playCorrect();
                        } else {
                          await AudioHelper.playWrong();
                        }
                      } catch (e) {
                        debugPrint('Audio error (ignored): $e');
                      }
                      ref
                          .read(showCorrectnessLabelProvider.notifier)
                          .set(isCorrectTranslation == true);
                      await Future.delayed(const Duration(milliseconds: 400));
                      if (!mounted) return;
                      ref
                          .read(showCorrectnessLabelProvider.notifier)
                          .set(null);
                      ref
                          .read(dotsProvider.notifier)
                          .markAnswer(
                            isCorrect: isCorrectTranslation == true,
                          );
                      final currentWord = ref
                          .read(learningWordsProvider)[ref.read(
                            currentWordIndexProvider,
                          )]
                          .word;
                      final currentTranslation = ref
                          .read(learningWordsProvider)[ref.read(
                            currentWordIndexProvider,
                          )]
                          .translation;
                      final currentId = ref
                          .read(learningWordsProvider)[ref.read(
                            currentWordIndexProvider,
                          )]
                          .id;
                      ref
                          .read(gameResultProvider.notifier)
                          .addResult(
                            word: currentWord,
                            translation: currentTranslation,
                            isCorrect: isCorrectTranslation == true,
                            gameIndex: 5,
                            wordId: currentId,
                            gameName: GameNames.trueFalse,
                          );
                      checkAndAdvanceGame(ref);
                      setState(() => _answerLocked = false);
                      _startTimerIfRepeat();
                    },
                  ),
                  SizedBox(height: 15),
                  MyButton(
                    width: double.infinity,
                    height: 48,
                    depth: 4,
                    borderRadius: 10,
                    buttonColor: Color(0xFFEF4444),
                    backButtonColor: Color(0xFFDC2626),
                    child: Center(
                      child: Text(
                        '  ${'incorrect'.tr()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    onPressed: _answerLocked ? null : () async {
                      setState(() => _answerLocked = true);
                      _wallClockTimer?.cancel();
                      _timerController?.stop();
                      HapticFeedback.lightImpact();
                      try {
                        if (isCorrectTranslation == false) {
                          await _ciCorrectPlayer.stop();
                          await _ciCorrectPlayer.play(AssetSource('sounds/Accepted.mp3'));
                        } else {
                          await _ciWrongPlayer.stop();
                          await _ciWrongPlayer.play(AssetSource('sounds/WrongStatus.mp3'));
                        }
                      } catch (e) {
                        debugPrint('Audio error (ignored): $e');
                      }
                      ref
                          .read(showCorrectnessLabelProvider.notifier)
                          .set(isCorrectTranslation == false);
                      await Future.delayed(const Duration(milliseconds: 400));
                      if (!mounted) return;
                      ref
                          .read(showCorrectnessLabelProvider.notifier)
                          .set(null);
                      ref
                          .read(dotsProvider.notifier)
                          .markAnswer(
                            isCorrect: isCorrectTranslation == false,
                          );
                      final currentWord = ref
                          .read(learningWordsProvider)[ref.read(
                            currentWordIndexProvider,
                          )]
                          .word;
                      final currentTranslation = ref
                          .read(learningWordsProvider)[ref.read(
                            currentWordIndexProvider,
                          )]
                          .translation;
                      final currentId = ref
                          .read(learningWordsProvider)[ref.read(
                            currentWordIndexProvider,
                          )]
                          .id;
                      ref
                          .read(gameResultProvider.notifier)
                          .addResult(
                            word: currentWord,
                            translation: currentTranslation,
                            isCorrect: isCorrectTranslation == false,
                            gameIndex: 5,
                            wordId: currentId,
                            gameName: GameNames.trueFalse,
                          );
                      checkAndAdvanceGame(ref);
                      setState(() => _answerLocked = false);
                      _startTimerIfRepeat();
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }
}

void checkAndAdvanceGame(WidgetRef ref) {
  final stage = ref.read(gameStageProvider);
  if (stage == GameStage.flashcards) {
    final flashIndex = ref.read(gameStateProvider).currentQuestionIndex;
    if (flashIndex < 4) {
      ref.read(gameStateProvider.notifier).nextQuestion();
    } else {
      ref.read(currentWordIndexProvider.notifier).set(0);
      ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
    }
    return;
  }
  final index = ref.read(currentWordIndexProvider);
  final words = ref.read(learningWordsProvider);
  final limitedWords = words.take(4).toList();
  final random = Random();
  // 50/50 balance: randomly decide correct or wrong translation for next word
  final nextIndex = index < limitedWords.length - 1 ? index + 1 : 0;
  final nextWord = limitedWords[nextIndex];
  String newRandom;
  if (random.nextBool()) {
    // Show correct translation
    newRandom = nextWord.translation;
  } else {
    // Show wrong translation — pick from other words
    final wrongOptions = limitedWords.where((w) => w.translation != nextWord.translation).toList();
    if (wrongOptions.isNotEmpty) {
      newRandom = wrongOptions[random.nextInt(wrongOptions.length)].translation;
    } else {
      newRandom = nextWord.translation;
    }
  }

  ref.read(randomTranslationProvider.notifier).set(newRandom);

  // Unity: if (CurrentWordIndex == UIWords.Count) → NextGame()
  // Advance through ALL words, not just hardcoded 3
  if (index < limitedWords.length - 1) {
    ref.read(currentWordIndexProvider.notifier).set(index + 1);
  } else {
    ref.read(currentWordIndexProvider.notifier).set(0);
    ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
  }
}
