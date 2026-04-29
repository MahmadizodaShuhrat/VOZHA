import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// MultiChoice game — mirrors Unity UIMultiChoiceGame + MultiChoiceUI.
///
/// Unity layout:
///  - Each dataSource = one row: [number] [image?] [answer A] [answer B] [answer C] [answer D]
///  - User selects one answer per row
///  - CHECK button validates all rows at once
///  - Results: correct answer = green, wrong selected = red
class MultiChoiceGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const MultiChoiceGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    Key? key,
  }) : super(key: key);

  @override
  State<MultiChoiceGameWidget> createState() => _MultiChoiceGameWidgetState();
}

class _MultiChoiceGameWidgetState extends State<MultiChoiceGameWidget> {
  // Per-row selected answer index
  final Map<int, int> _selectedAnswers = {};
  bool _submitted = false;
  List<bool>? _results;

  bool get _allAnswered =>
      _selectedAnswers.length >= widget.question.dataSources.length;

  @override
  Widget build(BuildContext context) {
    final dataSources = widget.question.dataSources;
    if (dataSources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // All rows
        for (int rowIdx = 0; rowIdx < dataSources.length; rowIdx++) ...[
          _buildRow(rowIdx, dataSources[rowIdx]),
          if (rowIdx < dataSources.length - 1) const SizedBox(height: 16),
        ],

        const SizedBox(height: 20),

        // CHECK button (Unity: UIButtonCheck)
        if (!_submitted)
          SizedBox(
            width: double.infinity,
            child: MyButton(
              height: 48,
              borderRadius: 14,
              buttonColor: _allAnswered
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFB0B0B0),
              backButtonColor: _allAnswered
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF9E9E9E),
              onPressed: _allAnswered ? _onCheck : null,
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
    );
  }

  /// Build one row: [number] [image?] then answer options below
  Widget _buildRow(int rowIdx, CourseTestOption option) {
    final hasImage = option.spriteName != null && option.spriteName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row header: number + optional text
          Row(
            children: [
              // Row number circle (Unity: numberText)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F4FF),
                  border: Border.all(
                    color: const Color(0xFF4A90D9),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${rowIdx + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF4A90D9),
                    ),
                  ),
                ),
              ),
              if (option.text.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Optional image (Unity: Image per row)
          if (hasImage) ...[
            const SizedBox(height: 10),
            _buildRowImage(option.spriteName!),
          ],

          const SizedBox(height: 12),

          // Answer buttons — full-width so long text wraps properly
          Column(
            children: List.generate(option.answers.length, (ansIdx) {
              return Padding(
                padding: EdgeInsets.only(bottom: ansIdx < option.answers.length - 1 ? 8 : 0),
                child: _buildAnswerButton(rowIdx, ansIdx, option),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRowImage(String spriteName) {
    final imagePath = '${widget.basePath}/$spriteName';
    final file = File(imagePath);

    if (!file.existsSync()) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(file, height: 80, fit: BoxFit.contain),
    );
  }

  Widget _buildAnswerButton(int rowIdx, int ansIdx, CourseTestOption option) {
    final answer = option.answers[ansIdx];
    final isSelected = _selectedAnswers[rowIdx] == ansIdx;
    final isCorrect =
        option.correctAnswer?.trim().toLowerCase() ==
        answer.trim().toLowerCase();

    // Colors (Unity: normalColor, selectedColor, correctColor, incorrectColor)
    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE0E0E0);
    Color textColor = Colors.black87;
    IconData? trailingIcon;
    Color? iconColor;

    if (_submitted && _results != null) {
      if (isCorrect) {
        // Correct answer — always green (Unity: correctColor)
        bgColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF4CAF50);
        textColor = const Color(0xFF2E7D32);
        trailingIcon = Icons.check_circle;
        iconColor = const Color(0xFF4CAF50);
      } else if (isSelected && !isCorrect) {
        // Wrong selected — red (Unity: incorrectColor)
        bgColor = const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFEF5350);
        textColor = const Color(0xFFC62828);
        trailingIcon = Icons.cancel;
        iconColor = const Color(0xFFEF5350);
      }
    } else if (isSelected) {
      // Selected but not submitted (Unity: selectedColor)
      bgColor = const Color(0xFFE3F2FD);
      borderColor = const Color(0xFF2196F3);
      textColor = const Color(0xFF1565C0);
    }

    return GestureDetector(
      onTap: _submitted
          ? null
          : () {
              HapticFeedback.lightImpact();
              setState(() => _selectedAnswers[rowIdx] = ansIdx);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            // Letter circle: A, B, C, D
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? borderColor : const Color(0xFFF5F5F5),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + ansIdx), // A, B, C, D
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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

  /// Unity: OnCheckButtonClicked
  void _onCheck() {
    if (!_allAnswered) return;

    HapticFeedback.mediumImpact();

    final dataSources = widget.question.dataSources;
    final results = <bool>[];

    for (int rowIdx = 0; rowIdx < dataSources.length; rowIdx++) {
      final option = dataSources[rowIdx];
      final selectedIdx = _selectedAnswers[rowIdx]!;
      final selectedAnswer = option.answers[selectedIdx];
      final isCorrect =
          option.correctAnswer?.trim().toLowerCase() ==
          selectedAnswer.trim().toLowerCase();
      results.add(isCorrect);
    }

    setState(() {
      _submitted = true;
      _results = results;
    });

    widget.onAnswered(results);
  }
}
