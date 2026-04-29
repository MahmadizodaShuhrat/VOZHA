import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/feature/battle/data/battle_phase.dart';
import 'package:vozhaomuz/feature/battle/data/battle_state.dart';
import 'package:vozhaomuz/feature/battle/data/question_data.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/result_speech_game_page.dart';
import 'package:vozhaomuz/core/utils/speech_bridge.dart';

/// Game 5: Произнеси слово (speech recognition через Azure).
class PronounceWordGame extends ConsumerStatefulWidget {
  final QuestionData question;
  final AudioPlayer audioPlayer;
  final void Function(bool isCorrect) onAnswer;
  final void Function(bool isCorrect) playAnswerSound;

  const PronounceWordGame({
    super.key,
    required this.question,
    required this.audioPlayer,
    required this.onAnswer,
    required this.playAnswerSound,
  });

  @override
  ConsumerState<PronounceWordGame> createState() =>
      _PronounceWordGameState();
}

class _PronounceWordGameState extends ConsumerState<PronounceWordGame>
    with SingleTickerProviderStateMixin {
  final SpeechBridge _speech = SpeechBridge();
  bool _speechInitialized = false;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  bool _answering = false;
  bool _isProcessing = false;
  bool _disposed = false; // Prevents dialog after battle ends
  bool _dialogOpen = false; // Track if pronunciation dialog is showing
  int _retryCount = 0; // Max 3 retries per word (Unity parity)
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.init(
        key: 'c66a1cf12d114cdd82f37f652f34db1b',
        region: 'eastasia',
      );
      _speechInitialized = true;
    } catch (e) {
      debugPrint('⚠️ SpeechBridge init error: $e');
    }
  }

  /// Pronunciation evaluation dialog-ро бехатар мепӯшад. Тавассути
  /// **root navigator** мерасад (чунки dialog бо `useRootNavigator: true`
  /// кушода мешавад) ва try/catch барои ҳолате ки dialog аллакай дар
  /// stack нест.
  void _safelyCloseDialog() {
    if (!_dialogOpen) return;
    _dialogOpen = false;
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      debugPrint('PronounceWordGame: dialog close failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant PronounceWordGame old) {
    super.didUpdateWidget(old);
    if (old.question != widget.question) {
      _isRecording = false;
      _isPlayingAudio = false;
      _answering = false;
      _isProcessing = false;
      _retryCount = 0;
      _pulseController.stop();
      _pulseController.reset();
      // Агар backend саволро пеш бурд ва dialog ҳанӯз кушода аст —
      // онро мепӯшем то корбар якҷоя бо саволи нав dialog-и кӯҳна
      // набинад.
      if (_dialogOpen) _safelyCloseDialog();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pulseController.dispose();
    // Close pronunciation dialog if still open when battle ends.
    _safelyCloseDialog();
    // Stop recording if active
    if (_isRecording) {
      _speech.stopRecording();
    }
    super.dispose();
  }

  void _handleSpeechResult(bool isCorrect) {
    HapticFeedback.lightImpact();
    widget.playAnswerSound(isCorrect);
    setState(() => _answering = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _answering = false);
      widget.onAnswer(isCorrect);
    });
  }

  Future<void> _handleMicTap(QuestionData q) async {
    if (!_speechInitialized) {
      _handleSpeechResult(false);
      return;
    }

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return;

    if (!mounted) return;
    setState(() {
      _isRecording = true;
    });
    _pulseController.repeat();

    try {
      await _speech.startRecording();

      // Smart silence detection: stop when 600ms silence after voice
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

      final audioPath = await _speech.stopRecording();

      _pulseController.stop();
      _pulseController.reset();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      if (audioPath != null && mounted) {
        final azureResult = await _speech.assessPronunciation(
          referenceText: q.correctAnswer,
          audioFilePath: audioPath,
        );

        final isCorrect = azureResult.isSuccess && azureResult.accuracyScore >= 75;

        // If battle already ended (widget disposed), skip dialog and just submit
        if (_disposed || !mounted) {
          return;
        }

        setState(() => _isProcessing = false);
        _dialogOpen = true;
        showPronunciationEvaluationDialog(
          context,
          expectedWord: q.correctAnswer,
          actualWord: azureResult.displayText ?? q.correctAnswer,
          azureResult: azureResult,
          showRetry: azureResult.accuracyScore < 98 && _retryCount < 3,
          onRetry: () {
            _dialogOpen = false;
            if (mounted && !_disposed) {
              try {
                Navigator.of(context, rootNavigator: true).pop();
              } catch (_) {}
            }
            _retryCount++;
          },
          onNext: () {
            _dialogOpen = false;
            if (mounted && !_disposed) {
              try {
                Navigator.of(context, rootNavigator: true).pop();
              } catch (_) {}
            }
            _handleSpeechResult(isCorrect);
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('battle_game_record_error'.tr())),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Speech assessment error: $e');
      _pulseController.stop();
      _pulseController.reset();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
      _handleSpeechResult(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Агар battle phase аз `playing` хориҷ шуд (рақиб баромад,
    // delete_room, ё timer ба охир расид) ва pronunciation dialog ҳанӯз
    // кушода аст — мепӯшем. Бе ин корбар дар dialog-и санҷиш мегирад
    // ҳарчанд бозӣ аллакай тамом шуд.
    ref.listen<BattleState>(battleProvider, (prev, next) {
      final wasPlaying = prev?.phase == BattlePhase.playing;
      final stoppedPlaying = next.phase != BattlePhase.playing;
      if (wasPlaying && stoppedPlaying && _dialogOpen) {
        _safelyCloseDialog();
      }
    });

    final q = widget.question;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFEEF2F6), width: 2),
              boxShadow: [
                BoxShadow(color: Color(0xFFEEF2F6), offset: Offset(0, 4.h)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Верхняя зона: перевод + 🔊
                Container(
                  height: 140.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color(0xffEEF2F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10.r),
                      topRight: Radius.circular(10.r),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'battle_game_pronounce'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF697586),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        q.word,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      GestureDetector(
                        onTap: () {
                          if (q.audioPath != null && !_isRecording) {
                            setState(() => _isPlayingAudio = true);
                            AudioHelper.playWord(
                              widget.audioPlayer,
                              q.categoryName ?? '',
                              q.audioPath!,
                            ).then((_) {
                              Future.delayed(const Duration(seconds: 1), () {
                                if (mounted)
                                  setState(() => _isPlayingAudio = false);
                              });
                            });
                          }
                        },
                        child: Icon(
                          Icons.volume_up_rounded,
                          size: 36.sp,
                          color: const Color(0xFF2E90FA),
                        ),
                      ),
                    ],
                  ),
                ),
                // Нижняя зона: кнопка микрофона
                Container(
                  // `.h` scales with screen_util; on foldables unfolded
                  // to a landscape tablet shape that can be only ~300 pt
                  // tall, 200.h collapses to ~150 pt and the mic button
                  // falls below the 48 pt touch target. Clamp keeps it
                  // usable regardless of device shape.
                  constraints: BoxConstraints(
                    minHeight: 180,
                    maxHeight: (200.h).clamp(180.0, 240.0),
                  ),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10.r),
                      bottomRight: Radius.circular(10.r),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Статус текст
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isProcessing
                              ? '⏳ ${"Analyzing".tr()}...'
                              : _isRecording
                              ? 'battle_game_recording'.tr()
                              : 'battle_game_tap_to_record'.tr(),
                          key: ValueKey(
                            _isProcessing
                                ? 'processing'
                                : (_isRecording ? 'recording' : 'idle'),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: _isProcessing
                                ? Colors.orange
                                : _isRecording
                                ? Colors.red
                                : const Color(0xFF697586),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: 150.w,
                        height: 150.w,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Пульсирующие кольца при записи (два кольца)
                            if (_isRecording) ...[
                              // Внешнее кольцо
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width:
                                        120.w + (35.w * _pulseController.value),
                                    height:
                                        120.w + (35.w * _pulseController.value),
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
                                        120.w + (18.w * _pulseController.value),
                                    height:
                                        120.w + (18.w * _pulseController.value),
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
                              onTap:
                                  (_answering ||
                                      _isPlayingAudio ||
                                      _isProcessing)
                                  ? null
                                  : () => _handleMicTap(q),
                              child: AnimatedScale(
                                scale: _isRecording ? 1.05 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutSine,
                                child: Container(
                                  width: 100.w,
                                  height: 100.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _isProcessing
                                          ? [
                                              const Color(0xFFFF9800),
                                              const Color(0xFFE65100),
                                            ]
                                          : _isRecording
                                          ? [
                                              const Color(0xFFFF4444),
                                              const Color(0xFFCC0000),
                                            ]
                                          : [
                                              const Color(0xFF41A4FF),
                                              const Color(0xFF2E90FA),
                                            ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_isRecording
                                                    ? const Color(0xFFFF4444)
                                                    : const Color(0xFF41A4FF))
                                                .withValues(alpha: 0.4),
                                        blurRadius: 16.r,
                                        spreadRadius: 2.r,
                                        offset: Offset(0, 6.h),
                                      ),
                                      BoxShadow(
                                        color:
                                            (_isRecording
                                                    ? const Color(0xFFFF4444)
                                                    : const Color(0xFF41A4FF))
                                                .withValues(alpha: 0.15),
                                        blurRadius: 30.r,
                                        spreadRadius: 4.r,
                                        offset: Offset(0, 10.h),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _isProcessing
                                        ? SizedBox(
                                            width: 40.w,
                                            height: 40.w,
                                            child:
                                                const CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                ),
                                          )
                                        : Icon(
                                            _isRecording
                                                ? Icons.stop_rounded
                                                : Icons.mic_rounded,
                                            key: ValueKey(_isRecording),
                                            color: Colors.white,
                                            size: 44.sp,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
