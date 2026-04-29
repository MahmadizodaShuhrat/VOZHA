import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:vozhaomuz/core/services/openai_service.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// SpeakingWithAI game — record voice answers and get AI evaluation.
/// Unity: UISpeakingWithAI + SpeakingWithAIUI
///
/// Per-question: record button → inline audio player → AI score + mistakes.
/// Premium design matching Unity: pulse animation, color transitions, modals.
class SpeakingWithAIGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const SpeakingWithAIGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<SpeakingWithAIGameWidget> createState() =>
      _SpeakingWithAIGameWidgetState();
}

class _SpeakingWithAIGameWidgetState extends State<SpeakingWithAIGameWidget>
    with TickerProviderStateMixin {
  late List<String> _questions;
  final AudioRecorder _recorder = AudioRecorder();

  // Per-question state
  late List<String?> _recordedPaths; // null = not recorded
  late List<double> _scores; // AI scores (0.0 - 1.0)
  late List<String?> _mistakes; // AI mistake text
  late List<bool> _isPlaying; // playback state

  // Recording state
  int _recordingIndex = -1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Playback
  final AudioPlayer _player = AudioPlayer();
  int _playingIndex = -1;
  StreamSubscription<void>? _completeSub;

  // Analysis state
  bool _submitted = false;
  bool _analyzing = false;

  // Story text
  String? _storyText;
  bool _storyExpanded = true;

  @override
  void initState() {
    super.initState();
    _questions = widget.question.dataSources.map((ds) => ds.text).toList();
    _recordedPaths = List.generate(_questions.length, (_) => null);
    _scores = List.generate(_questions.length, (_) => 0.0);
    _mistakes = List.generate(_questions.length, (_) => null);
    _isPlaying = List.generate(_questions.length, (_) => false);

    // Unity: DOScale(1.1f, 0.5f).SetLoops(-1, LoopType.Yoyo).SetEase(InOutSine)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Hold the subscription so we can cancel it in dispose() — otherwise
    // the callback can fire after the widget is gone (e.g. user backs
    // out mid-playback) and hit setState on a dead state.
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          if (_playingIndex >= 0) _isPlaying[_playingIndex] = false;
          _playingIndex = -1;
        });
      }
    });

    _loadStoryText();
  }

  /// Load the story text from text_file_name if available
  Future<void> _loadStoryText() async {
    var fileName = widget.question.textFileName;
    if (fileName == null || fileName.isEmpty) return;

    // Fix double extension (.txt.txt → .txt)
    if (fileName.endsWith('.txt.txt')) {
      fileName = fileName.replaceAll('.txt.txt', '.txt');
    }

    try {
      final path = '${widget.basePath}/$fileName';
      String text;
      // If basePath is a local file system path, read as File
      if (path.startsWith('/') || path.startsWith('C:')) {
        final file = File(path);
        if (await file.exists()) {
          text = await file.readAsString();
        } else {
          debugPrint('⚠️ Story text file not found: $path');
          return;
        }
      } else {
        text = await rootBundle.loadString(path);
      }
      if (mounted) setState(() => _storyText = text);
    } catch (e) {
      debugPrint('⚠️ Could not load story text: $e');
    }
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _pulseController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  bool get _allRecorded => _recordedPaths.every((p) => p != null);
  bool get _isRecording => _recordingIndex >= 0;

  // ════════════════════════════════════════
  //  STORY SECTION
  // ════════════════════════════════════════
  Widget _buildStorySection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _storyExpanded = !_storyExpanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEFF6FF), Color(0xFFF0F9FF)],
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(14),
                  bottom: Radius.circular(_storyExpanded ? 0 : 14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\u04b2\u0438\u043a\u043e\u044f',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        Text(
                          '\u0410\u0432\u0432\u0430\u043b \u0445\u043e\u043d\u0435\u0434, \u0431\u0430\u044a\u0434 \u0431\u0430 \u0441\u0430\u0432\u043e\u043b\u04b3\u043e \u04b7\u0430\u0432\u043e\u0431 \u0434\u0438\u04b3\u0435\u0434',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF60A5FA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _storyExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 250),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: SingleChildScrollView(
                child: RichText(
                  text: _parseHtmlText(
                    _storyText!,
                    const TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _storyExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  HTML PARSER
  // ════════════════════════════════════════
  TextSpan _parseHtmlText(String html, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'<(/?)(b|i|strong|em)>', caseSensitive: false);
    int lastEnd = 0;
    bool isBold = false;
    bool isItalic = false;

    for (final match in regex.allMatches(html)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: html.substring(lastEnd, match.start),
          style: baseStyle.copyWith(
            fontWeight: isBold ? FontWeight.w700 : baseStyle.fontWeight,
            fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
          ),
        ));
      }
      final isClosing = match.group(1) == '/';
      final tag = match.group(2)!.toLowerCase();
      if (tag == 'b' || tag == 'strong') isBold = !isClosing;
      else if (tag == 'i' || tag == 'em') isItalic = !isClosing;
      lastEnd = match.end;
    }

    if (lastEnd < html.length) {
      spans.add(TextSpan(
        text: html.substring(lastEnd),
        style: baseStyle.copyWith(
          fontWeight: isBold ? FontWeight.w700 : baseStyle.fontWeight,
          fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
        ),
      ));
    }

    return spans.isEmpty ? TextSpan(text: html, style: baseStyle) : TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Story text (read before answering) ───
        if (_storyText != null && _storyText!.isNotEmpty) _buildStorySection(),

        // ─── Title (Unity: UITitle) ───
        if (widget.question.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.question.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
                height: 1.4,
              ),
            ),
          ),

        // ─── Speaking instruction banner ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0F7FF), Color(0xFFE8F4FD)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB3D9FF), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF41A4FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Color(0xFF41A4FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'record_speaking_hint'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A6FA5),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Per-question blocks ───
        for (int i = 0; i < _questions.length; i++) ...[
          _buildQuestionBlock(i),
          if (i < _questions.length - 1) const SizedBox(height: 16),
        ],

        const SizedBox(height: 20),

        // ─── CHECK button (Unity: UIButtonCheck) ───
        if (!_submitted)
          SizedBox(
            width: double.infinity,
            child: _analyzing
                ? _buildAnalyzingIndicator()
                : MyButton(
                    height: 52,
                    borderRadius: 14,
                    buttonColor: _allRecorded
                        ? const Color(0xFF41A4FF)
                        : const Color(0xFFCCCCCC),
                    backButtonColor: _allRecorded
                        ? const Color(0xFF1570EF)
                        : const Color(0xFFB0B0B0),
                    onPressed: _allRecorded ? _analyzeAll : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'check'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════
  //  QUESTION BLOCK
  // ════════════════════════════════════════

  Widget _buildQuestionBlock(int index) {
    final hasRecording = _recordedPaths[index] != null;
    final isThisRecording = _recordingIndex == index;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isThisRecording
              ? const Color(0xFFFF4444).withOpacity(0.4)
              : _submitted && _scores[index] >= 0.8
              ? const Color(0xFF1BD259).withOpacity(0.3)
              : const Color(0xFFE8ECF0),
          width: isThisRecording ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isThisRecording
                ? const Color(0xFFFF4444).withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Text(
            '${index + 1}. ${_questions[index]}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Record button or Audio player
          if (!_submitted)
            hasRecording ? _buildAudioPlayer(index) : _buildRecordButton(index),

          // Score badge (after analysis)
          if (_submitted) _buildScoreBadge(index),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  RECORD BUTTON (Unity: recordButtonPrefab)
  // ════════════════════════════════════════

  Widget _buildRecordButton(int index) {
    final isThisRecording = _recordingIndex == index;
    final isLocked = _isRecording && !isThisRecording;

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isThisRecording ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Column(
          children: [
            GestureDetector(
              onTap: isLocked ? null : () => _handleRecordTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Unity: idle=#41A4FF, recording=Red
                  color: isLocked
                      ? const Color(0xFFCCCCCC)
                      : isThisRecording
                      ? const Color(0xFFFF4444)
                      : const Color(0xFF41A4FF),
                  boxShadow: [
                    BoxShadow(
                      // Unity: idle=#1570EF, recording=#A12107
                      color: isThisRecording
                          ? const Color(0xFFA12107).withOpacity(0.35)
                          : const Color(0xFF1570EF).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isThisRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isThisRecording
                    ? const Color(0xFFFF4444)
                    : const Color(0xFF41A4FF),
              ),
              child: Text(
                isThisRecording
                    ? _formatDuration(_recordingSeconds)
                    : 'tap_to_record'.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  //  AUDIO PLAYER (Unity: UIAudioItem)
  // ════════════════════════════════════════

  Widget _buildAudioPlayer(int index) {
    final isPlaying = _isPlaying[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0E3FF)),
      ),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: () => _togglePlayback(index),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF41A4FF),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1570EF).withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF41A4FF),
                          const Color(0xFF41A4FF).withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'recorded'.tr(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF88A4C4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Delete button (Unity: OnClosed)
          GestureDetector(
            onTap: () => _deleteRecording(index),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4444).withOpacity(0.1),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFFF4444),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  SCORE BADGE (Unity: GetScoreLine)
  // ════════════════════════════════════════

  Widget _buildScoreBadge(int index) {
    final score = _scores[index];
    final isGood = score >= 0.8;
    final hasMistakes =
        _mistakes[index] != null && _mistakes[index]!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isGood
                      ? const Color(0xFFE5FFEE)
                      : const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isGood
                        ? const Color(0xFF1BD259)
                        : const Color(0xFFFF3700),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isGood
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 20,
                      color: isGood
                          ? const Color(0xFF1BD259)
                          : const Color(0xFFFF3700),
                    ),
                    const SizedBox(width: 8),
                    // Unity: "Оценка: 0.85/1"
                    Text(
                      '${'score'.tr()}: ${score.toStringAsFixed(2)}/1',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isGood
                            ? const Color(0xFF1BD259)
                            : const Color(0xFFFF3700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Mistake icon (Unity: UIMistakeIconPrefab)
            if (hasMistakes) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showMistakeModal(index),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFFF9800),
                    size: 22,
                  ),
                ),
              ),
            ],
          ],
        ),

        // Inline audio player (still playable after analysis)
        if (_recordedPaths[index] != null) ...[
          const SizedBox(height: 10),
          _buildAudioPlayer(index),
        ],
      ],
    );
  }

  // ════════════════════════════════════════
  //  ANALYZING INDICATOR
  // ════════════════════════════════════════

  Widget _buildAnalyzingIndicator() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB3D9FF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF41A4FF),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'analyzing'.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF41A4FF),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  RECORDING LOGIC
  // ════════════════════════════════════════

  Future<void> _handleRecordTap(int index) async {
    HapticFeedback.lightImpact();

    if (_isRecording) {
      if (_recordingIndex == index) {
        await _stopRecording();
      }
      return;
    }

    // Request mic permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('microphone_permission_denied'.tr()),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
      return;
    }

    await _startRecording(index);
  }

  Future<void> _startRecording(int index) async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/speaking_q${index}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        _recordingIndex = index;
        _recordingSeconds = 0;
      });

      // Start pulse animation
      _pulseController.repeat(reverse: true);

      // Start timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingSeconds++);
        }
      });
    } catch (e) {
      debugPrint('❌ Recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.value = 0;

    try {
      final path = await _recorder.stop();
      if (path != null && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _recordedPaths[_recordingIndex] = path;
          _recordingIndex = -1;
          _recordingSeconds = 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Stop recording error: $e');
      setState(() {
        _recordingIndex = -1;
        _recordingSeconds = 0;
      });
    }
  }

  void _deleteRecording(int index) {
    HapticFeedback.lightImpact();
    // Stop playback if playing this file
    if (_playingIndex == index) {
      _player.stop();
      _playingIndex = -1;
    }
    // Delete file
    final path = _recordedPaths[index];
    if (path != null) {
      File(path).deleteSync();
    }
    setState(() {
      _recordedPaths[index] = null;
      _isPlaying[index] = false;
    });
  }

  // ════════════════════════════════════════
  //  PLAYBACK LOGIC
  // ════════════════════════════════════════

  Future<void> _togglePlayback(int index) async {
    HapticFeedback.lightImpact();
    final path = _recordedPaths[index];
    if (path == null) return;

    // If already playing this, pause
    if (_playingIndex == index && _isPlaying[index]) {
      await _player.pause();
      setState(() => _isPlaying[index] = false);
      return;
    }

    // Stop any other playback
    if (_playingIndex >= 0 && _playingIndex != index) {
      await _player.stop();
      setState(() {
        _isPlaying[_playingIndex] = false;
      });
    }

    // Play
    _playingIndex = index;
    await _player.play(DeviceFileSource(path));
    setState(() => _isPlaying[index] = true);
  }

  // ════════════════════════════════════════
  //  AI ANALYSIS (Unity: StartAnalyze)
  // ════════════════════════════════════════

  Future<void> _analyzeAll() async {
    HapticFeedback.mediumImpact();
    setState(() => _analyzing = true);

    final List<bool> results = [];

    for (int i = 0; i < _questions.length; i++) {
      final audioPath = _recordedPaths[i];
      if (audioPath == null) {
        results.add(false);
        continue;
      }

      try {
        // Build prompt (Unity: basePrompt + language + story + question)
        final prompt = await OpenAIService.instance.buildSpeakingPrompt(
          questionText: _questions[i],
          storyText: _storyText,
          promptAdditional: widget.question.promptAdditional,
        );

        // Send to OpenAI
        final result = await OpenAIService.instance.sendSpeakingAIRequest(
          prompt,
          audioPath,
        );

        if (result.statusCode == 200) {
          final examResults = OpenAIService.instance.parseExamResults(
            result.response,
          );

          if (examResults.isNotEmpty) {
            final examResult = examResults.first;
            final score = examResult.score.clamp(0.0, 1.0);
            _scores[i] = score;
            _mistakes[i] = examResult.mistakes;
            results.add(score >= 0.8);
          } else {
            results.add(false);
          }
        } else {
          results.add(false);
        }
      } catch (e) {
        debugPrint('❌ Analysis error for Q$i: $e');
        results.add(false);
      }
    }

    if (mounted) {
      setState(() {
        _submitted = true;
        _analyzing = false;
      });
      widget.onAnswered(results);
    }
  }

  // ════════════════════════════════════════
  //  MISTAKE MODAL (Unity: ToggleMistakeModal)
  // ════════════════════════════════════════

  void _showMistakeModal(int index) {
    HapticFeedback.lightImpact();
    final mistakeText = _mistakes[index] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          // 60 % clamped to [320, 620] — sheet needs enough room for the
          // per-word score list on iPhone SE, but shouldn't take over
          // the whole screen on tall devices / foldables.
          maxHeight: (MediaQuery.of(context).size.height * 0.6)
              .clamp(320.0, 620.0),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_rounded,
                    color: Color(0xFF41A4FF),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ai_feedback'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  // Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _scores[index] >= 0.8
                          ? const Color(0xFFE5FFEE)
                          : const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_scores[index].toStringAsFixed(2)}/1',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _scores[index] >= 0.8
                            ? const Color(0xFF1BD259)
                            : const Color(0xFFFF3700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Mistake text content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  mistakeText,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF444444),
                    height: 1.6,
                  ),
                ),
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: MyButton(
                  height: 48,
                  borderRadius: 12,
                  buttonColor: const Color(0xFF41A4FF),
                  backButtonColor: const Color(0xFF1570EF),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'close'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  //  UTILS
  // ════════════════════════════════════════

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
