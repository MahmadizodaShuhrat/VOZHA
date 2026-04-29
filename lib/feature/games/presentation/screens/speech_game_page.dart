import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/core/utils/zip_resource_loader.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/result_speech_game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/wrong_answer2.dart';
import 'package:vozhaomuz/shared/widgets/like_ListTile.dart';
import 'package:vozhaomuz/shared/widgets/words_box.dart';
import 'package:vozhaomuz/core/utils/speech_bridge.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/shared/widgets/microphone_permission_dialog.dart';

// class SpeechGameNotifier extends Notifier<SpeechGameState> {
//   @override
//   SpeechGameState build() {
//     final words = ref.watch(learningWordsProvider);
//     return SpeechGameState(words: words);
//   }

//   void setResult(String? heard) {
//     final expected = state.currentWord.word.trim().toLowerCase();
//   final actual = heard
//       ?.trim()
//       .toLowerCase()
//       .replaceAll(RegExp(r'[^\w\s]'), '');
//   final correct = actual == expected;
//   state = state.copyWith(heard: heard, correct: correct);
//   }
//   void next() {
//     if (state.idx < state.words.length - 1) {
//       state = state.copyWith(idx: state.idx + 1, heard: null, correct: null);
//     }
//   }
// }

class SpeechGameNotifier extends Notifier<SpeechGameState> {
  @override
  SpeechGameState build() {
    final words = ref.watch(learningWordsProvider);
    final startFrom = ref.watch(currentWordIndexProvider); // use this as base
    return SpeechGameState(
      words: words,
      baseIndex: startFrom,
      idx: 0,
      answeredCount: 0,
    );
  }

  void setResult(String? heard) {
    final expected = state.currentWord.word.trim().toLowerCase();
    final actual = heard?.trim().toLowerCase().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );
    final correct = actual == expected;
    state = state.copyWith(heard: heard, correct: correct);
  }

  void next() {
    if (state.idx < state.words.length - state.baseIndex - 1) {
      state = state.copyWith(
        idx: state.idx + 1,
        answeredCount: state.answeredCount + 1,
        heard: null,
        correct: null,
      );
    }
  }

  int nextGameStartIndex() {
    final idx = state.baseIndex + state.answeredCount;
    return idx.clamp(0, state.words.length);
  }
}

@immutable
class SpeechGameState {
  final int baseIndex;
  final int idx;
  final int answeredCount;
  final List<Word> words;
  final String? heard;
  final bool? correct;

  SpeechGameState({
    required this.baseIndex,
    required this.idx,
    required this.answeredCount,
    required this.words,
    this.heard,
    this.correct,
  });

  SpeechGameState copyWith({
    int? baseIndex,
    int? idx,
    int? answeredCount,
    List<Word>? words,
    String? heard,
    bool? correct,
  }) {
    return SpeechGameState(
      baseIndex: baseIndex ?? this.baseIndex,
      idx: idx ?? this.idx,
      answeredCount: answeredCount ?? this.answeredCount,
      words: words ?? this.words,
      heard: heard,
      correct: correct,
    );
  }

  Word get currentWord => words[baseIndex + idx];
}

// class SpeechGameState {
//   final List<Word> words;
//   final int idx;
//   final String? heard;
//   final bool? correct;

//   const SpeechGameState({
//     required this.words,
//     this.idx = 0,
//     this.heard,
//     this.correct,
//   });

//   Word get currentWord => words[idx];

//   SpeechGameState copyWith({
//     List<Word>? words,
//     int? idx,
//     String? heard,
//     bool? correct,
//   }) {
//     return SpeechGameState(
//       words: words ?? this.words,
//       idx: idx ?? this.idx,
//       heard: heard,
//       correct: correct,
//     );
//   }
// }

final speechGameProvider =
    NotifierProvider<SpeechGameNotifier, SpeechGameState>(() {
      return SpeechGameNotifier();
    });
Color micContainerColor = Colors.blue;
Color micContainerBorderColor = Color.fromARGB(255, 21, 56, 115);

class SpeechGamePage extends ConsumerStatefulWidget {
  final categoryId;
  const SpeechGamePage({super.key, required this.categoryId});

  @override
  ConsumerState<SpeechGamePage> createState() => _SpeechGamePageState();
}

