import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';

/// FillBlank game — mirrors Unity UIFillBlankGame.
///
/// Real data format:
///   text: "She looks <u>like</u> someone.\n*Input...*a*Input...*i*Input...*"
///   blanks: [{correct_answer: ""}], [{correct_answer: ""}], ...
///
/// Parsing rules:
///  - <u>text</u> → underlined (bold) text
///  - \n splits sentence from input line
///  - *Input...* → editable text field
///  - Fixed chars between *Input...* markers → given letters (read-only)
class FillBlankGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const FillBlankGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    Key? key,
  }) : super(key: key);

  @override
  State<FillBlankGameWidget> createState() => _FillBlankGameWidgetState();
}

class _FillBlankGameWidgetState extends State<FillBlankGameWidget> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  bool _submitted = false;
  List<bool> _results = [];

  // Total blanks across all data sources
  int _totalBlanks = 0;

  @override
  void initState() {
    super.initState();
    _totalBlanks = 0;
    for (final ds in widget.question.dataSources) {
      if (ds.blanks.isNotEmpty) {
        _totalBlanks += ds.blanks.length;
      } else {
        _totalBlanks += 1;
      }
    }
    for (int i = 0; i < _totalBlanks; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    int controllerIdx = 0;

    for (final ds in widget.question.dataSources) {
      final blanksCount = ds.blanks.isNotEmpty ? ds.blanks.length : 1;
      children.add(_buildDataSource(ds, controllerIdx));
      controllerIdx += blanksCount;
      children.add(const SizedBox(height: 16));
    }

    // Submit button
    if (!_submitted) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'confirm'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // ════════════════════════════════════
  //  PARSE & RENDER DATA SOURCE
  // ════════════════════════════════════
  Widget _buildDataSource(CourseTestOption ds, int startIdx) {
    final text = ds.text;
    if (text.isEmpty) {
      // Simple input only — no text, just blanks
      return _buildSimpleInput(startIdx, ds);
    }

    // Normalize escaped newlines
    final normalized = text.replaceAll(r'\n', '\n');

    // Check if text contains *Input...* markers ANYWHERE
    final hasInputMarkers = normalized.contains('*Input...*');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
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
          if (hasInputMarkers)
            // Render full text with inline inputs replacing *Input...*
            _buildTextWithInlineInputs(normalized, ds, startIdx)
          else if (ds.blanks.isNotEmpty) ...[
            // No *Input...* markers but has blanks — show text + separate inputs
            _buildRichSentence(normalized),
            const SizedBox(height: 12),
            ...List.generate(ds.blanks.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSimpleInput(startIdx + i, ds),
              );
            }),
          ] else ...[
            // No markers, no blanks — show text + one input
            _buildRichSentence(normalized),
            const SizedBox(height: 12),
            _buildSimpleInput(startIdx, ds),
          ],
        ],
      ),
    );
  }

  /// Build the full text with *Input...* replaced by inline TextField widgets.
  /// Handles <u> tags, newlines, and fixed chars between inputs.
  Widget _buildTextWithInlineInputs(
    String fullText,
    CourseTestOption ds,
    int startIdx,
  ) {
    // Split by *Input...* to get alternating: text, input, text, input, ...
    final segments = fullText.split('*Input...*');
    final spans = <InlineSpan>[];
    int inputIdx = 0;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // Add text segment (may contain <u>, <b>, <i> tags and newlines)
      if (segment.isNotEmpty) {
        // Handle newlines within segments
        final lines = segment.split('\n');
        for (int li = 0; li < lines.length; li++) {
          if (li > 0) {
            // Add line break
            spans.add(const TextSpan(text: '\n'));
          }
          final line = lines[li];
          if (line.isNotEmpty) {
            spans.add(_parseHtmlToSpan(line));
          }
        }
      }

      // Add input field (except after last segment)
      if (i < segments.length - 1 &&
          (startIdx + inputIdx) < _controllers.length) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _buildInlineInput(startIdx + inputIdx, ds),
          ),
        );
        inputIdx++;
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Parse HTML <u>/<b>/<i> tags into a TextSpan tree.
  TextSpan _parseHtmlToSpan(String text) {
    // Collapse nested <u> tags
    var cleaned = text;
    while (cleaned.contains('<u><u>')) {
      cleaned = cleaned.replaceAll('<u><u>', '<u>');
    }
    while (cleaned.contains('</u></u>')) {
      cleaned = cleaned.replaceAll('</u></u>', '</u>');
    }
    cleaned = cleaned.replaceAll('</u><u>', '');

    final spans = <InlineSpan>[];
    final regex = RegExp(r'<(u|b|i)>(.*?)</\1>', caseSensitive: false);
    int lastEnd = 0;

    const baseStyle = TextStyle(
      fontSize: 15,
      height: 1.5,
      color: Color(0xFF333333),
    );

    for (final match in regex.allMatches(cleaned)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: cleaned.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final tag = match.group(1)!.toLowerCase();
      final content = match.group(2)!;
      TextStyle tagStyle;
      switch (tag) {
        case 'u':
          tagStyle = baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF4A90D9),
            decorationThickness: 2,
          );
          break;
        case 'b':
          tagStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);
          break;
        case 'i':
          tagStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
          break;
        default:
          tagStyle = baseStyle;
      }
      spans.add(TextSpan(text: content, style: tagStyle));
      lastEnd = match.end;
    }

    if (lastEnd < cleaned.length) {
      spans.add(TextSpan(text: cleaned.substring(lastEnd), style: baseStyle));
    }

    if (spans.isEmpty) {
      return TextSpan(text: cleaned, style: baseStyle);
    }
    return TextSpan(children: spans);
  }

  // ════════════════════════════════════
  //  RICH SENTENCE (parse <u> tags)
  // ════════════════════════════════════
  Widget _buildRichSentence(String text) {
    // Collapse nested <u> tags: <u><u>make</u></u> → <u>make</u>
    var cleaned = text;
    while (cleaned.contains('<u><u>')) {
      cleaned = cleaned.replaceAll('<u><u>', '<u>');
    }
    while (cleaned.contains('</u></u>')) {
      cleaned = cleaned.replaceAll('</u></u>', '</u>');
    }
    // Merge adjacent: </u><u> → continuous underline
    cleaned = cleaned.replaceAll('</u><u>', '');

    // Parse <u>text</u> into underlined+bold spans
    final spans = <InlineSpan>[];
    final regex = RegExp(r'<u>(.*?)</u>');
    int lastEnd = 0;

    for (final match in regex.allMatches(cleaned)) {
      // Text before the match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: cleaned.substring(lastEnd, match.start),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF333333),
            ),
          ),
        );
      }
      // Underlined text
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF4A90D9),
            decorationThickness: 2,
          ),
        ),
      );
      lastEnd = match.end;
    }

    // Remaining text
    if (lastEnd < cleaned.length) {
      spans.add(
        TextSpan(
          text: cleaned.substring(lastEnd),
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF333333),
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(
        cleaned,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Color(0xFF333333),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  // ════════════════════════════════════
  //  INLINE INPUT FIELD
  // ════════════════════════════════════
  Widget _buildInlineInput(int idx, CourseTestOption option) {
    if (idx >= _controllers.length) return const SizedBox.shrink();

    final controller = _controllers[idx];
    final focusNode = _focusNodes[idx];

    Color borderColor = const Color(0xFFCCD5E0);
    Color fillColor = const Color(0xFFF8FAFC);

    if (_submitted && idx < _results.length) {
      if (_results[idx]) {
        borderColor = const Color(0xFF4CAF50);
        fillColor = const Color(0xFFE8F5E9);
      } else {
        borderColor = const Color(0xFFEF5350);
        fillColor = const Color(0xFFFFEBEE);
      }
    }

    // Determine width based on expected answer length
    int expectedLen = 4;
    int blankOffset = 0;
    for (final ds in widget.question.dataSources) {
      if (ds.blanks.isNotEmpty) {
        for (int b = 0; b < ds.blanks.length; b++) {
          if (blankOffset == idx) {
            final answer = ds.blanks[b].correctAnswer ?? '';
            expectedLen = answer.length.clamp(2, 20);
          }
          blankOffset++;
        }
      } else {
        if (blankOffset == idx) {
          final answer = ds.correctAnswer ?? '';
          expectedLen = answer.length.clamp(2, 20);
        }
        blankOffset++;
      }
    }

    // Adaptive width: max of expected answer length and current user input
    final currentLen = controller.text.length;
    final displayLen = (currentLen > expectedLen ? currentLen : expectedLen)
        .clamp(2, 30);
    final width = (displayLen * 11.0 + 32).clamp(60.0, 280.0);

    return Container(
      width: width,
      height: 36,
      decoration: BoxDecoration(
        color: _submitted ? fillColor : Colors.white,
        borderRadius: BorderRadius.circular(8),
        // border: Border.all(color: borderColor, width: 1.5),
      ),
      child: _submitted
          ? Center(
              child: Text(
                controller.text.isEmpty
                    ? _getCorrectAnswer(idx)
                    : controller.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: (idx < _results.length && _results[idx])
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFEF5350),
                ),
              ),
            )
          : TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !_submitted,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
              decoration: InputDecoration(
                hintText: '...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB0BEC5),
                ),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: borderColor, width: 1.5),
                ),

                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
              ),
              onChanged: (val) {
                // Rebuild to resize width adaptively
                setState(() {});
              },
            ),
    );
  }

  // ════════════════════════════════════
  //  SIMPLE INPUT (fallback)
  // ════════════════════════════════════
  Widget _buildSimpleInput(int controllerIdx, CourseTestOption option) {
    if (controllerIdx >= _controllers.length) return const SizedBox.shrink();

    final controller = _controllers[controllerIdx];
    Color borderColor = const Color(0xFFE0E0E0);
    Color fillColor = Colors.white;

    if (_submitted && controllerIdx < _results.length) {
      if (_results[controllerIdx]) {
        borderColor = const Color(0xFF4CAF50);
        fillColor = const Color(0xFFE8F5E9);
      } else {
        borderColor = const Color(0xFFEF5350);
        fillColor = const Color(0xFFFFEBEE);
      }
    }

    return TextField(
      controller: controller,
      enabled: !_submitted,
      decoration: InputDecoration(
        hintText: 'answer_hint'.tr(),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90D9), width: 2),
        ),
        filled: true,
        fillColor: fillColor,
      ),
    );
  }

  // ════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════
  String _getCorrectAnswer(int idx) {
    int offset = 0;
    for (final ds in widget.question.dataSources) {
      if (ds.blanks.isNotEmpty) {
        for (final blank in ds.blanks) {
          if (offset == idx) return blank.correctAnswer ?? '';
          offset++;
        }
      } else {
        if (offset == idx) return ds.correctAnswer ?? '';
        offset++;
      }
    }
    return '';
  }

  // ════════════════════════════════════
  //  SUBMIT
  // ════════════════════════════════════
  void _submit() {
    HapticFeedback.mediumImpact();
    final results = <bool>[];
    int controllerIdx = 0;

    for (final ds in widget.question.dataSources) {
      if (ds.blanks.isNotEmpty) {
        for (final blank in ds.blanks) {
          final userAnswer = _controllers[controllerIdx].text
              .trim()
              .toLowerCase();
          final correctAnswer = blank.correctAnswer?.trim().toLowerCase() ?? '';
          final correctAnswers = blank.correctAnswers
              .map((a) => a.trim().toLowerCase())
              .toList();

          results.add(
            userAnswer == correctAnswer || correctAnswers.contains(userAnswer),
          );
          controllerIdx++;
        }
      } else {
        final userAnswer = _controllers[controllerIdx].text
            .trim()
            .toLowerCase();
        final correctAnswer = ds.correctAnswer?.trim().toLowerCase() ?? '';
        final correctAnswers = ds.correctAnswers
            .map((a) => a.trim().toLowerCase())
            .toList();

        results.add(
          userAnswer == correctAnswer || correctAnswers.contains(userAnswer),
        );
        controllerIdx++;
      }
    }

    setState(() {
      _submitted = true;
      _results = results;
    });
    widget.onAnswered(results);
  }
}
