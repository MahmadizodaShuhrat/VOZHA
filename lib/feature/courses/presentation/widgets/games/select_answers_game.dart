import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/game_text_utils.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// SelectAnswers game — mirrors Unity UISelectAnswers + UISelectMoreAnswers.
///
/// Single-select (UISelectAnswers):
///  - Each dataSource = numbered question with answer buttons
///  - Tap instantly selects, disables buttons, shows result
///  - Auto-submits when all questions answered
///
/// Multi-select (UISelectMoreAnswers):
///  - Toggle selection per question (blue highlight)
///  - CHECK button at end, only active when all questions have ≥1 selection
///  - On check: correct=green, wrong=red, disable all
class SelectAnswersGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final bool multiSelect;
  final void Function(List<bool> results) onAnswered;

  const SelectAnswersGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    this.multiSelect = false,
    Key? key,
  }) : super(key: key);

  @override
  State<SelectAnswersGameWidget> createState() =>
      _SelectAnswersGameWidgetState();
}

class _SelectAnswersGameWidgetState extends State<SelectAnswersGameWidget> {
  // Per-question state
  final List<_QuestionState> _questions = [];
  bool _allDone = false;

  // Shuffled answer order per question
  final List<List<int>> _shuffledOrders = [];

  @override
  void initState() {
    super.initState();
    final rng = Random();
    for (int i = 0; i < widget.question.dataSources.length; i++) {
      final ds = widget.question.dataSources[i];
      _questions.add(_QuestionState());

      // Create shuffled indices (Unity: Fisher-Yates)
      final indices = List.generate(ds.answers.length, (j) => j);
      for (int k = indices.length - 1; k > 0; k--) {
        int j = rng.nextInt(k + 1);
        final tmp = indices[k];
        indices[k] = indices[j];
        indices[j] = tmp;
      }
      _shuffledOrders.add(indices);
    }
  }

