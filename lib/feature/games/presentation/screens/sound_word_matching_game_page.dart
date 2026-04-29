import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/core/utils/zip_resource_loader.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/wrong_answer2.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/shared/widgets/like_ListTile.dart';
import 'package:vozhaomuz/shared/widgets/words_box.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';

class SoundWordMatchingGamePage extends ConsumerStatefulWidget {
  const SoundWordMatchingGamePage({super.key});

  @override
  ConsumerState<SoundWordMatchingGamePage> createState() =>
      _SoundWordMatchingGamePageState();
}

final shuffledOptionsProvider =
    NotifierProvider<SoundGameShuffledOptionsNotifier, List<Word>>(
      SoundGameShuffledOptionsNotifier.new,
    );

class SoundGameShuffledOptionsNotifier extends Notifier<List<Word>> {
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

    return [...original]..shuffle();
  }

  void set(List<Word> value) => state = value;
}

final lastPlayedWordProvider =
    NotifierProvider<LastPlayedWordNotifier, String?>(
      LastPlayedWordNotifier.new,
    );

class LastPlayedWordNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final currentWordProvider = Provider<Word>((ref) {
  final currentIndex = ref.watch(currentWordIndexProvider);
  final words = ref.watch(learningWordsProvider);
  if (currentIndex >= 0 && currentIndex < words.length) {
    return words[currentIndex];
  }
  return words.isNotEmpty
      ? words[0]
      : Word(
          id: 0,
          word: '',
          translation: '',
          transcription: '',
          categoryId: 0,
          status: '',
        );
});

