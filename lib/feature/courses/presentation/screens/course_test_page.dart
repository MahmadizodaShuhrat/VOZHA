import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/core/services/lesson_score_service.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/categorize_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/collect_words_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/crossword_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/drag_drop_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/dropdown_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/fill_blank_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/matching_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/multi_choice_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/ordering_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/select_answers_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/speaking_with_ai_game.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/write_with_ai_game.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// CourseTestPage — Main test engine page.
/// Mirrors Unity's UIGamesCourses layout:
/// - Section name header with back button
/// - Progress bar with "X/Y" indicator
/// - ScrollView with all games in current section
/// - UITaskTotal after each game (score/total)
/// - UISectionTotal at the end
/// - NEXT button — only active when all section answered
/// - After last section → results screen
class CourseTestPage extends StatefulWidget {
  final CourseTestData testData;
  final int? sectionIndex; // If set, only show this section (workbook mode)
  final int categoryId;
  final int lessonIndex;
  final int testIndex;

  const CourseTestPage({
    required this.testData,
    this.sectionIndex,
    this.categoryId = 0,
    this.lessonIndex = 0,
    this.testIndex = 0,
    super.key,
  });

  @override
  State<CourseTestPage> createState() => _CourseTestPageState();
}

class _CourseTestPageState extends State<CourseTestPage> {
  int _currentSectionIdx = 0;
  int _totalQuestions = 0;
  int _questionsDone = 0; // across all sections

  // Score tracking: questionId -> results
  final Map<String, List<bool>> _scoreMap = {};
  // Track which questions in current section are answered
  final Set<String> _answeredInSection = {};

