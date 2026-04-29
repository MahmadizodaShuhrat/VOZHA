import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// DropDown game — mirrors Unity UIDropDownGame + DropdownBlanksUI.
///
/// Unity design:
///  - Each dataSource = numbered question with inline *DD* dropdown blanks
///  - Text flows with dropdown buttons embedded inline
///  - Dropdown placeholder: "Select answer"
///  - CHECK button → validate → correct=green, wrong=red
///  - Colors: E5FFEE/1BD259 (correct), FFF0F0/FF3700 (wrong)
class DropDownGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const DropDownGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<DropDownGameWidget> createState() => _DropDownGameWidgetState();
}

class _DropDownGameWidgetState extends State<DropDownGameWidget> {
  // All blanks across all dataSources
  final List<_BlankData> _blanks = [];
  // User selections: blankIndex -> selected value
  final Map<int, String?> _selectedValues = {};
  bool _submitted = false;
  List<bool> _results = [];

  @override
  void initState() {
    super.initState();
    _parseBlanks();
  }

  void _parseBlanks() {
    int blankIdx = 0;
    for (final ds in widget.question.dataSources) {
      if (ds.blanks.isNotEmpty) {
        for (final blank in ds.blanks) {
          // WordBank fallback: ds → question.wordBank → question.phraseBank
          final wordBank = ds.wordBank.isNotEmpty
              ? ds.wordBank
              : widget.question.wordBank.isNotEmpty
              ? widget.question.wordBank
              : widget.question.phraseBank;
          final answers = <String>[
            if (blank.correctAnswer != null && blank.correctAnswer!.isNotEmpty)
              blank.correctAnswer!,
            ...blank.correctAnswers,
          ];
          _blanks.add(
            _BlankData(
              index: blankIdx,
              wordBank: wordBank.isNotEmpty ? wordBank : answers,
              correctAnswers: answers,
            ),
          );
          blankIdx++;
        }
      } else if (ds.correctAnswer != null && ds.correctAnswer!.isNotEmpty) {
        // WordBank fallback: ds → question.wordBank → question.phraseBank
        final wordBank = ds.wordBank.isNotEmpty
            ? ds.wordBank
            : widget.question.wordBank.isNotEmpty
            ? widget.question.wordBank
            : widget.question.phraseBank;
        final answers = [ds.correctAnswer!, ...ds.correctAnswers];
        _blanks.add(
          _BlankData(
            index: blankIdx,
            wordBank: wordBank.isNotEmpty ? wordBank : answers,
            correctAnswers: answers,
          ),
        );
        blankIdx++;
      }
    }
  }

  bool get _allFilled =>
      _blanks.isNotEmpty &&
      _blanks.every(
        (b) =>
            _selectedValues[b.index] != null &&
            _selectedValues[b.index]!.isNotEmpty,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unity: Numbered questions with inline dropdown blanks
        ...List.generate(widget.question.dataSources.length, (dsIdx) {
          return _buildQuestionLine(dsIdx);
        }),

        // Unity: UIButtonCheck
        if (!_submitted && _blanks.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: MyButton(
              height: 48,
              borderRadius: 14,
              buttonColor: _allFilled
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFB0B0B0),
              backButtonColor: _allFilled
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF9E9E9E),
              onPressed: _allFilled ? _onCheck : null,
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

  /// Build one numbered question line with inline dropdowns
  /// Unity: "1. Tom uses a(n) [Select answer ▼] to take photos."
  Widget _buildQuestionLine(int dsIdx) {
    final ds = widget.question.dataSources[dsIdx];
    final questionNumber = dsIdx + 1;

    // Split text by *DD* or ___ to find where dropdowns go
    final text = ds.text;
    var parts = text.split(RegExp(r'\*DD\*|___'));

    // If text has no DD markers but has correctAnswer → append blank at end
    int blanksInText = parts.length - 1;
    int expectedBlanks = ds.blanks.isNotEmpty
        ? ds.blanks.length
        : (ds.correctAnswer != null && ds.correctAnswer!.isNotEmpty ? 1 : 0);
    if (blanksInText < expectedBlanks && text.isNotEmpty) {
      // Add empty parts so dropdown appears after text
      for (int i = blanksInText; i < expectedBlanks; i++) {
        parts = [...parts, ''];
      }
    }

    // Count blanks in this dataSource
    int blankOffset = 0;
    for (int i = 0; i < dsIdx; i++) {
      final prevDs = widget.question.dataSources[i];
      if (prevDs.blanks.isNotEmpty) {
        blankOffset += prevDs.blanks.length;
      } else if (prevDs.correctAnswer != null &&
          prevDs.correctAnswer!.isNotEmpty) {
        blankOffset += 1;
      }
    }

    int blanksInThisDs = ds.blanks.isNotEmpty
        ? ds.blanks.length
        : (ds.correctAnswer != null && ds.correctAnswer!.isNotEmpty ? 1 : 0);

    // Determine result color for this question line
    Color? bgColor;
    Color? borderColor;
    if (_submitted) {
      bool allCorrect = true;
      for (int b = 0; b < blanksInThisDs; b++) {
        int globalIdx = blankOffset + b;
        if (globalIdx < _results.length && !_results[globalIdx]) {
          allCorrect = false;
          break;
        }
      }
      bgColor = allCorrect
          ? const Color(0xFFE5FFEE) // Unity green bg
          : const Color(0xFFFFF0F0); // Unity red bg
      borderColor = allCorrect
          ? const Color(0xFF1BD259) // Unity green
          : const Color(0xFFFF3700); // Unity red
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE8ECF0),
          width: borderColor != null ? 1.5 : 1,
        ),
        boxShadow: _submitted
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Build inline text with dropdown widgets using RichText + WidgetSpan
          _buildRichTextLine(
            questionNumber,
            parts,
            blankOffset,
            blanksInThisDs,
          ),
          // Show correct answers for wrong blanks
          if (_submitted)
            ...List.generate(blanksInThisDs, (b) {
              int globalIdx = blankOffset + b;
              if (globalIdx < _results.length && !_results[globalIdx]) {
                final correctText =
                    (globalIdx < _blanks.length &&
                        _blanks[globalIdx].correctAnswers.isNotEmpty)
                    ? _blanks[globalIdx].correctAnswers.first
                    : '?';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '✅ $correctText',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
        ],
      ),
    );
  }

