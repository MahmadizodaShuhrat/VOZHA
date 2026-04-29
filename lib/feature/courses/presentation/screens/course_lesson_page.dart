import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/services/lesson_score_service.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_test_page.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';

import 'package:vozhaomuz/feature/games/presentation/screens/choose_learn_know_page.dart';

/// CourseLessonPage — Lesson detail page with 3 buttons:
/// Learning Words, Testing, WorkBook.
/// Mirrors Unity's UISelectionLessonPage.
class CourseLessonPage extends ConsumerStatefulWidget {
  final int categoryId;
  final int lessonIndex; // 0-based
  final String lessonTitle;

  const CourseLessonPage({
    required this.categoryId,
    required this.lessonIndex,
    required this.lessonTitle,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<CourseLessonPage> createState() => _CourseLessonPageState();
}

class _CourseLessonPageState extends ConsumerState<CourseLessonPage> {
  LessonMeta? _meta;
  bool _loading = true;

  // Progress data
  int _totalWords = 0;
  int _learnedWords = 0;
  List<LessonScore> _testScores = [];
  LessonScore? _workbookScore;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final meta = await CategoryDbHelper.getLessonMeta(
      widget.categoryId,
      widget.lessonIndex,
    );

    // Load word progress
    int totalWords = 0;
    int learnedWords = 0;
    try {
      final lessonWords = await CategoryDbHelper.getWordsForLesson(
        widget.categoryId,
        widget.lessonIndex,
      );
      totalWords = lessonWords.length;

      // Count how many are learned from progressProvider
      final progress = ref.read(progressProvider);
      final allProgressWords = <int, int>{}; // wordId → state
      for (final entry in progress.dirs.values) {
        for (final wp in entry) {
          allProgressWords[wp.wordId] = wp.state;
        }
      }
      for (final w in lessonWords) {
        final state = allProgressWords[w.id];
        if (state != null && state != 0) {
          learnedWords++;
        }
      }
    } catch (_) {}

    // Load test/workbook scores
    final testScores = await LessonScoreService.getTestScores(
      widget.categoryId,
      widget.lessonIndex,
    );
    final workbookScore = await LessonScoreService.getWorkbookScore(
      widget.categoryId,
      widget.lessonIndex,
    );

    if (mounted) {
      setState(() {
        _meta = meta;
        _totalWords = totalWords;
        _learnedWords = learnedWords;
        _testScores = testScores;
        _workbookScore = workbookScore;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // After popping back from the result page, the 3-second delayed
    // `fetchProgressFromBackend` often finishes AFTER `_loadAll` already ran
    // with stale data — so the unit progress % stayed frozen until the user
    // left and re-entered. Re-run `_loadAll` whenever `progressProvider`
    // emits a new state so the card refreshes live.
    ref.listen(progressProvider, (_, _) {
      if (mounted) _loadAll();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5FAFF),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 24),
        ),
        title: Text(
          widget.lessonTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202939),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E90FA)))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final meta = _meta;
    if (meta == null) {
      return Center(
        child: Text('error_loading'.tr(),
            style: const TextStyle(fontSize: 16)),
      );
    }

    // Compute test progress
    final testsDone = _testScores.length;
    final testsTotal = meta.testCount;
    double testAvgPercent = 0;
    if (_testScores.isNotEmpty) {
      testAvgPercent =
          _testScores.map((s) => s.percent).reduce((a, b) => a + b) /
              _testScores.length;
    }
    final allTestsDone = testsTotal > 0 && testsDone >= testsTotal;

    // Word progress
    final wordsDone = _totalWords > 0 && _learnedWords >= _totalWords;
    final wordProgress =
        _totalWords > 0 ? (_learnedWords / _totalWords).clamp(0.0, 1.0) : 0.0;

    // Workbook progress
    final workbookDone = _workbookScore != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // ─── Learning Words ───
          if (meta.hasLearningWords)
            _buildActionCard(
              icon: Icons.style_rounded,
              title: 'learning_words'.tr(),
              iconColor: const Color(0xFF2E90FA),
              iconBgColor: const Color(0xFFD1E9FF),
              isDone: wordsDone,
              subtitle: _totalWords > 0
                  ? '$_learnedWords / $_totalWords'
                  : null,
              progress: wordProgress,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChoseLearnKnowPage(
                      categoryId: widget.categoryId,
                      lessonIndex: widget.lessonIndex,
                      lessonTitle: widget.lessonTitle,
                    ),
                  ),
                ).then((_) => _loadAll());
              },
            ),

          if (meta.hasLearningWords) const SizedBox(height: 10),

          // ─── Testing ───
          if (meta.hasTests)
            _buildActionCard(
              icon: Icons.quiz_rounded,
              title: 'testing'.tr(),
              iconColor: const Color(0xFF12B76A),
              iconBgColor: const Color(0xFFD1FADF),
              isDone: allTestsDone,
              subtitle: _testScores.isNotEmpty
                  ? '$testsDone / $testsTotal  ·  ${'avg'.tr()}: ${testAvgPercent.toStringAsFixed(0)}%'
                  : '$testsDone / $testsTotal',
              progress: testsTotal > 0
                  ? (testsDone / testsTotal).clamp(0.0, 1.0)
                  : 0.0,
              onTap: () {
                HapticFeedback.lightImpact();
                _openTests();
              },
            ),

          if (meta.hasTests) const SizedBox(height: 10),

          // ─── WorkBook ───
          if (meta.hasWorkbook)
            _buildActionCard(
              icon: Icons.auto_stories_rounded,
              title: 'work_book'.tr(),
              iconColor: const Color(0xFFF79009),
              iconBgColor: const Color(0xFFFEF0C7),
              isDone: workbookDone,
              subtitle: workbookDone
                  ? '${_workbookScore!.percent.toStringAsFixed(0)}%'
                  : null,
              progress: workbookDone ? 1.0 : 0.0,
              onTap: () {
                HapticFeedback.lightImpact();
                _openWorkbook();
              },
            ),

          // ─── No content ───
          if (!meta.hasLearningWords && !meta.hasTests && !meta.hasWorkbook)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('no_content_available'.tr(),
                        style: const TextStyle(
                            fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// VozhaOmuz-style white card with colored icon and progress info
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    String? subtitle,
    double progress = 0.0,
    bool isDone = false,
  }) {
    // Card colors based on state
    final cardBg = isDone
        ? const Color(0xFFF0FDF4) // soft green tint
        : Colors.white;
    final cardBorder = isDone
        ? const Color(0xFFBBF7D0) // green border
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: isDone ? 1.5 : 0),
          boxShadow: isDone
              ? [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // ─── Icon ───
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFFDCFCE7) // green bg when done
                        : iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF22C55E), size: 28)
                      : Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 14),

                // ─── Title + Subtitle ───
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? const Color(0xFF166534)
                              : const Color(0xFF202939),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDone
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ─── Trailing indicator ───
                if (isDone)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '✓',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right,
                      color: Color(0xFFD0D5DD), size: 22),
              ],
            ),

            // ─── Progress bar (only if in progress) ───
            if (progress > 0 && progress < 1.0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTests() async {
    final tests = await CategoryDbHelper.getTestsForLesson(
      widget.categoryId,
      widget.lessonIndex,
    );
    if (!mounted || tests.isEmpty) return;

    if (tests.length == 1) {
      // Single test — go directly
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseTestPage(
            testData: tests.first,
            categoryId: widget.categoryId,
            lessonIndex: widget.lessonIndex,
            testIndex: 0,
          ),
        ),
      );
      _loadAll(); // Refresh scores on return
    } else {
      // Multiple tests — show selection dialog
      _showTestSelectionDialog(tests);
    }
  }

  Future<void> _openWorkbook() async {
    final workbook = await CategoryDbHelper.getWorkbookForLesson(
      widget.categoryId,
      widget.lessonIndex,
    );
    if (!mounted || workbook == null) return;

    if (workbook.sections.length == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseTestPage(
            testData: workbook,
            sectionIndex: 0,
            categoryId: widget.categoryId,
            lessonIndex: widget.lessonIndex,
          ),
        ),
      );
      _loadAll(); // Refresh scores on return
    } else {
      // Multiple sections — show selection
      _showSectionSelectionDialog(workbook);
    }
  }

  // ─── Unity-style centered modal dialog ───
  void _showTestSelectionDialog(List<CourseTestData> tests) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _UnityStyleModal(
        title: 'select_test'.tr(),
        items: tests.map((t) => t.testTitle).toList(),
        scores: List.generate(tests.length, (i) {
          if (i < _testScores.length) return _testScores[i];
          return null;
        }),
        onItemTap: (index) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseTestPage(
                testData: tests[index],
                categoryId: widget.categoryId,
                lessonIndex: widget.lessonIndex,
                testIndex: index,
              ),
            ),
          ).then((_) => _loadAll());
        },
      ),
    );
  }

  void _showSectionSelectionDialog(CourseTestData workbook) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _UnityStyleModal(
        title: 'select_section'.tr(),
        items: workbook.sections.map((s) => s.title).toList(),
        onItemTap: (index) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CourseTestPage(
                    testData: workbook,
                    sectionIndex: index,
                    categoryId: widget.categoryId,
                    lessonIndex: widget.lessonIndex,
                  ),
            ),
          ).then((_) => _loadAll());
        },
      ),
    );
  }
}

/// Unity-style centered modal with X button and white option cards.
/// Matches the UI from the Unity app's "Выберите тест" popup.
class _UnityStyleModal extends StatelessWidget {
  final String title;
  final List<String> items;
  final List<LessonScore?>? scores;
  final void Function(int index) onItemTap;

  const _UnityStyleModal({
    required this.title,
    required this.items,
    required this.onItemTap,
    this.scores,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(
            // 70 % clamped to [360, 600]. iPhone SE (667pt) needs at
            // least 360pt for the header + content + close button, and
            // a taller phone shouldn't have the dialog swallow the
            // whole screen.
            maxHeight: (MediaQuery.of(context).size.height * 0.7)
                .clamp(360.0, 600.0),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Header with title + X button ───
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Option cards ───
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final score =
                        scores != null && index < scores!.length
                            ? scores![index]
                            : null;
                    final hasDone = score != null;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onItemTap(index);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: hasDone
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF5F8FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasDone
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFFE8EEFF),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                items[index],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: hasDone
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF2D2D3A),
                                ),
                              ),
                            ),
                            if (hasDone)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: score.percent >= 70
                                      ? const Color(0xFF22C55E)
                                      : score.percent >= 40
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${score.percent.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
