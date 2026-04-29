import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/core/services/openai_service.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';

/// WriteWithAI game — mirrors Unity's UIWriteWithAI + WriteWithAIUI exactly.
///
/// Flow:
///  1. Show questions with text input fields
///  2. On CHECK: build prompt → send to OpenAI → parse AIExamResult
///  3. Show per-question: correct_answer (green) + score + mistakes icon
class WriteWithAIGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const WriteWithAIGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<WriteWithAIGameWidget> createState() => _WriteWithAIGameWidgetState();
}

class _WriteWithAIGameWidgetState extends State<WriteWithAIGameWidget> {
  late List<String> _questions;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  bool _submitted = false;
  bool _isLoading = false;
  bool _storyExpanded = true;
  String? _storyText;
  List<AIExamResult> _aiResults = [];

  @override
  void initState() {
    super.initState();
    // Unity: Questions = DataSources.Select(q => q.Text)
    _questions = widget.question.dataSources.map((ds) => ds.text).toList();
    _controllers = List.generate(
      _questions.length,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(_questions.length, (_) => FocusNode());
    _loadStoryText();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  /// Load the story text from text_file_name (Unity: TextFileContent)
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
      if (mounted) {
        setState(() => _storyText = text);
      }
    } catch (e) {
      debugPrint('⚠️ Could not load story text: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Story text (read before answering) ──
        if (_storyText != null && _storyText!.isNotEmpty) _buildStorySection(),


        // Questions with text input
        for (int i = 0; i < _questions.length; i++) ...[
          _buildQuestionBlock(i),
          const SizedBox(height: 16),
        ],

        // CHECK button (Unity: UIButtonCheck)
        if (!_submitted && !_isLoading)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _allFilled ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                disabledBackgroundColor: const Color(0xFFCCCCCC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'check'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        // Loading indicator
        if (_isLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF4A90D9)),
                  SizedBox(height: 12),
                  Text(
                    'ai_analyzing'.tr(),
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool get _allFilled => _controllers.every((c) => c.text.trim().isNotEmpty);

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
          // ── Header (tap to expand/collapse) ──
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'story'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        Text(
                          'read_then_answer'.tr(),
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

          // ── Story body ──
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

  // ════════════════════════════════════════
  //  QUESTION BLOCK (Unity: WriteWithAIUI block)
  // ════════════════════════════════════════
  Widget _buildQuestionBlock(int index) {
    // Parse *Input...* from question text (Unity: BuildLine)
    final rawText = _questions[index];
    final questionText = rawText.replaceAll('*Input...*', '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question label
          if (questionText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                questionText,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Input field (Unity: TMP_InputField)
          if (!_submitted)
            TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              maxLines: 4,
              minLines: 2,
              enabled: !_submitted && !_isLoading,
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
              decoration: InputDecoration(
                hintText: 'Write here...',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB0BEC5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF2C81FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (_) => setState(() {}),
              textInputAction: index < _questions.length - 1
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: (_) {
                if (index < _questions.length - 1) {
                  _focusNodes[index + 1].requestFocus();
                }
              },
            ),

          // AI Result (after submission)
          if (_submitted && index < _aiResults.length) ...[
            const SizedBox(height: 10),
            _buildResultCard(index),
          ] else if (_submitted) ...[
            const SizedBox(height: 10),
            // Show user answer when AI didn't return result for this index
            Text(
              '${'your_answer'.tr()}: ${_controllers[index].text}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  RESULT CARD (Unity: ApplyExamResults)
  // ════════════════════════════════════════
  Widget _buildResultCard(int index) {
    final result = _aiResults[index];
    final isCorrect = result.score >= 0.8;
    final scorePercent = (result.score * 100).toInt();
    final scoreColor = result.score >= 0.8
        ? const Color(0xFF22C55E)
        : result.score >= 0.5
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    // Praise message based on score
    final praiseText = scorePercent == 100
        ? 'ai_perfect'.tr()
        : scorePercent >= 90
        ? 'ai_excellent'.tr()
        : scorePercent >= 80
        ? 'ai_good'.tr()
        : null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Praise + Score row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.info_outline,
                      color: scoreColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$scorePercent%',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (praiseText != null) ...[
                const SizedBox(width: 8),
                Text(
                  praiseText,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

        // ── User's answer ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'your_answer'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _controllers[index].text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // ── Correct answer ──
        if (result.correctAnswer != null && result.correctAnswer!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF22C55E),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'correct_answer_label'.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF22C55E).withOpacity(0.8),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.correctAnswer!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // ── Mistakes button ──
        if (result.mistakes != null && result.mistakes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showMistakesModal(result.mistakes!),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'errors_and_tips'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: const Color(0xFFF59E0B).withOpacity(0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
    );
  }

  // ════════════════════════════════════════
  //  MISTAKES MODAL (Unity: ToggleMistakeModal)
  // ════════════════════════════════════════
  void _showMistakesModal(String mistakes) {
    // Parse categorized mistakes
    final categories = <_MistakeCategory>[];
    final lines = mistakes.split('\n').where((l) => l.trim().isNotEmpty);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Grammar:') || trimmed.startsWith('Грамматика:')) {
        categories.add(
          _MistakeCategory(
            type: 'grammar',
            text: trimmed
                .replaceFirst('Grammar:', '')
                .replaceFirst('Грамматика:', '')
                .trim(),
          ),
        );
      } else if (trimmed.startsWith('Spelling:') ||
          trimmed.startsWith('Имло:')) {
        categories.add(
          _MistakeCategory(
            type: 'spelling',
            text: trimmed
                .replaceFirst('Spelling:', '')
                .replaceFirst('Имло:', '')
                .trim(),
          ),
        );
      } else if (trimmed.startsWith('Content:') ||
          trimmed.startsWith('Мазмун:')) {
        categories.add(
          _MistakeCategory(
            type: 'content',
            text: trimmed
                .replaceFirst('Content:', '')
                .replaceFirst('Мазмун:', '')
                .trim(),
          ),
        );
      } else {
        // General/uncategorized mistake
        categories.add(_MistakeCategory(type: 'general', text: trimmed));
      }
    }

    // If parsing found nothing, show raw text
    if (categories.isEmpty) {
      categories.add(_MistakeCategory(type: 'general', text: mistakes));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          // 65 % of screen height clamped to [320, 620]. On iPhone SE
          // (667pt) 65 % = 433pt — with status bar + handle + header
          // the mistakes list would be truncated. Clamp also avoids an
          // oversized sheet on tall phones / foldables.
          maxHeight: (MediaQuery.of(ctx).size.height * 0.65)
              .clamp(320.0, 620.0),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ──
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'errors_and_tips'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ai_analyzed_answer'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Categorized mistakes list ──
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                shrinkWrap: true,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  return _buildMistakeItem(cat);
                },
              ),
            ),

            // ── Close button ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'understood'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildMistakeItem(_MistakeCategory cat) {
    final config = _mistakeConfig(cat.type);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: config.iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(config.icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: config.labelColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cat.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _MistakeConfig _mistakeConfig(String type) {
    switch (type) {
      case 'grammar':
        return _MistakeConfig(
          icon: Icons.spellcheck,
          label: 'grammar_label'.tr(),
          bgColor: const Color(0xFFFEF2F2),
          borderColor: const Color(0xFFFECACA),
          iconBgColor: const Color(0xFFEF4444),
          labelColor: const Color(0xFFDC2626),
        );
      case 'spelling':
        return _MistakeConfig(
          icon: Icons.abc,
          label: 'spelling_label'.tr(),
          bgColor: const Color(0xFFFFF7ED),
          borderColor: const Color(0xFFFED7AA),
          iconBgColor: const Color(0xFFF59E0B),
          labelColor: const Color(0xFFD97706),
        );
      case 'content':
        return _MistakeConfig(
          icon: Icons.menu_book,
          label: 'content_label'.tr(),
          bgColor: const Color(0xFFEFF6FF),
          borderColor: const Color(0xFFBFDBFE),
          iconBgColor: const Color(0xFF3B82F6),
          labelColor: const Color(0xFF2563EB),
        );
      default:
        return _MistakeConfig(
          icon: Icons.info_outline,
          label: 'advice_label'.tr(),
          bgColor: const Color(0xFFF8FAFC),
          borderColor: const Color(0xFFE2E8F0),
          iconBgColor: const Color(0xFF64748B),
          labelColor: const Color(0xFF475569),
        );
    }
  }

  // ════════════════════════════════════════
  //  SUBMIT (Unity: UIWriteWithAI.OnEnable CHECK handler)
  // ════════════════════════════════════════
  void _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    // Collect answers (Unity: UIGame.CollectAnswers())
    final answers = _controllers.map((c) => c.text.trim()).toList();
    final questions = _questions
        .map((q) => q.replaceAll('*Input...*', ''))
        .toList();

    try {
      // Build prompt (Unity: UIWriteWithAI prompt building)
      final prompt = await OpenAIService.instance.buildWritePrompt(
        questions: questions,
        answers: answers,
        storyText: _storyText,
        promptAdditional: widget.question.promptAdditional,
      );

      // Send to OpenAI (Unity: OpenAIServices.Instance.SendAIRequestRoutine)
      final result = await OpenAIService.instance.sendAIRequest(prompt);

      if (result.statusCode == 200) {
        final examResults = OpenAIService.instance.parseExamResults(
          result.response,
        );

        // Unity: score > 0.8 → true
        final boolResults = <bool>[];
        for (int i = 0; i < _questions.length; i++) {
          if (i < examResults.length) {
            boolResults.add(examResults[i].score > 0.8);
          } else {
            boolResults.add(false);
          }
        }

        if (mounted) {
          setState(() {
            _submitted = true;
            _isLoading = false;
            _aiResults = examResults;
          });
          widget.onAnswered(boolResults);
        }
      } else {
        debugPrint('❌ OpenAI returned ${result.statusCode}');
        _handleAIError('Server error: ${result.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ AI error: $e');
      _handleAIError(e.toString());
    }
  }

  void _handleAIError(String error) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${'error'.tr()}: $error'),
        backgroundColor: const Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ════════════════════════════════════════
//  HELPER CLASSES
// ════════════════════════════════════════

class _MistakeCategory {
  final String type; // grammar, spelling, content, general
  final String text;
  const _MistakeCategory({required this.type, required this.text});
}

class _MistakeConfig {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color iconBgColor;
  final Color labelColor;
  const _MistakeConfig({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.iconBgColor,
    required this.labelColor,
  });
}