  /// Build one line as RichText with inline WidgetSpan for dropdowns.
  /// This ensures text flows naturally as a paragraph.
  Widget _buildRichTextLine(
    int questionNumber,
    List<String> textParts,
    int blankOffset,
    int blanksCount,
  ) {
    final spans = <InlineSpan>[];
    int blankCounter = 0;

    const textStyle = TextStyle(
      fontSize: 15,
      color: Color(0xFF333333),
      height: 1.8,
    );

    // Add question number
    spans.add(
      TextSpan(
        text: '$questionNumber. ',
        style: textStyle.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    for (int i = 0; i < textParts.length; i++) {
      final part = textParts[i].trim();

      // Add text segment
      if (part.isNotEmpty) {
        spans.add(TextSpan(text: '$part ', style: textStyle));
      }

      // Add dropdown widget after each text segment (except last)
      if (i < textParts.length - 1 && blankCounter < blanksCount) {
        final globalIdx = blankOffset + blankCounter;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _buildDropdownButton(globalIdx),
          ),
        );
        // Add space after dropdown
        spans.add(const TextSpan(text: ' ', style: textStyle));
        blankCounter++;
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Inline dropdown button — tap to show PopupMenu with options
  /// Unity: TMP_Dropdown with "Select answer" placeholder
  Widget _buildDropdownButton(int blankIndex) {
    if (blankIndex >= _blanks.length) return const SizedBox.shrink();

    final blank = _blanks[blankIndex];
    final selected = _selectedValues[blankIndex];
    final hasSelection = selected != null && selected.isNotEmpty;

    // Result color
    Color dropBg = const Color(0xFFF8F9FA);
    Color dropBorder = const Color(0xFFD0D5DD);
    Color textColor = const Color(0xFF666666);

    if (_submitted && blankIndex < _results.length) {
      if (_results[blankIndex]) {
        dropBg = const Color(0xFFE5FFEE);
        dropBorder = const Color(0xFF1BD259);
        textColor = const Color(0xFF15803D);
      } else {
        dropBg = const Color(0xFFFFF0F0);
        dropBorder = const Color(0xFFFF3700);
        textColor = const Color(0xFFC62828);
      }
    } else if (hasSelection) {
      dropBg = const Color(0xFFF0F6FF);
      dropBorder = const Color(0xFF2C81FF);
      textColor = const Color(0xFF1565C0);
    }

    return PopupMenuButton<String>(
      onSelected: _submitted
          ? null
          : (value) {
              HapticFeedback.lightImpact();
              setState(() => _selectedValues[blankIndex] = value);
            },
      enabled: !_submitted,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
      itemBuilder: (context) {
        // Unity: filter out words already used in OTHER blanks
        final usedInOtherBlanks = <String>{};
        for (final entry in _selectedValues.entries) {
          if (entry.key != blankIndex &&
              entry.value != null &&
              entry.value!.isNotEmpty) {
            usedInOtherBlanks.add(entry.value!);
          }
        }
        final availableWords = blank.wordBank
            .where((w) => !usedInOtherBlanks.contains(w) || w == selected)
            .toList();
        return availableWords.map((word) {
          final isSelected = selected == word;
          return PopupMenuItem<String>(
            value: word,
            height: 42,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF0F6FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF2C81FF)
                            : const Color(0xFF333333),
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, size: 18, color: Color(0xFF2C81FF)),
                ],
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dropBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: dropBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasSelection ? selected : 'Select answer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasSelection ? FontWeight.w500 : FontWeight.w400,
                color: textColor,
              ),
            ),
            if (!_submitted) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 18, color: dropBorder),
            ],
          ],
        ),
      ),
    );
  }

  /// Unity: OnCheckButtonClicked
  void _onCheck() {
    HapticFeedback.mediumImpact();

    final results = <bool>[];
    for (final blank in _blanks) {
      final selected = _selectedValues[blank.index]?.trim().toLowerCase() ?? '';
      final correct = blank.correctAnswers
          .map((a) => a.trim().toLowerCase())
          .toList();
      results.add(correct.contains(selected));
    }

    setState(() {
      _submitted = true;
      _results = results;
    });
    widget.onAnswered(results);
  }
}

class _BlankData {
  final int index;
  final List<String> wordBank;
  final List<String> correctAnswers;
  _BlankData({
    required this.index,
    required this.wordBank,
    required this.correctAnswers,
  });
}
