import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/utils/speech_bridge.dart';

/// Show pronunciation evaluation dialog with Azure Speech scores
/// Matches Unity's UIItemResultsRecognition display with DOTween-style animations
void showPronunciationEvaluationDialog(
  BuildContext context, {
  required String expectedWord,
  required String actualWord,
  required VoidCallback onRetry,
  required VoidCallback onNext,
  PronunciationResult? azureResult,
  bool showRetry = true, // Unity: hide when score >= 98 or retried 3 times
}) {
  Map<String, int> scores;

  // Use Azure scores directly — even if AccuracyScore=0 (bad pronunciation is still valid data)
  if (azureResult != null && azureResult.isSuccess) {
    scores = {
      'accuracy': azureResult.accuracyScore.toInt().clamp(0, 100),
      'fluency': azureResult.fluencyScore.toInt().clamp(0, 100),
      'completeness': azureResult.completenessScore.toInt().clamp(0, 100),
      'pronScore': azureResult.pronScore.toInt().clamp(0, 100),
    };
    debugPrint('📊 Azure scores (direct): $scores');
  } else {
    scores = evaluatePronunciation(expectedWord, actualWord);
    scores['pronScore'] = ((scores['accuracy']! + scores['fluency']! + scores['completeness']!) / 3).toInt();
    debugPrint('📊 Using local pronunciation scores: $scores');
  }

  showDialog(
    context: context,
    // Root navigator-ро истифода мекунем то ки dialog ба `BattleGamePage`-и
    // local navigator пайваста набошад. Бе ин, ҳангоми гузариш аз `playing`
    // ба `finished` `BattlePage` ҷой иваз мекард ва `Navigator.pop`-и dialog
    // тамоми саҳифаро мепӯшид.
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        insetPadding: const EdgeInsets.all(20),
        child: _AnimatedResultContent(
          scores: scores,
          expectedWord: expectedWord,
          actualWord: actualWord,
          azureResult: azureResult,
          showRetry: showRetry,
          onRetry: onRetry,
          onNext: onNext,
        ),
      );
    },
  );
}

/// Animated dialog content — Unity's OnEnable starts at 0, then animates to target
class _AnimatedResultContent extends StatefulWidget {
  final Map<String, int> scores;
  final String expectedWord;
  final String actualWord;
  final PronunciationResult? azureResult;
  final bool showRetry;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  const _AnimatedResultContent({
    required this.scores,
    required this.expectedWord,
    required this.actualWord,
    this.azureResult,
    required this.showRetry,
    required this.onRetry,
    required this.onNext,
  });

  @override
  State<_AnimatedResultContent> createState() => _AnimatedResultContentState();
}