class _SpeechGamePageState extends ConsumerState<SpeechGamePage>
    with TickerProviderStateMixin {
  final _speech = SpeechBridge();
  bool _speechInitialized = false;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  bool _gameFinished = false;
  bool _isAnalyzing = false;
  int _retryCount = 0; // Unity: max 3 retries per word
  late AnimationController _pulseController;
  final AudioPlayer player = AudioPlayer();
  // Cached flashcard options — only regenerate when word changes
  List<Word> _cachedOptions = [];
  int? _lastWordId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _speech.init(
        key: 'c66a1cf12d114cdd82f37f652f34db1b',
        region: 'eastasia',
      );
      _speechInitialized = true;

      // ✅ Ҳолатро ба speech гузоштан, то микрофон нишон дода шавад
      Future.microtask(() {
        ref.read(gameModeProvider.notifier).set(GameMode.speech);
      });

      final game = ref.read(speechGameProvider);
      AudioHelper.playWord(
        player,
        '',
        '${game.currentWord.word}.mp3',
        categoryId: game.currentWord.categoryId,
      );
    } catch (e) {
      debugPrint('Speech SDK not available, switching to flashcard mode: $e');
      // Speech SDK is not available, switch to flashcard mode
      _speechInitialized = false;
      Future.microtask(() {
        ref.read(gameModeProvider.notifier).set(GameMode.flashcard);
      });
    }
  }

  /// Asks for microphone permission, but first shows our own explainer
  /// dialog telling the user to tap "Разрешить / Allow" on the OS prompt.
  /// We learned that many users dismiss the OS dialog without reading and
  /// then can't use speech games — pre-explaining cuts that drop-off.
  ///
  /// Returns true only if permission ends up granted. If already granted,
  /// returns true without showing any dialog. If permanently denied,
  /// shows a settings prompt and returns false.
  /// SharedPreferences flag — set to `true` after the explainer has
  /// been acknowledged once so it doesn't pop up before every retry of
  /// a denied permission. Re-show the OS prompt directly thereafter.
  static const _micExplainerShownKey = 'mic_permission_explainer_shown_v1';

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (!mounted) return false;

    if (status.isPermanentlyDenied) {
      final shouldOpen = await showMicPermissionSettings(context);
      if (shouldOpen) await openAppSettings();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_micExplainerShownKey) ?? false;

    if (!alreadyShown) {
      if (!mounted) return false;
      final shouldRequest = await showMicPermissionExplainer(context);
      if (!shouldRequest) return false;
      await prefs.setBool(_micExplainerShownKey, true);
    }

    final newStatus = await Permission.microphone.request();
    return newStatus.isGranted;
  }

  Future<void> _finishGame(BuildContext context, WidgetRef ref) async {
    if (_gameFinished) return; // Prevent double finish
    _gameFinished = true;

    debugPrint(
      '🎮 [SpeechGame] Finishing speech game stage, transitioning via getNextStage',
    );

    // Follow the same pattern as Flashcard and other game widgets:
    // Reset currentWordIndexProvider and transition to next game stage
    ref.read(currentWordIndexProvider.notifier).set(0);
    final stage = ref.read(gameStageProvider);
    ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
  }

  /// Unity UIGame5: UIErrorSpeech dialog — shown when word not recognized correctly
  void _showSpeechErrorDialog(
    BuildContext context,
    WidgetRef ref,
    SpeechGameNotifier controller, {
    required String expectedWord,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 56),
                SizedBox(height: 16),
                Text(
                  'Speech_not_recognized'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202939),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${"Expected_word".tr()}: "$expectedWord"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF697586)),
                ),
                SizedBox(height: 24),
                // Unity: UINextRepeat2 — retry recording
                MyButton(
                  backButtonColor: Color(0xFFEDAC10),
                  buttonColor: Color(0xFFFEDF47),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _retryCount++;
                    setState(() {
                      micContainerColor = Colors.blue;
                      micContainerBorderColor = Color(0xFF175CD3);
                    });
                  },
                  child: Center(
                    child: Text(
                      'retry'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                // Unity: UIContinueWord — skip this word (mark as incorrect)
                MyButton(
                  backButtonColor: Color(0xFF15824F),
                  buttonColor: Color(0xFF20CD7E),
                  onPressed: () async {
                    // Play wrong sound and wait for it to finish before
                    // starting the next word audio — otherwise they overlap.
                    try {
                      await AudioHelper.playWrong(awaitCompletion: true);
                    } catch (_) {}
                    // Mark as incorrect and advance
                    ref
                        .read(dotsProvider.notifier)
                        .markAnswer(isCorrect: false);
                    final freshGame = ref.read(speechGameProvider);
                    ref
                        .read(gameResultProvider.notifier)
                        .addResult(
                          word: freshGame.currentWord.word,
                          translation: freshGame.currentWord.translation,
                          isCorrect: false,
                          gameIndex: 5,
                          wordId: freshGame.currentWord.id,
                          gameName: GameNames.sayTheWord,
                          overwrite: true,
                          pronScore: 0,
                        );

                    Navigator.pop(ctx);
                    _retryCount = 0;
                    debugPrint(
                      '🔍 [ErrorDialog Continue] freshGame: idx=${freshGame.idx}, baseIndex=${freshGame.baseIndex}, words.length=${freshGame.words.length}, check=${freshGame.baseIndex + freshGame.idx + 1} >= ${freshGame.words.length}',
                    );
                    if (freshGame.baseIndex + freshGame.idx + 1 >=
                        freshGame.words.length) {
                      _finishGame(context, ref);
                    } else {
                      controller.next();
                    }
                    AudioHelper.playWord(
                      player,
                      '',
                      '${controller.state.currentWord.word}.mp3',
                      categoryId: controller.state.currentWord.categoryId,
                    );
                    setState(() {
                      micContainerColor = Colors.blue;
                      micContainerBorderColor = Color(0xFF175CD3);
                    });
                  },
                  child: Center(
                    child: Text(
                      'next'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ZipResourceLoader.clear();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(speechGameProvider);
    final controller = ref.read(speechGameProvider.notifier);
    final gameMode = ref.watch(gameModeProvider);
    final startIndex = ref.watch(currentWordIndexProvider);
    final words = ref.watch(learningWordsProvider);
    final currentWord = words[startIndex];
    final localIndex = ref.watch(localChoiceIndexProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final topCardHeight = (screenHeight * 0.22).clamp(140.0, 230.0);
    final bottomCardHeight = (screenHeight * 0.25).clamp(160.0, 230.0);
    if (gameMode == GameMode.speech) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // === Top Card (Grey) — subtitle + translation ===
                    Container(
                      width: double.infinity,
                      height: topCardHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(17),
                          topRight: Radius.circular(17),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Color.fromARGB(255, 210, 215, 221),
                            width: 0.5,
                          ),
                          left: BorderSide(
                            color: Color.fromARGB(255, 210, 215, 221),
                            width: 0.5,
                          ),
                          right: BorderSide(
                            color: Color.fromARGB(255, 210, 215, 221),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Word_pronunciation'.tr(),
                            style: AppTextStyles.whiteTextStyle.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF697586),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            game.currentWord.translation,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF202939),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.volume_up_rounded,
                              size: 55,
                              color: Color(0xFF2E90FA),
                            ),
                            onPressed: () async {
                              // Stop recording if active, so speaker audio isn't captured
                              if (_isRecording) {
                                _pulseController.stop();
                                _pulseController.reset();
                                await _speech.stopRecording();
                                setState(() {
                                  _isRecording = false;
                                  micContainerColor = Colors.blue;
                                  micContainerBorderColor = Color(0xFF175CD3);
                                });
                              }
                              setState(() => _isPlayingAudio = true);

                              await AudioHelper.playWord(
                                player,
                                '',
                                '${game.currentWord.word}.mp3',
                                categoryId: game.currentWord.categoryId,
                              );

                              // Wait for audio to finish (approx 2 sec)
                              await Future.delayed(const Duration(seconds: 2));
                              if (mounted) {
                                setState(() => _isPlayingAudio = false);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(color: Color(0xFFEEF2F6), height: 0),
                    // === Bottom Card (White) — volume + mic button ===
                    Container(
                      height: bottomCardHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Color.fromARGB(255, 210, 215, 221),
                            width: 4,
                          ),
                          left: BorderSide(
                            color: Color.fromARGB(255, 210, 215, 221),
                            width: 0.5,
                          ),
                          right: BorderSide(
                            color: Color.fromARGB(255, 210, 215, 221),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 4),
                          SizedBox(height: 12),
                          // Статуси сабт
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isAnalyzing
                                  ? '${"Analyzing".tr()}...'
                                  : _isRecording
                                  ? 'recording'.tr()
                                  : 'tap_to_record'.tr(),
                              key: ValueKey(
                                _isAnalyzing
                                    ? 'processing'
                                    : (_isRecording ? 'recording' : 'idle'),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _isAnalyzing
                                    ? Colors.orange
                                    : _isRecording
                                    ? Colors.red
                                    : const Color(0xFF697586),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Microphone button
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                // Пульсирующие кольца при записи (мисли battle)
                                if (_isRecording) ...[
                                  // Внешнее кольцо
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        width:
                                            120 + (35 * _pulseController.value),
                                        height:
                                            120 + (35 * _pulseController.value),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withValues(
                                            alpha:
                                                0.08 *
                                                (1.0 - _pulseController.value),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Внутреннее кольцо
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        width:
                                            120 + (18 * _pulseController.value),
                                        height:
                                            120 + (18 * _pulseController.value),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withValues(
                                            alpha:
                                                0.12 *
                                                (1.0 - _pulseController.value),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                                // Кнопка микрофона
                                GestureDetector(
                                  onTap: _isPlayingAudio
                                      ? null
                                      : null, // placeholder — onPressed logic below
                                  child: AnimatedScale(
                                    scale: _isRecording ? 1.05 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOutSine,
                                    child: MyButton(
                                      width: 95,
                                      height: 95,
                                      borderRadius: 60,
                                      buttonColor: micContainerColor,
                                      backButtonColor: micContainerBorderColor,
                                      depth: 5,
                                      padding: EdgeInsets.zero,
                                      onPressed:
                                          (_isPlayingAudio ||
                                              _gameFinished ||
                                              _isAnalyzing)
                                          ? null
                                          : () async {
                                              if (await _ensureMicrophonePermission()) {
                                                setState(() {
                                                  _isRecording = true;
                                                  micContainerColor =
                                                      Colors.red;
                                                  micContainerBorderColor =
                                                      Colors.red.shade700;
                                                });
                                                _pulseController.repeat();

                                                try {
                                                  // Unity: UIPlayClip.interactable = false
                                                  // Stop any playing audio and mute so mic doesn't pick up speaker
                                                  await player.stop();
                                                  await player.setVolume(0);
                                                  await AudioHelper.stopSfx();

                                                  await _speech
                                                      .startRecording();

                                                  // Smart silence detection (мисли battle):
                                                  // Вақте ки 600ms хомӯшӣ баъди овоз — қатъ мекунем
                                                  const maxDuration = Duration(seconds: 4);
                                                  const silenceThreshold = Duration(milliseconds: 600);
                                                  const checkInterval = Duration(milliseconds: 100);
                                                  const voiceThreshold = -35.0;

                                                  final stopwatch = Stopwatch()..start();
                                                  bool voiceDetected = false;
                                                  DateTime? lastVoiceTime;

                                                  while (stopwatch.elapsed < maxDuration) {
                                                    try {
                                                      final amp = await _speech.recorder.getAmplitude();
                                                      if (amp.current > voiceThreshold) {
                                                        voiceDetected = true;
                                                        lastVoiceTime = DateTime.now();
                                                      } else if (voiceDetected && lastVoiceTime != null) {
                                                        final silenceDuration = DateTime.now().difference(lastVoiceTime);
                                                        if (silenceDuration >= silenceThreshold) {
                                                          break;
                                                        }
                                                      }
                                                    } catch (_) {}
                                                    await Future.delayed(checkInterval);
                                                  }

                                                  final audioPath =
                                                      await _speech
                                                          .stopRecording();

                                                  // Restore volume after recording
                                                  await player.setVolume(1.0);

                                                  _pulseController.stop();
                                                  _pulseController.reset();

                                                  setState(() {
                                                    _isRecording = false;
                                                    _isAnalyzing = true;
                                                    micContainerColor =
                                                        Colors.orange;
                                                    micContainerBorderColor =
                                                        Colors.orange.shade700;
                                                  });

                                                  if (audioPath != null) {
                                                    final azureResult =
                                                        await _speech
                                                            .assessPronunciation(
                                                              referenceText: game
                                                                  .currentWord
                                                                  .word,
                                                              audioFilePath:
                                                                  audioPath,
                                                            );

                                                    final txt =
                                                        azureResult
                                                            .displayText ??
                                                        game.currentWord.word;
                                                    controller.setResult(txt);

                                                    setState(() {
                                                      _isAnalyzing = false;
                                                      micContainerColor =
                                                          Colors.blue;
                                                      micContainerBorderColor =
                                                          Color(0xFF175CD3);
                                                    });

                                                    // ── Unity UIGame5 parity: word mismatch check ──
                                                    // Azure forced alignment: referenceText causes Azure to always return
                                                    // the expected word in Words[] — even when pronunciation is terrible.
                                                    // So we check AZURE'S Words array (not displayText) for true recognition.
                                                    final expectedWord =
                                                        game.currentWord.word;

                                                    // Check if Azure returned words from forced alignment
                                                    final hasAzureWords =
                                                        azureResult.isSuccess &&
                                                        azureResult
                                                            .words
                                                            .isNotEmpty;

                                                    // Azure words match expected? (forced alignment gives the reference word)
                                                    final azureWordText =
                                                        azureResult.words
                                                            .map((w) => w.word)
                                                            .join(' ')
                                                            .trim()
                                                            .toLowerCase();
                                                    final expectedLexical =
                                                        expectedWord
                                                            .trim()
                                                            .toLowerCase();
                                                    final wordMatches =
                                                        hasAzureWords &&
                                                        azureWordText ==
                                                            expectedLexical;

                                                    debugPrint(
                                                      '🔍 [Speech] azureWords="$azureWordText", expected="$expectedLexical", hasWords=$hasAzureWords, matches=$wordMatches',
                                                    );

                                                    if (!azureResult
                                                            .isSuccess ||
                                                        !hasAzureWords) {
                                                      // True recognition failure — Azure couldn't force-align at all
                                                      debugPrint(
                                                        '❌ [Speech] Azure recognition failed completely',
                                                      );
                                                      _showSpeechErrorDialog(
                                                        context,
                                                        ref,
                                                        controller,
                                                        expectedWord:
                                                            expectedWord,
                                                      );
                                                    } else {
                                                      // Unity: UIResults — show pronunciation scores
                                                      final accuracyScore =
                                                          azureResult
                                                              .accuracyScore;
                                                      debugPrint(
                                                        '✅ [Speech] Word matched! AccuracyScore=$accuracyScore',
                                                      );

                                                      showPronunciationEvaluationDialog(
                                                        context,
                                                        expectedWord:
                                                            expectedWord,
                                                        actualWord: txt,
                                                        azureResult:
                                                            azureResult,
                                                        // Unity: hide retry when score >= 98 or retried 3 times
                                                        showRetry:
                                                            accuracyScore <
                                                                98 &&
                                                            _retryCount < 3,
                                                        onRetry: () {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          _retryCount++;
                                                          setState(() {
                                                            micContainerColor =
                                                                Colors.blue;
                                                            micContainerBorderColor =
                                                                Color(
                                                                  0xFF175CD3,
                                                                );
                                                          });
                                                        },
                                                        onNext: () async {
                                                          // Unity: AccuracyScore >= 75 = correct
                                                          final isCorrect =
                                                              accuracyScore >=
                                                              75;
                                                          // Play correct/incorrect sound and wait
                                                          // for it to finish — prevents overlap
                                                          // with the next word's audio.
                                                          try {
                                                            if (isCorrect) {
                                                              await AudioHelper.playCorrect(
                                                                awaitCompletion:
                                                                    true,
                                                              );
                                                            } else {
                                                              await AudioHelper.playWrong(
                                                                awaitCompletion:
                                                                    true,
                                                              );
                                                            }
                                                          } catch (_) {}
                                                          ref
                                                              .read(
                                                                dotsProvider
                                                                    .notifier,
                                                              )
                                                              .markAnswer(
                                                                isCorrect:
                                                                    isCorrect,
                                                              );

                                                          final freshGame = ref
                                                              .read(
                                                                speechGameProvider,
                                                              );
                                                          ref
                                                              .read(
                                                                gameResultProvider
                                                                    .notifier,
                                                              )
                                                              .addResult(
                                                                word: freshGame
                                                                    .currentWord
                                                                    .word,
                                                                translation: freshGame
                                                                    .currentWord
                                                                    .translation,
                                                                isCorrect:
                                                                    isCorrect,
                                                                gameIndex: 5,
                                                                wordId: freshGame
                                                                    .currentWord
                                                                    .id,
                                                                gameName: GameNames
                                                                    .sayTheWord,
                                                                overwrite: true,
                                                                pronScore:
                                                                    accuracyScore
                                                                        .toInt(),
                                                              );

                                                          // Unity: SetErrorWord if AccuracyScore < 80
                                                          if (!isCorrect) {
                                                            debugPrint(
                                                              '⚠️ [Speech] AccuracyScore=$accuracyScore < 80, marking as error',
                                                            );
                                                          }

                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          _retryCount =
                                                              0; // reset for next word
                                                          debugPrint(
                                                            '🔍 [onNext] freshGame: idx=${freshGame.idx}, baseIndex=${freshGame.baseIndex}, words.length=${freshGame.words.length}',
                                                          );
                                                          if (freshGame
                                                                      .baseIndex +
                                                                  freshGame
                                                                      .idx +
                                                                  1 >=
                                                              freshGame
                                                                  .words
                                                                  .length) {
                                                            _finishGame(
                                                              context,
                                                              ref,
                                                            );
                                                          } else {
                                                            controller.next();
                                                          }

                                                          AudioHelper.playWord(
                                                            player,
                                                            '',
                                                            '${controller.state.currentWord.word}.mp3',
                                                            categoryId:
                                                                controller
                                                                    .state
                                                                    .currentWord
                                                                    .categoryId,
                                                          );
                                                          setState(() {
                                                            micContainerColor =
                                                                Colors.blue;
                                                            micContainerBorderColor =
                                                                Color(
                                                                  0xFF175CD3,
                                                                );
                                                          });
                                                        },
                                                      );
                                                    }
                                                  } else {
                                                    // Audio not captured — show "Nothing heard" notification
                                                    setState(() {
                                                      micContainerColor =
                                                          Colors.blue;
                                                      micContainerBorderColor =
                                                          Color(0xFF175CD3);
                                                    });
                                                    showModalBottomSheet(
                                                      context: context,
                                                      backgroundColor:
                                                          Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    20,
                                                                  ),
                                                            ),
                                                      ),
                                                      builder: (ctx) => Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 24,
                                                              vertical: 24,
                                                            ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'nothing_heard'
                                                                  .tr(),
                                                              style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                  0xFF202939,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              height: 20,
                                                            ),
                                                            SizedBox(
                                                              width: double
                                                                  .infinity,
                                                              height: 50,
                                                              child: ElevatedButton(
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      Color(
                                                                        0xFF12B76A,
                                                                      ),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          14,
                                                                        ),
                                                                  ),
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                    ),
                                                                child: Text(
                                                                  'try_one_more_time'
                                                                      .tr(),
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              height: 16,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  debugPrint(
                                                    '❌ Speech assessment error: $e',
                                                  );
                                                  // Restore volume on error
                                                  await player.setVolume(1.0);
                                                  _pulseController.stop();
                                                  _pulseController.reset();
                                                  setState(() {
                                                    _isRecording = false;
                                                    _isAnalyzing = false;
                                                    micContainerColor =
                                                        Colors.blue;
                                                    micContainerBorderColor =
                                                        Color(0xFF175CD3);
                                                  });
                                                }
                                              }
                                            },
                                      child: _isAnalyzing
                                          ? const SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 4,
                                              ),
                                            )
                                          : Image.asset(
                                              'assets/images/microphone-2.png',
                                              height: 60,
                                              width: 50,
                                              color: Colors.white,
                                            ),
                                    ), // MyButton
                                  ), // AnimatedScale
                                ), // GestureDetector
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // "Не могу сейчас слушать" link at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextButton(
              onPressed: () {
                // Reset to start from the first word
                ref.read(currentWordIndexProvider.notifier).set(0);
                ref.invalidate(speechGameProvider);
                ref.read(gameModeProvider.notifier).set(GameMode.flashcard);
              },
              child: Text(
                ' ${'I_am_unable_to_speak_right_now'.tr()}',
                style: AppTextStyles.bigTextStyle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: const Color.fromARGB(255, 27, 131, 216),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // Build 4 options: 1 correct + 3 dummies
    // Only regenerate when the current word changes (not on every rebuild)
    if (_lastWordId != game.currentWord.id) {
      _lastWordId = game.currentWord.id;
      final pool = ref.read(dummyWordPoolProvider);
      if (pool.isNotEmpty) {
        final dummies = ref
            .read(dummyWordPoolProvider.notifier)
            .pickForWord(game.currentWord, count: 3);
        _cachedOptions = [game.currentWord, ...dummies]..shuffle();
      } else {
        // Fallback: use learning words
        _cachedOptions = [...game.words]..shuffle();
        if (_cachedOptions.length > 4)
          _cachedOptions = _cachedOptions.sublist(0, 4);
        // Ensure correct word is included
        if (!_cachedOptions.any((w) => w.id == game.currentWord.id)) {
          _cachedOptions[0] = game.currentWord;
          _cachedOptions.shuffle();
        }
      }
    }
    final options = _cachedOptions;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: WordsBox(
          isVolume: false,
          topColorContainer: Color(0xFFEEF2F6),
          topWidthContainer: 90,
          topTextContainer: "Choose the correct translation".tr(),
          topWordContainer: Text(
            game.currentWord.displayWord,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202939),
            ),
          ),
          isIcon: true,
          onPressed: () {
            HapticFeedback.lightImpact();
          },
          child: Column(
            children: [
              Divider(color: Colors.white, height: 0),
              for (int i = 0; i < options.length; i++) ...[
                bbuildLikeTile(
                  word: options[i],
                  correctWord: game.currentWord,
                  ref: ref,
                  isLast: i == options.length - 1 ? 1 : 0,
                  context: context,
                ),
                Divider(color: Color(0xFFEEF2F6), height: 0),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget bbuildLikeTile({
    required Word word, // <- показываемое слово (то, что в списке)
    required Word correctWord, // <- правильное слово (game.currentWord)
    required WidgetRef ref,
    required int isLast,
    required BuildContext context,
  }) {
    final selectedAnswer = ref.watch(selectedAnswerProvider);
    final correctAnswer = correctWord.translation;
    final gameState = ref.read(speechGameProvider);
    final startIndex = ref.watch(currentWordIndexProvider);
    final isLastWord = gameState.idx + startIndex + 1 >= gameState.words.length;
    Color tileColor = Colors.white;

    if (selectedAnswer != null) {
      if (word.translation == correctAnswer &&
          word.translation == selectedAnswer) {
        tileColor = const Color(0xFF22C55E);
      } else if (word.translation == selectedAnswer &&
          word.translation != correctAnswer) {
        tileColor = const Color(0xFFEF4444);
      }
    }

    return GestureDetector(
      onTap: () async {
        ref.read(selectedAnswerProvider.notifier).set(word.translation);
        final isCorrect = word.translation == correctAnswer;
        // Play sound using AudioHelper (proper AudioContext config)
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
          await showAnswerFeedback(
            context,
            userAnswer: word.word,
            userTranslation: word.translation,
            correctAnswer: correctWord.word,
            correctTranslation: correctWord.translation,
            categoryId: correctWord.categoryId,
          );
        }
        if (!mounted) return;
        // Clear selection and advance
        ref.read(selectedAnswerProvider.notifier).set(null);
        ref.read(showCorrectnessLabelProvider.notifier).set(true);
        ref.read(dotsProvider.notifier).markAnswer(isCorrect: isCorrect);
        ref
            .read(gameResultProvider.notifier)
            .addResult(
              word: correctWord.word,
              translation: correctWord.translation,
              isCorrect: isCorrect,
              gameIndex: 1,
              wordId: correctWord.id,
              gameName: GameNames.sayTheWord, // Unity: 'Say the word'
            );
        if (isLastWord) {
          _finishGame(context, ref);
        } else {
          ref.read(speechGameProvider.notifier).next();
          // Force regenerate options for next word
          _lastWordId = null;
        }

        ref.read(showCorrectnessLabelProvider.notifier).set(null);
      },
      child: likeListTile(
        word.translation,
        colorr: tileColor,
        isLasstt: isLast,
      ),
    );
  }
}