  late List<CourseTestSection> _sections;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.sectionIndex != null) {
      _sections = [widget.testData.sections[widget.sectionIndex!]];
    } else {
      _sections = widget.testData.sections;
    }
    _totalQuestions = _sections.fold(0, (sum, s) => sum + s.questions.length);
    _currentSectionIdx = 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  CourseTestSection get _currentSection => _sections[_currentSectionIdx];

  bool get _allCurrentSectionAnswered =>
      _answeredInSection.length >= _currentSection.questions.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header: Back + Section Name (Unity: UIButtonBack + UISectionName) ───
            _buildHeader(),

            // ─── Progress Bar (Unity: UITextProgress + UIProgressBar) ───
            _buildProgressBar(),

            // ─── All questions in ScrollView (Unity: UIContent ScrollRect) ───
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Render all questions in this section
                    for (
                      int i = 0;
                      i < _currentSection.questions.length;
                      i++
                    ) ...[
                      _buildQuestionBlock(i),
                      // Unity: UITaskTotal after each game
                      _buildTaskTotal(i),
                      const SizedBox(height: 24),
                    ],
                    // Unity: UISectionTotal at the bottom
                    _buildSectionTotal(),
                    const SizedBox(height: 20), // space for NEXT button
                  ],
                ),
              ),
            ),

            // ─── NEXT Button (Unity: UINextGame — only active when all answered) ───
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  /// Unity: UIButtonBack + UISectionName — header with back button and section title
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90D9), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90D9).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Expanded(
          //   child: Text(
          //     _currentSection.title,
          //     textAlign: TextAlign.center,
          //     style: const TextStyle(
          //       color: Colors.white,
          //       fontSize: 17,
          //       fontWeight: FontWeight.w700,
          //       letterSpacing: -0.2,
          //     ),
          //   ),
          // ),
          // const SizedBox(width: 50),
        ],
      ),
    );
  }

  /// Unity: UITextProgress + UIProgressBar
  Widget _buildProgressBar() {
    final currentQuestionInTotal = _questionsDone + _answeredInSection.length;
    final progress = _totalQuestions > 0
        ? currentQuestionInTotal / _totalQuestions
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Unity: UITextProgress — "{IndexTest + 1}/{MaxTest}"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4A90D9).withOpacity(0.12),
                      const Color(0xFF6366F1).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4A90D9).withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_lesson_rounded,
                      size: 14,
                      color: const Color(0xFF4A90D9),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${currentQuestionInTotal + 1} / $_totalQuestions',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A90D9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Unity: UIProgressBar — fill amount
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFFE8ECF0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A90D9), Color(0xFF6BA3E8)],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionBlock(int questionIndex) {
    final question = _currentSection.questions[questionIndex];
    final basePath = widget.testData.currentPath;
    final isAnswered = _answeredInSection.contains(question.id);

    return Container(
      key: ValueKey('q_${question.id}'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAnswered ? const Color(0xFFE0E0E0) : const Color(0xFFE8ECF0),
          width: 1,
        ),
        boxShadow: [
          if (!isAnswered)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reading text from file (workbook passage)
          // Skip for AI games — they display their own story section
          if (question.textFileName != null && question.textFileName!.isNotEmpty &&
              question.type != 'WriteWithAI' && question.type != 'UIWriteWithAI' &&
              question.type != 'SpeakingWithAI' && question.type != 'UISpeakingWithAI')
            _buildReadingText(question.textFileName!, basePath),

          // Question title
          if (question.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                question.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                  height: 1.4,
                ),
              ),
            ),

          // Additional prompt
          if (question.promptAdditional != null && question.promptAdditional!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                question.promptAdditional!,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF555555),
                  height: 1.4,
                ),
              ),
            ),

          // Question image
          if (question.spriteName != null && question.spriteName!.isNotEmpty)
            _buildQuestionImage(question),

          // Game widget (includes its own CHECK button)
          _buildGameWidget(question, basePath),
        ],
      ),
    );
  }

  /// Load and display reading passage from a text file
  Widget _buildReadingText(String textFileName, String basePath) {
    // Extract just the file basename (strip directory prefix like "texts/")
    final baseName = textFileName.split('/').last;
    // Fix double extension
    final fixedName = baseName.endsWith('.txt.txt')
        ? baseName.substring(0, baseName.length - 4)
        : baseName;

    // Try multiple path variations to find the text file
    final candidates = <String>[
      '$basePath/$textFileName',                           // exact path from JSON
      '$basePath/$fixedName',                              // basename only
      '$basePath/texts/$fixedName',                        // texts/ + fixed name
      '$basePath/texts/$baseName',                         // texts/ + original name
    ];

    File? foundFile;
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        foundFile = f;
        break;
      }
    }

    // Fallback: recursive search in basePath and parent directory
    if (foundFile == null) {
      final searchDirs = [basePath, Directory(basePath).parent.path];
      for (final searchDir in searchDirs) {
        try {
          final dir = Directory(searchDir);
          if (!dir.existsSync()) continue;
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is File) {
              final name = entity.path.split(Platform.pathSeparator).last;
              if (name == fixedName || name == baseName) {
                foundFile = entity;
                break;
              }
            }
          }
          if (foundFile != null) break;
        } catch (_) {}
      }
    }

    if (foundFile == null) {
      // Debug: list what's in the texts/ subdirectory
      final textsDir = Directory('$basePath/texts');
      if (textsDir.existsSync()) {
        final files = textsDir.listSync().map((e) => e.path.split(Platform.pathSeparator).last).toList();
        debugPrint('⚠️ Text file "$fixedName" not found. texts/ contains: $files');
      } else {
        debugPrint('⚠️ Text file "$fixedName" not found. No texts/ directory in $basePath');
      }
      return const SizedBox.shrink();
    }

    final text = foundFile.readAsStringSync();
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD1E9FF),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              Text(
                'reading'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A90D9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: _parseHtmlText(
              text.trim(),
              const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Parse simple HTML tags (<b>, <i>) into TextSpan tree
  TextSpan _parseHtmlText(String html, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'<(/?)(b|i|strong|em)>', caseSensitive: false);
    int lastEnd = 0;
    bool isBold = false;
    bool isItalic = false;

    for (final match in regex.allMatches(html)) {
      // Add text before this tag
      if (match.start > lastEnd) {
        final segment = html.substring(lastEnd, match.start);
        spans.add(TextSpan(
          text: segment,
          style: baseStyle.copyWith(
            fontWeight: isBold ? FontWeight.w700 : baseStyle.fontWeight,
            fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
          ),
        ));
      }

      final isClosing = match.group(1) == '/';
      final tag = match.group(2)!.toLowerCase();

      if (tag == 'b' || tag == 'strong') {
        isBold = !isClosing;
      } else if (tag == 'i' || tag == 'em') {
        isItalic = !isClosing;
      }

      lastEnd = match.end;
    }

    // Remaining text after last tag
    if (lastEnd < html.length) {
      spans.add(TextSpan(
        text: html.substring(lastEnd),
        style: baseStyle.copyWith(
          fontWeight: isBold ? FontWeight.w700 : baseStyle.fontWeight,
          fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
        ),
      ));
    }

    if (spans.isEmpty) {
      return TextSpan(text: html, style: baseStyle);
    }

    return TextSpan(children: spans);
  }

  Widget _buildQuestionImage(CourseTestQuestion question) {
    final spritePath = '${widget.testData.currentPath}/${question.spriteName}';
    final file = File(spritePath);
    if (!file.existsSync()) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(file, width: double.infinity, fit: BoxFit.contain),
      ),
    );
  }

  /// Unity: UITaskTotal — shows "score/total" aligned right after each game
  /// UITaskTotal has UISecore (claimed score) + UISecores (total count)
  Widget _buildTaskTotal(int questionIndex) {
    final question = _currentSection.questions[questionIndex];
    final results = _scoreMap[question.id];
    final isAnswered = _answeredInSection.contains(question.id);

    if (!isAnswered || results == null) return const SizedBox.shrink();

    final correct = results.where((r) => r).length;
    final total = results.length;
    final isAllCorrect = correct == total;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isAllCorrect
              ? const Color(0xFFE5FFEE)
              : const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isAllCorrect
                ? const Color(0xFF1BD259)
                : const Color(0xFFFF3700),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAllCorrect ? Icons.check_circle : Icons.info_outline,
              size: 18,
              color: isAllCorrect
                  ? const Color(0xFF1BD259)
                  : const Color(0xFFFF3700),
            ),
            const SizedBox(width: 6),
            // Unity: UISecore / UISecores
            Text(
              '$correct/$total',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isAllCorrect
                    ? const Color(0xFF1BD259)
                    : const Color(0xFFFF3700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unity: UISectionTotal — total for entire section
  /// Shows section name + total score badge
  Widget _buildSectionTotal() {
    if (!_allCurrentSectionAnswered) return const SizedBox.shrink();

    int totalCorrect = 0;
    int totalCount = 0;
    for (final q in _currentSection.questions) {
      final results = _scoreMap[q.id];
      if (results != null) {
        totalCorrect += results.where((r) => r).length;
        totalCount += results.length;
      }
    }

    final percent = totalCount > 0 ? (totalCorrect / totalCount * 100) : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: percent >= 70
              ? [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)]
              : percent >= 40
              ? [const Color(0xFFFFF8E1), const Color(0xFFFFF3E0)]
              : [const Color(0xFFFFEBEE), const Color(0xFFFCE4EC)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: percent >= 70
              ? const Color(0xFF4CAF50)
              : percent >= 40
              ? const Color(0xFFFFC107)
              : const Color(0xFFFF5252),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Unity: UISectionName
          Text(
            _currentSection.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          // Score circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: percent >= 70
                    ? [const Color(0xFF43A047), const Color(0xFF2E7D32)]
                    : percent >= 40
                    ? [const Color(0xFFFFA726), const Color(0xFFF57C00)]
                    : [const Color(0xFFEF5350), const Color(0xFFC62828)],
              ),
            ),
            child: Center(
              child: Text(
                '${percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Total score text
          Text(
            '$totalCorrect / $totalCount',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameWidget(CourseTestQuestion question, String basePath) {
    switch (question.type) {
      case 'MultiChoiceGame':
      case 'UIMultiChoiceGame':
        return MultiChoiceGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'SelectAnswers':
      case 'UISelectAnswers':
        return SelectAnswersGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'SelectMoreAnswers':
      case 'UISelectMoreAnswers':
        return SelectAnswersGameWidget(
          question: question,
          basePath: basePath,
          multiSelect: true,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'FillBlankGame':
      case 'UIFillBlankGame':
        return FillBlankGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'Ordering':
      case 'UIOrdering':
        return OrderingGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'DropDownGame':
      case 'UIDropDownGame':
        return DropDownGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'DragDropItems':
      case 'UIDragDropItems':
        return DragDropGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'CollectWords':
      case 'UICollectWords':
        return CollectWordsGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'CategorizeGame':
      case 'UICategorizeGame':
        return CategorizeGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'MatchingGame':
      case 'UIMatchingGame':
        return MatchingGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'CrossWord':
      case 'UICrossWord':
        return CrossWordGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'SpeakingWithAI':
      case 'UISpeakingWithAI':
        return SpeakingWithAIGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      case 'WriteWithAI':
      case 'UIWriteWithAI':
        return WriteWithAIGameWidget(
          question: question,
          basePath: basePath,
          onAnswered: (results) => _onGameAnswered(question.id, results),
        );
      default:
        // Unsupported game type — placeholder
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              const Icon(Icons.extension, size: 40, color: Colors.orange),
              const SizedBox(height: 8),
              Text(
                '${'unsupported_game_type'.tr()}: ${question.type}',
                style: const TextStyle(fontSize: 14, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              MyButton(
                height: 40,
                borderRadius: 10,
                depth: 4,
                buttonColor: Colors.orange,
                backButtonColor: Colors.orange.shade700,
                onPressed: () {
                  _onGameAnswered(question.id, [false]);
                },
                child: Text(
                  'skip'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Called when a game's CHECK button is pressed
  void _onGameAnswered(String questionId, List<bool> results) {
    if (_scoreMap.containsKey(questionId)) return; // already answered

    setState(() {
      _scoreMap[questionId] = results;
      _answeredInSection.add(questionId);
    });
  }

  /// Unity: UINextGame — bottom button, only active when all section answered
  Widget _buildNextButton() {
    final isActive = _allCurrentSectionAnswered;
    final isLast = _currentSectionIdx >= _sections.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: MyButton(
          height: 52,
          borderRadius: 14,
          buttonColor: isActive
              ? const Color(0xFF4A90D9)
              : const Color(0xFFCCCCCC),
          backButtonColor: isActive
              ? const Color(0xFF3A7BC8)
              : const Color(0xFFB0B0B0),
          onPressed: isActive ? _nextSection : null,
          child: Text(
            isLast ? 'finish'.tr() : 'next'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Unity: NextGameInternal → move to next section or show results
  void _nextSection() {
    HapticFeedback.mediumImpact();
    _questionsDone += _currentSection.questions.length;

    if (_currentSectionIdx < _sections.length - 1) {
      setState(() {
        _currentSectionIdx++;
        _answeredInSection.clear();
      });
      // Unity: ResetScrollToTop (animated)
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      // All sections done → show results
      _showResults();
    }
  }

  /// Unity: UICoursesResults — final results dialog
  void _showResults() {
    int correctCount = 0;
    int totalCount = 0;
    for (final entry in _scoreMap.entries) {
      for (final result in entry.value) {
        totalCount++;
        if (result) correctCount++;
      }
    }

    final percent = totalCount > 0 ? (correctCount / totalCount * 100) : 0;

    // Persist score for lesson progress display
    final scoreType = widget.sectionIndex != null ? 'workbook' : 'test';
    LessonScoreService.saveScore(
      categoryId: widget.categoryId,
      lessonIndex: widget.lessonIndex,
      type: scoreType,
      testIndex: widget.testIndex,
      correct: correctCount,
      total: totalCount,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                'results'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 20),
              // Score circle
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: percent >= 70
                        ? [const Color(0xFF43A047), const Color(0xFF2E7D32)]
                        : percent >= 40
                        ? [const Color(0xFFFFA726), const Color(0xFFF57C00)]
                        : [const Color(0xFFEF5350), const Color(0xFFC62828)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (percent >= 70
                                  ? const Color(0xFF43A047)
                                  : percent >= 40
                                  ? const Color(0xFFFFA726)
                                  : const Color(0xFFEF5350))
                              .withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Score count
              Text(
                '$correctCount / $totalCount',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'correct_answers'.tr(),
                style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 24),
              // OK button
              SizedBox(
                width: double.infinity,
                child: MyButton(
                  height: 48,
                  borderRadius: 14,
                  buttonColor: const Color(0xFF4A90D9),
                  backButtonColor: const Color(0xFF3A7BC8),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'ok'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