class _AnimatedResultContentState extends State<_AnimatedResultContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Unity: duration = 1f (1 second)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    // Unity: OnEnable starts at 0, then animate
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pronScore = widget.scores['pronScore']!;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final t = _animation.value; // 0.0 → 1.0

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Center(
                  child: Text(
                    "Pronunciation_Assessment".tr(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(height: 16),
                // Unity: PronScore in main circle — animated
                Center(
                  child: _AnimatedScoreCircle(
                    score: pronScore,
                    progress: t,
                  ),
                ),
                SizedBox(height: 12),
                // Color scale (Unity colors: A80000, DAB934, 218D51)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildColorIndicator("0 - 59", Color(0xFFA80000)),
                    _buildColorIndicator("60 - 79", Color(0xFFDAB934)),
                    _buildColorIndicator("80 - 100", Color(0xFF218D51)),
                  ],
                ),
                SizedBox(height: 20),

                // Section title
                Text(
                  "Score_Breakdown".tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E90FA),
                  ),
                ),
                SizedBox(height: 16),

                // Unity: 4 animated bars — Accuracy, Fluency, Completeness, PronScore
                _buildAnimatedScoreBar(
                  "Accuracy_Assessment".tr(),
                  widget.scores['accuracy']!,
                  t,
                ),
                SizedBox(height: 12),
                _buildAnimatedScoreBar(
                  "Fluency_Assessment".tr(),
                  widget.scores['fluency']!,
                  t,
                ),
                SizedBox(height: 12),
                _buildAnimatedScoreBar(
                  "Completeness_Assessment".tr(),
                  widget.scores['completeness']!,
                  t,
                ),
                SizedBox(height: 12),
                _buildAnimatedScoreBar(
                  "PronScore".tr(),
                  widget.scores['pronScore']!,
                  t,
                ),
                SizedBox(height: 20),

                // Recognized word — color based on overall pronScore
                Center(
                  child: colorizeLettersCombined(
                    widget.expectedWord,
                    widget.actualWord,
                    widget.azureResult?.words ?? [],
                    overallScore: pronScore,
                  ),
                ),
                SizedBox(height: 24),
                // Buttons
                if (widget.showRetry)
                  MyButton(
                    backButtonColor: Color(0xFFEDAC10),
                    buttonColor: Color(0xFFFEDF47),
                    onPressed: widget.onRetry,
                    child: Center(
                      child: Text(
                        "retry".tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                if (widget.showRetry) SizedBox(height: 10),
                MyButton(
                  backButtonColor: Color(0xFF15824F),
                  buttonColor: Color(0xFF20CD7E),
                  onPressed: widget.onNext,
                  child: Center(
                    child: Text(
                      "next".tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Unity: AnimateScoreChange — fill bar + text count-up + color transition
  Widget _buildAnimatedScoreBar(String label, int targetScore, double t) {
    final currentScore = (targetScore * t).toInt();
    final currentFill = targetScore * t / 100.0;
    final color = getColorForScore(currentScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
            Text(
              '$currentScore / 100',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: currentFill.clamp(0.0, 1.0),
            backgroundColor: Color(0xFFEEF2F6),
            color: color,
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

/// Animated circular score — Unity: DOTween count-up + fill
class _AnimatedScoreCircle extends StatelessWidget {
  final int score;
  final double progress; // 0.0 → 1.0

  const _AnimatedScoreCircle({
    required this.score,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final currentScore = (score * progress).toInt();
    final currentPercent = (score * progress / 100.0).clamp(0.0, 1.0);

    return CircularPercentIndicator(
      radius: 55.0,
      lineWidth: 8.0,
      percent: currentPercent,
      center: Text(
        '$currentScore',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: getColorForScore(currentScore),
        ),
      ),
      progressColor: getColorForScore(currentScore),
      backgroundColor: Color(0xFFEEF2F6),
      circularStrokeCap: CircularStrokeCap.round,
    );
  }
}

// Helper for evaluation (fallback when Azure is not available)
Map<String, int> evaluatePronunciation(String expected, String actual) {
  expected = expected.toLowerCase().trim();
  actual = actual.toLowerCase().trim();

  // Accuracy
  int accuracy =
      ((actual == expected)
              ? 100
              : (actual.contains(expected) || expected.contains(actual))
                  ? 70
                  : 30)
          .toInt();

  // Fluency (length ratio)
  int fluency =
      actual.isNotEmpty
          ? ((1 - (actual.length - expected.length).abs() / expected.length) *
                  100)
              .clamp(0, 100)
              .toInt()
          : 0;

  // Completeness (character overlap)
  int matchingChars = 0;
  for (int i = 0; i < actual.length && i < expected.length; i++) {
    if (actual[i] == expected[i]) matchingChars++;
  }
  int completeness =
      expected.isNotEmpty
          ? ((matchingChars / expected.length) * 100).toInt()
          : 0;

  return {
    'accuracy': accuracy.clamp(0, 100),
    'fluency': fluency.clamp(0, 100),
    'completeness': completeness.clamp(0, 100),
  };
}

// Unity: AnimateColorChange — gradient red→yellow→green based on score
Color getColorForScore(int score) {
  if (score <= 59) {
    final t = score / 59.0;
    return Color.lerp(
      Color(0xFF6B0000),
      Color(0xFFEF4444),
      t,
    )!;
  } else if (score <= 79) {
    final t = (score - 60) / 19.0;
    return Color.lerp(
      Color(0xFFD97706),
      Color(0xFFF59E0B),
      t,
    )!;
  } else {
    final t = (score - 80) / 20.0;
    return Color.lerp(
      Color(0xFF34D399),
      Color(0xFF059669),
      t,
    )!;
  }
}

Widget _buildColorIndicator(String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Color(0xFF697586))),
    ],
  );
}

// Keep for backward compatibility (non-animated version)
Widget buildScoreBar(String label, int score, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E),
            ),
          ),
          Text(
            '$score / 100',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
      SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: score / 100,
          backgroundColor: Color(0xFFEEF2F6),
          color: color,
          minHeight: 10,
        ),
      ),
    ],
  );
}