class _SoundWordMatchingGamePageState
    extends ConsumerState<SoundWordMatchingGamePage>
    with TickerProviderStateMixin {
  late final AudioPlayer player = AudioPlayer();

  // ── Smooth repeat timer ──
  AnimationController? _timerController;
  bool _timerExpired = false;
  bool _answerLocked = false;
  // Wall-clock fallback — immune to MIUI / dev-options "Animator duration
  // scale" (e.g. 0.1x on Redmi 12C would collapse the 10s timer to ~1s).
  Timer? _wallClockTimer;
  static const Duration _repeatTimeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameMode = ref.watch(gameModeProvider);
      if (gameMode == GameMode.sound) {
        final words = ref.read(learningWordsProvider);
        if (words.isNotEmpty) {
          final firstWord = words[0];
          AudioHelper.playWord(
            player,
            '',
            '${firstWord.word}.mp3',
            categoryId: firstWord.categoryId,
          );
          ref.read(lastPlayedWordProvider.notifier).set(firstWord.word);
        }
      }
      _startTimerIfRepeat();
    });
  }

  @override
  void dispose() {
    _timerController?.dispose();
    _wallClockTimer?.cancel();
    ZipResourceLoader.clear();
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

    // No status listener on the AnimationController — on MIUI devices
    // with a reduced "Animator duration scale" it would fire way before
    // 10s (Redmi 12C bug). The Timer below is the single source of
    // truth for the 10s deadline; the controller only drives the visual
    // progress bar.
    _timerController!.forward(from: 0.0);
    _wallClockTimer = Timer(_repeatTimeout, _onTimerExpired);
  }

  void _onTimerExpired() async {
    if (!mounted || _answerLocked) return;
    setState(() {
      _timerExpired = true;
      _answerLocked = true;
    });

    try {
      await AudioHelper.playWrong();
    } catch (_) {}

    final words = ref.read(learningWordsProvider);
    final index = ref.read(currentWordIndexProvider);
    if (index < words.length) {
      final word = words[index];
      ref.read(dotsProvider.notifier).markAnswer(isCorrect: false);
      ref
          .read(gameResultProvider.notifier)
          .addResult(
            word: word.word,
            translation: word.translation,
            isCorrect: false,
            gameIndex: 3,
            wordId: word.id,
            gameName: GameNames.selectTranslationAudio,
          );
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    _advanceToNext();
  }

  void _advanceToNext() {
    // Таймерро пеш аз гузариш ба бозии дигар қатъ мекунем
    _timerController?.stop();
    _wallClockTimer?.cancel();

    final stage = ref.read(gameStageProvider);
    final original = ref.read(learningWordsProvider);
    final currentIndex = ref.read(currentWordIndexProvider);
    final nextIndex = currentIndex + 1;

    final pool = ref.read(dummyWordPoolProvider);
    if (pool.isNotEmpty && nextIndex < original.length) {
      final nextCorrect = original[nextIndex];
      final dummies = ref
          .read(dummyWordPoolProvider.notifier)
          .pickForWord(nextCorrect, count: 3);
      if (dummies.isNotEmpty) {
        ref
            .read(shuffledOptionsProvider.notifier)
            .set([nextCorrect, ...dummies]..shuffle());
      } else {
        ref
            .read(shuffledOptionsProvider.notifier)
            .set([...original]..shuffle());
      }
    } else {
      ref.read(shuffledOptionsProvider.notifier).set([...original]..shuffle());
    }

    ref.read(selectedAnswerProvider.notifier).set(null);

    if (nextIndex >= original.length) {
      ref.read(currentWordIndexProvider.notifier).set(0);
      ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
    } else {
      ref.read(currentWordIndexProvider.notifier).increment();
      _startTimerIfRepeat();
    }
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameMode = ref.watch(gameModeProvider);
    final words = ref.read(learningWordsProvider);
    final currentIndex = ref.read(currentWordIndexProvider);
    final isRepeat = ref.watch(isRepeatModeProvider);

    // Агар калимаҳо холӣ бошанд — экрани холӣ нишон намедиҳем
    if (words.isEmpty) {
      return const Center(
        child: Text(
          'No words available',
          style: TextStyle(fontSize: 16, color: Color(0xFF697586)),
        ),
      );
    }

    if (gameMode == GameMode.flashcard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentIndex >= 0 && currentIndex < words.length) {
          ref
              .read(lastPlayedWordProvider.notifier)
              .set(words[currentIndex].word);
        }
      });
    }
    if (gameMode == GameMode.sound) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isRepeat) _buildTimerBar(),
            const SizedBox(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer(
                builder: (context, ref, _) {
                  ref.listen<int>(currentWordIndexProvider, (previous, next) {
                    final shuffledOptions = ref.read(learningWordsProvider);
                    if (next >= 0 && next < shuffledOptions.length) {
                      Future.delayed(Duration(milliseconds: 200), () {
                        if (!context.mounted) return;
                        final nextWord = shuffledOptions[next];
                        AudioHelper.playWord(
                          player,
                          '',
                          '${nextWord.word}.mp3',
                          categoryId: nextWord.categoryId,
                        );
                        ref
                            .read(lastPlayedWordProvider.notifier)
                            .set(nextWord.word);
                      });
                    }
                  });
                  final currentIndexx = ref.watch(currentWordIndexProvider);
                  final shuffledOptions = ref.watch(learningWordsProvider);
                  return WordsBox(
                    isVolume: false,
                    topColorContainer: Colors.white,
                    topWidthContainer: 130,
                    topTextContainer: "listen_choose_translation".tr(),
                    topWordContainer: IconButton(
                      onPressed: () {
                        final currentIndex = ref.read(currentWordIndexProvider);
                        final words = ref.read(learningWordsProvider);
                        if (currentIndex >= 0 && currentIndex < words.length) {
                          final currentWord = words[currentIndex].word;
                          AudioHelper.playWord(
                            player,
                            '',
                            '$currentWord.mp3',
                            categoryId: words[currentIndex].categoryId,
                          );
                          ref
                              .read(lastPlayedWordProvider.notifier)
                              .set(currentWord);
                        }
                      },
                      icon: const Icon(
                        Icons.volume_up,
                        color: Color(0xFF2E90FA),
                        size: 50,
                      ),
                    ),
                    isIcon: true,
                    onPressed: () {},
                    child: Consumer(
                      builder: (context, ref, _) {
                        final shuffledOptions = ref.watch(
                          shuffledOptionsProvider,
                        );
                        return Column(
                          children: [
                            Divider(color: Color(0xFFEEF2F6), height: 2),
                            for (
                              int i = 0;
                              i < shuffledOptions.length - 1;
                              i++
                            ) ...[
                              _buildLikeTile(
                                shuffledOptions[i].word,
                                shuffledOptions[i].translation,
                                ref,
                                0,
                                context,
                              ),
                              Divider(
                                color: i < shuffledOptions.length - 1
                                    ? Colors.grey.shade200
                                    : Colors.white,
                                height: 0,
                              ),
                            ],
                            _buildLikeTile(
                              shuffledOptions[shuffledOptions.length - 1].word,
                              shuffledOptions[shuffledOptions.length - 1]
                                  .translation,
                              ref,
                              1,
                              context,
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 50),
            TextButton(
              onPressed: () {
                ref.read(gameModeProvider.notifier).set(GameMode.flashcard);
              },
              child: Text(
                'cant_listen_now'.tr(),
                style: AppTextStyles.bigTextStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  color: Color(0xFF2E90FA),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Flashcard mode fallback
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRepeat) _buildTimerBar(),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: WordsBox(
                isVolume: false,
                topColorContainer: const Color(0xFFEEF2F6),
                topWidthContainer: 95,
                topTextContainer: "Прослушай и выбери перевод",
                topWordContainer: Consumer(
                  builder: (context, ref, _) {
                    final currentIndex = ref.watch(currentWordIndexProvider);
                    final words = ref.watch(learningWordsProvider);

                    return Text(
                      (currentIndex >= 0 && currentIndex < words.length)
                          ? words[currentIndex].displayWord
                          : "",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202939),
                      ),
                    );
                  },
                ),
                isIcon: true,
                onPressed: () {},
                child: Consumer(
                  builder: (context, ref, _) {
                    final shuffledOptions = ref.watch(shuffledOptionsProvider);
                    return Column(
                      children: [
                        Divider(color: Colors.white, height: 0),
                        for (
                          int i = 0;
                          i < shuffledOptions.length - 1;
                          i++
                        ) ...[
                          _buildLikeTile(
                            shuffledOptions[i].word,
                            shuffledOptions[i].translation,
                            ref,
                            0,
                            context,
                          ),
                          Divider(
                            color: i < shuffledOptions.length - 1
                                ? Colors.grey.shade200
                                : Colors.white,
                            height: 0,
                          ),
                        ],
                        _buildLikeTile(
                          shuffledOptions[shuffledOptions.length - 1].word,
                          shuffledOptions[shuffledOptions.length - 1]
                              .translation,
                          ref,
                          1,
                          context,
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

  Widget _buildLikeTile(
    String englishWord,
    String translation,
    WidgetRef ref,
    int isLast,
    BuildContext context,
  ) {
    final selectedAnswer = ref.watch(selectedAnswerProvider);
    final currentWord = ref.watch(currentWordProvider);
    final correctAnswer = currentWord.translation;
    final correctAnswerWord = currentWord.word;
    final correctId = currentWord.id;
    Color tileColor = Colors.white;

    if (_timerExpired) {
      if (translation.trim() == correctAnswer.trim()) {
        tileColor = const Color(0xFF22C55E);
      }
    } else if (selectedAnswer != null) {
      if (translation.trim() == correctAnswer.trim() && translation == selectedAnswer) {
        tileColor = const Color(0xFF22C55E);
      } else if (translation == selectedAnswer &&
          translation.trim() != correctAnswer.trim()) {
        tileColor = const Color(0xFFEF4444);
      }
    }

    return GestureDetector(
      onTap: _answerLocked
          ? null
          : () async {
              setState(() => _answerLocked = true);
              _timerController?.stop();
              _wallClockTimer?.cancel();

              final selected = ref.read(selectedAnswerProvider);
              if (selected != null) return;
              ref.read(selectedAnswerProvider.notifier).set(translation);
              final isCorrect = translation.trim() == correctAnswer.trim();
              
              // DEBUG: Log comparison details to find why identical-looking strings don't match
              if (!isCorrect) {
                debugPrint('❌ [MATCH DEBUG] isCorrect=false');
                debugPrint('   translation     = "${translation}" (len=${translation.length})');
                debugPrint('   correctAnswer   = "${correctAnswer}" (len=${correctAnswer.length})');
                debugPrint('   translation.trim()   = "${translation.trim()}" (len=${translation.trim().length})');
                debugPrint('   correctAnswer.trim() = "${correctAnswer.trim()}" (len=${correctAnswer.trim().length})');
                debugPrint('   englishWord     = "$englishWord"');
                debugPrint('   correctWord     = "$correctAnswerWord"');
                debugPrint('   correctId       = $correctId');
                // Print char codes for first difference
                final t = translation;
                final c = correctAnswer;
                for (int i = 0; i < t.length && i < c.length; i++) {
                  if (t.codeUnitAt(i) != c.codeUnitAt(i)) {
                    debugPrint('   DIFF at index $i: "${t[i]}"(${t.codeUnitAt(i)}) vs "${c[i]}"(${c.codeUnitAt(i)})');
                    break;
                  }
                }
                if (t.length != c.length) {
                  debugPrint('   LENGTH DIFF: ${t.length} vs ${c.length}');
                }
              }
              
              final lastPlayedWord = ref.read(lastPlayedWordProvider);
              ref.read(dotsProvider.notifier).markAnswer(isCorrect: isCorrect);
              final gameMode = ref.read(gameModeProvider);
              // Await the SFX so it finishes before the next word audio starts —
              // otherwise the two sounds overlap and the user has to tap the
              // volume button again to rehear the word.
              try {
                if (isCorrect) {
                  await AudioHelper.playCorrect(awaitCompletion: true);
                } else {
                  await AudioHelper.playWrong(awaitCompletion: true);
                }
              } catch (e) {
                debugPrint('Audio error (ignored): $e');
              }
              ref
                  .read(gameResultProvider.notifier)
                  .addResult(
                    word: correctAnswerWord,
                    translation: correctAnswer,
                    isCorrect: isCorrect,
                    gameIndex: 3,
                    wordId: correctId,
                    gameName: GameNames.selectTranslationAudio,
                  );
              if (currentWord.word != lastPlayedWord &&
                  gameMode == GameMode.sound) {
                AudioHelper.playWord(
                  player,
                  '',
                  '${currentWord.word}.mp3',
                  categoryId: currentWord.categoryId,
                );
                ref.read(lastPlayedWordProvider.notifier).set(currentWord.word);
              }
              await Future.delayed(Duration(milliseconds: 200));
              if (!isCorrect) {
                await showAnswerFeedback(
                  context,
                  userAnswer: englishWord,
                  userTranslation: translation,
                  correctAnswer: currentWord.word,
                  correctTranslation: correctAnswer,
                  categoryId: currentWord.categoryId,
                );
              }
              if (!mounted) return;
              ref.read(selectedAnswerProvider.notifier).set(null);

              final original = ref.read(learningWordsProvider);
              final currentIndex = ref.read(currentWordIndexProvider);
              final nextIndex = currentIndex + 1;

              final pool = ref.read(dummyWordPoolProvider);
              if (pool.isNotEmpty && nextIndex < original.length) {
                final nextCorrect = original[nextIndex];
                final dummies = ref
                    .read(dummyWordPoolProvider.notifier)
                    .pickForWord(nextCorrect, count: 3);
                if (dummies.isNotEmpty) {
                  ref
                      .read(shuffledOptionsProvider.notifier)
                      .set([nextCorrect, ...dummies]..shuffle());
                } else {
                  ref
                      .read(shuffledOptionsProvider.notifier)
                      .set([...original]..shuffle());
                }
              } else {
                ref
                    .read(shuffledOptionsProvider.notifier)
                    .set([...original]..shuffle());
              }

              final stage = ref.read(gameStageProvider);
              if (nextIndex >= original.length) {
                ref.read(currentWordIndexProvider.notifier).set(0);
                ref
                    .read(gameStageProvider.notifier)
                    .set(getNextStage(stage, ref));
              } else {
                ref.read(currentWordIndexProvider.notifier).increment();
                setState(() => _answerLocked = false);
                _startTimerIfRepeat();
              }
            },
      child: likeListTile(translation, colorr: tileColor, isLasstt: isLast),
    );
  }
}