  bool get _allQuestionsHaveSelection =>
      _questions.every((q) => q.selectedIndices.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final dataSources = widget.question.dataSources;
    if (dataSources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int qIdx = 0; qIdx < dataSources.length; qIdx++) ...[
          _buildQuestionBlock(qIdx, dataSources[qIdx]),
          if (qIdx < dataSources.length - 1) const SizedBox(height: 20),
        ],

        // Multi-select: CHECK button at end (Unity: UICheckButton)
        if (widget.multiSelect && !_allDone) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: MyButton(
              height: 48,
              borderRadius: 14,
              buttonColor: _allQuestionsHaveSelection
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFB0B0B0),
              backButtonColor: _allQuestionsHaveSelection
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF9E9E9E),
              onPressed: _allQuestionsHaveSelection
                  ? _onCheckMultiSelect
                  : null,
              child: Text(
                'check'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build one numbered question block with answers
  /// Unity: "{questionNumber}. {Option.Text}" + FlowWrapLayout with answer buttons
  Widget _buildQuestionBlock(int qIdx, CourseTestOption option) {
    final qState = _questions[qIdx];
    final shuffledIndices = _shuffledOrders[qIdx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question text: "1. question text" (Unity: questionTmp.text)
        if (option.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: buildRichTextFromHtml(
              '${qIdx + 1}. ${option.text}',
              baseStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
                height: 1.5,
              ),
            ),
          ),

        // Answer buttons in Wrap (Unity: FlowWrapLayout)
        // Unity logic: if any answer.length > 18 → full width, else half width
        _buildAnswersWrap(qIdx, option, shuffledIndices, qState),
      ],
    );
  }

  Widget _buildAnswersWrap(
    int qIdx,
    CourseTestOption option,
    List<int> shuffledIndices,
    _QuestionState qState,
  ) {
    final useFullWidth = option.answers.any((a) => a.length > 18);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: List.generate(shuffledIndices.length, (displayIdx) {
            final origIdx = shuffledIndices[displayIdx];
            final answer = option.answers[origIdx];
            final letter = String.fromCharCode(65 + displayIdx); // A, B, C...

            // Calculate button width (Unity logic)
            final buttonWidth = useFullWidth
                ? totalWidth
                : (totalWidth - 12) / 2; // Half width with spacing

            return _buildAnswerButton(
              qIdx: qIdx,
              origIdx: origIdx,
              answer: answer,
              letter: letter,
              qState: qState,
              option: option,
              width: buttonWidth,
              useFullWidth: useFullWidth,
            );
          }),
        );
      },
    );
  }

  Widget _buildAnswerButton({
    required int qIdx,
    required int origIdx,
    required String answer,
    required String letter,
    required _QuestionState qState,
    required CourseTestOption option,
    required double width,
    required bool useFullWidth,
  }) {
    final isSelected = qState.selectedIndices.contains(origIdx);
    final correctAnswers = _getCorrectAnswers(option);
    final isCorrect = correctAnswers.any(
      (c) => c.trim().toLowerCase() == answer.trim().toLowerCase(),
    );
    final isLocked = qState.isLocked;

    // Colors (Unity: SetColors)
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData? trailingIcon;
    Color? iconColor;

    if (isLocked) {
      // After submission — show results
      if (isCorrect) {
        // Unity: "1BD259", "E5FFEE" — correct always green
        bgColor = const Color(0xFFE5FFEE);
        borderColor = const Color(0xFF1BD259);
        textColor = const Color(0xFF15803D);
        trailingIcon = Icons.check_circle;
        iconColor = const Color(0xFF1BD259);
      } else if (isSelected && !isCorrect) {
        // Unity: "FF3700", "FFF0F0" — wrong selected red
        bgColor = const Color(0xFFFFF0F0);
        borderColor = const Color(0xFFFF3700);
        textColor = const Color(0xFFC62828);
        trailingIcon = Icons.cancel;
        iconColor = const Color(0xFFFF3700);
      } else {
        // Not selected, not correct — normal
        bgColor = const Color(0xFFFAFAFA);
        borderColor = const Color(0xFFE1E1E1);
        textColor = Colors.black54;
      }
    } else if (isSelected) {
      // Selected but not submitted
      // Unity multi-select: "2C81FF", "F0F6FF" (blue)
      bgColor = const Color(0xFFF0F6FF);
      borderColor = const Color(0xFF2C81FF);
      textColor = const Color(0xFF1565C0);
    } else {
      // Normal
      bgColor = const Color(0xFFFAFAFA);
      borderColor = const Color(0xFFE1E1E1);
      textColor = Colors.black87;
    }

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              HapticFeedback.lightImpact();
              setState(() {
                if (widget.multiSelect) {
                  // Unity: toggle selection
                  if (isSelected) {
                    qState.selectedIndices.remove(origIdx);
                  } else {
                    qState.selectedIndices.add(origIdx);
                  }
                } else {
                  // Unity UISelectAnswers: instant select + lock + show result
                  qState.selectedIndices.clear();
                  qState.selectedIndices.add(origIdx);
                  _onSingleSelect(qIdx, origIdx, option);
                }
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            // Icon: radio for single, checkbox for multi
            if (widget.multiSelect)
              Icon(
                isSelected
                    ? (isLocked
                          ? (isCorrect
                                ? Icons.check_box
                                : Icons.indeterminate_check_box)
                          : Icons.check_box)
                    : Icons.check_box_outline_blank,
                color: isSelected ? borderColor : const Color(0xFFBDBDBD),
                size: 22,
              )
            else
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? borderColor : const Color(0xFFBDBDBD),
                size: 22,
              ),
            const SizedBox(width: 10),
            // "A. answer text" (Unity: "{letter}. <indent=1.2em>{answer}</indent>")
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$letter. ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    parseHtmlTags(
                      answer,
                      baseStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              Icon(trailingIcon, color: iconColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  /// Unity UISelectAnswers: instant click → lock → color → check if all done
  void _onSingleSelect(int qIdx, int selectedOrigIdx, CourseTestOption option) {
    final qState = _questions[qIdx];
    qState.isLocked = true;

    final answer = option.answers[selectedOrigIdx];
    final correctAnswers = _getCorrectAnswers(option);
    final isCorrect = correctAnswers.any(
      (c) => c.trim().toLowerCase() == answer.trim().toLowerCase(),
    );

    qState.result = isCorrect;

    // Check if all questions answered (Unity: CheckAnswered)
    if (_questions.every((q) => q.isLocked)) {
      setState(() => _allDone = true);
      widget.onAnswered(_questions.map((q) => q.result ?? false).toList());
    }
  }

  /// Unity UISelectMoreAnswers: CHECK button pressed
  void _onCheckMultiSelect() {
    if (!_allQuestionsHaveSelection) return;

    HapticFeedback.mediumImpact();

    final dataSources = widget.question.dataSources;
    final results = <bool>[];

    for (int qIdx = 0; qIdx < dataSources.length; qIdx++) {
      final option = dataSources[qIdx];
      final qState = _questions[qIdx];
      qState.isLocked = true;

      final correctAnswers = _getCorrectAnswers(option);
      final selectedAnswerTexts = qState.selectedIndices
          .map((idx) => option.answers[idx].trim().toLowerCase())
          .toSet();
      final correctSet = correctAnswers
          .map((a) => a.trim().toLowerCase())
          .toSet();

      // Unity: CheckAnswerCorrectness — selected must match correct exactly
      final isCorrect =
          selectedAnswerTexts.length == correctSet.length &&
          correctSet.every((c) => selectedAnswerTexts.contains(c));

      qState.result = isCorrect;
      results.add(isCorrect);
    }

    setState(() => _allDone = true);
    widget.onAnswered(results);
  }

  /// Get correct answers list (Unity: GetCorrectAnswers)
  List<String> _getCorrectAnswers(CourseTestOption option) {
    if (option.correctAnswers.isNotEmpty) return option.correctAnswers;
    if (option.correctAnswer != null && option.correctAnswer!.isNotEmpty) {
      return [option.correctAnswer!];
    }
    return [];
  }
}

/// Internal per-question state
class _QuestionState {
  final Set<int> selectedIndices = {};
  bool isLocked = false;
  bool? result;
}