/// Unity UIGame5.cs coloring logic:
/// 1. Check if syllables have Grapheme → color per-syllable
/// 2. If no grapheme → color entire word based on word AccuracyScore
/// Colors: red (#A80000) for 0-59, yellow (#DAB934) for 60-79, green (#218D51) for 80-100
RichText colorizeLettersCombined(
  String expected,
  String actual,
  List<WordAssessment> azureWords, {
  int? overallScore,
}) {
  final List<TextSpan> spans = [];

  // If we have an overall score, use it for the entire word color
  if (overallScore != null) {
    final color = _getUnityColor(overallScore.toDouble());
    // Use Azure recognized text if available, otherwise expected
    final displayText = azureWords.isNotEmpty
        ? azureWords.map((w) => w.word).join(' ')
        : expected;
    spans.add(TextSpan(
      text: displayText,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ));
  } else if (azureWords.isNotEmpty) {
    for (int i = 0; i < azureWords.length; i++) {
      final wordAssessment = azureWords[i];

      // Unity: Check if syllables have Grapheme
      bool hasGrapheme = wordAssessment.syllables.isNotEmpty &&
          wordAssessment.syllables.every((s) => s.grapheme.isNotEmpty);

      if (hasGrapheme) {
        // Unity: Color each syllable by its Grapheme + AccuracyScore
        for (final syllable in wordAssessment.syllables) {
          final color = _getUnityColor(syllable.accuracyScore);
          spans.add(TextSpan(
            text: syllable.grapheme,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ));
        }
      } else {
        // Unity: No grapheme — color entire word
        final color = _getUnityColor(wordAssessment.accuracyScore);
        spans.add(TextSpan(
          text: wordAssessment.word,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ));
      }

      // Add space between words
      if (i < azureWords.length - 1) {
        spans.add(TextSpan(text: ' '));
      }
    }
  } else {
    // Local fallback: show EXPECTED word, highlight matching chars using LCS
    final exp = expected.toLowerCase();
    final act = actual.toLowerCase();
    final matchSet = _lcsMatchIndices(exp, act);

    for (int i = 0; i < expected.length; i++) {
      final isMatch = matchSet.contains(i);
      spans.add(TextSpan(
        text: expected[i],
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: isMatch ? Color(0xFF218D51) : Color(0xFFA80000), // green / red
        ),
      ));
    }
  }

  return RichText(text: TextSpan(children: spans));
}

/// Unity's exact 3-color system (no gradients for word display)
Color _getUnityColor(double accuracyScore) {
  if (accuracyScore >= 80) return Color(0xFF218D51); // green
  if (accuracyScore >= 60) return Color(0xFFDAB934); // yellow
  return Color(0xFFA80000); // red
}

/// Find indices in [expected] that match chars in [actual] using LCS.
/// Returns set of indices in [expected] that were matched.
Set<int> _lcsMatchIndices(String expected, String actual) {
  final m = expected.length;
  final n = actual.length;
  // Build LCS table
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (expected[i - 1] == actual[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }
  // Backtrack to find matched indices in expected
  final matched = <int>{};
  int i = m, j = n;
  while (i > 0 && j > 0) {
    if (expected[i - 1] == actual[j - 1]) {
      matched.add(i - 1);
      i--;
      j--;
    } else if (dp[i - 1][j] > dp[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }
  return matched;
}

// Keep ScoreCircle for backward compatibility
class ScoreCircle extends StatelessWidget {
  final int score;
  const ScoreCircle({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: 55.0,
      lineWidth: 8.0,
      percent: score / 100,
      center: Text(
        '$score',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: getColorForScore(score),
        ),
      ),
      progressColor: getColorForScore(score),
      backgroundColor: Color(0xFFEEF2F6),
      circularStrokeCap: CircularStrokeCap.round,
    );
  }
}

// Word match penalty is no longer needed — word match check is done
// in speech_game_page.dart before showing this dialog (Unity parity)
