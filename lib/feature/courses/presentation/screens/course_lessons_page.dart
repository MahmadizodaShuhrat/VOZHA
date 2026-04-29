import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_lesson_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Lesson list page — matches Unity's UISelectionSubCategoryPage
/// with VozhaOmuz-style enhancements.
class CourseLessonsPage extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryTitle;

  const CourseLessonsPage({
    required this.categoryId,
    required this.categoryTitle,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<CourseLessonsPage> createState() => _CourseLessonsPageState();
}

class _CourseLessonsPageState extends ConsumerState<CourseLessonsPage> {
  /// Number of free (unlocked) units for non-premium users
  static const int _freeUnitsCount = 3;

  List<_LessonItem> _lessons = [];
  bool _loading = true;
  String? _error;

  bool get _isPremium => StorageService.instance.isPremium();

  bool _isUnitLocked(int index) => !_isPremium && index >= _freeUnitsCount;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final coursePath =
          await CategoryResourceService.getCoursePath(widget.categoryId);
      if (coursePath == null) {
        setState(() {
          _error = 'course_not_found'.tr();
          _loading = false;
        });
        return;
      }

      final manifestFile = File(p.join(coursePath, 'manifest.json'));
      if (!manifestFile.existsSync()) {
        setState(() {
          _error = 'manifest_not_found'.tr();
          _loading = false;
        });
        return;
      }

      final manifestJson = jsonDecode(await manifestFile.readAsString());
      final lessonPaths = List<String>.from(manifestJson['lessons'] ?? []);

      final prefs = await SharedPreferences.getInstance();
      String savedLocale = 'tg';
      final localeStr = prefs.getString('locale');
      if (localeStr != null && localeStr.isNotEmpty) {
        savedLocale = localeStr.split('_').first;
      }
      final titlesKey = switch (savedLocale) {
        'tg' => 'Таджикский',
        'ru' => 'Русский',
        'en' => 'English',
        _ => 'Таджикский',
      };

      // Build set of learned word IDs for this category from all directions
      final progress = ref.read(progressProvider);
      final learnedWordIds = <int>{};
      for (final entry in progress.dirs.values) {
        for (final wp in entry) {
          if (wp.categoryId == widget.categoryId &&
              wp.state > 0 &&
              !wp.firstDone) {
            learnedWordIds.add(wp.wordId);
          }
        }
      }

      final lessons = <_LessonItem>[];
      for (int i = 0; i < lessonPaths.length; i++) {
        final lessonFilePath = p.join(coursePath, lessonPaths[i]);
        final lessonFile = File(lessonFilePath);
        if (!lessonFile.existsSync()) continue;

        try {
          final json = jsonDecode(await lessonFile.readAsString())
              as Map<String, dynamic>;
          final meta = await CategoryDbHelper.getLessonMeta(
            widget.categoryId,
            i,
          );

          String title = '${'lesson'.tr()} ${i + 1}';
          if (json['titles'] is Map) {
            final titles = Map<String, dynamic>.from(json['titles']);
            title = (titles[titlesKey] ??
                    titles.values.firstWhere(
                      (v) => v is String && v.toString().isNotEmpty,
                      orElse: () => title,
                    ))
                .toString();
          } else {
            title = json['title']?.toString() ??
                json['name']?.toString() ??
                title;
          }

          // Load words for this lesson to calculate progress
          final words = await CategoryDbHelper.getWordsForLesson(
            widget.categoryId,
            i,
          );
          final wordCount = words.length;
          final learnedCount =
              words.where((w) => learnedWordIds.contains(w.id)).length;

          lessons.add(_LessonItem(
            index: i,
            title: title,
            hasLearningWords: meta.hasLearningWords,
            hasTests: meta.hasTests,
            hasWorkbook: meta.hasWorkbook,
            testCount: meta.testCount,
            wordCount: wordCount,
            learnedCount: learnedCount,
          ));
        } catch (e) {
          debugPrint('⚠️ Failed to parse lesson $i: $e');
        }
      }

      if (mounted) {
        setState(() {
          _lessons = lessons;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '${'error'.tr()}: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          icon: const Icon(Icons.arrow_back_ios,
              color: Colors.black, size: 22),
        ),
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202939),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E90FA)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red.shade600)),
          ],
        ),
      );
    }
    if (_lessons.isEmpty) {
      return Center(
        child: Text(
          'no_lessons'.tr(),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Calculate overall progress
    final totalWords = _lessons.fold<int>(0, (sum, l) => sum + l.wordCount);
    final totalLearned = _lessons.fold<int>(0, (sum, l) => sum + l.learnedCount);
    final overallPercent = totalWords > 0 ? (totalLearned / totalWords * 100).round() : 0;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      itemCount: _lessons.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader(totalLearned, totalWords, overallPercent);
        return _buildLessonCard(_lessons[index - 1], _isUnitLocked(index - 1));
      },
    );
  }

  Widget _buildHeader(int learned, int total, int percent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E90FA), Color(0xFF1570EF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Progress circle
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: total > 0 ? learned / total : 0,
                    strokeWidth: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.categoryTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$learned / $total ${'words'.tr().toLowerCase()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? learned / total : 0,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// VozhaOmuz-style card with progress ring, title, and content badges
  Widget _buildLessonCard(_LessonItem lesson, bool locked) {
    final percent = lesson.wordCount > 0
        ? (lesson.learnedCount / lesson.wordCount * 100).round()
        : 0;
    // Circle color: blue → yellow (100%)
    final circleColor = percent >= 100
        ? const Color(0xFFF79009)
        : percent > 0
            ? Color.lerp(const Color(0xFF2E90FA), const Color(0xFFF79009),
                percent / 100.0)!
            : const Color(0xFF2E90FA);
    final circleBgColor = percent >= 100
        ? const Color(0xFFFEF0C7)
        : percent > 0
            ? Color.lerp(const Color(0xFFD1E9FF), const Color(0xFFFEF0C7),
                percent / 100.0)!
            : const Color(0xFFD1E9FF);

    final bool isComplete = percent >= 100;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (locked) {
          _showPremiumDialog();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            // `popUntil` дар ResultGamePage._exitFromResult аз рӯи ин
            // RouteName-и аниқ корбарро ба ин саҳифа бар мегардонад.
            settings: const RouteSettings(name: 'CourseLessonPage'),
            builder: (_) => CourseLessonPage(
              categoryId: widget.categoryId,
              lessonIndex: lesson.index,
              lessonTitle: lesson.title,
            ),
          ),
        ).then((_) {
          // Баъди баргашт (тапп-и Баромадан, swipe back, ё ҳар хели
          // дигар) маълумоти units-ро аз нав бор мекунем — то фоиз ва
          // прогресс-и нав фавран нишон дода шавад. Бе ин корбар
          // мебинад: "ман гузаштам, лекин Unit 1 ҳамоно 90% нишон
          // медиҳад" — то даме ки аз саҳифа бароёд ва баргардад.
          if (mounted) _loadLessons();
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: locked
              ? const Color(0xFFF2F4F7)
              : isComplete
                  ? const Color(0xFFFFFBF0)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isComplete && !locked
              ? Border.all(color: const Color(0xFFFDB022).withValues(alpha: 0.4), width: 1.5)
              : null,
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Opacity(
          opacity: locked ? 0.55 : 1.0,
          child: Row(
            children: [
              // ── Lesson number / lock / checkmark ──
              if (locked)
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE4E7EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_rounded,
                        color: Color(0xFF98A2B3), size: 20),
                  ),
                )
              else if (isComplete)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFDB022), Color(0xFFF79009)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF79009).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
                  ),
                )
              else
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: lesson.wordCount > 0
                              ? lesson.learnedCount / lesson.wordCount
                              : 0,
                          strokeWidth: 3.5,
                          backgroundColor: circleBgColor,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(circleColor),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: circleBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${lesson.index + 1}',
                            style: TextStyle(
                              color: circleColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 14),

              // ── Title + progress bar + content badges ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: locked
                                  ? const Color(0xFF98A2B3)
                                  : const Color(0xFF344054),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        if (!locked && lesson.wordCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? const Color(0xFFFEF0C7)
                                  : circleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: circleColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Progress bar (only for unlocked)
                    if (!locked && lesson.wordCount > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: lesson.learnedCount / lesson.wordCount,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFEAECF0),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(circleColor),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Content type indicators
                    Row(
                      children: [
                        if (lesson.hasLearningWords)
                          _contentTag(
                            Icons.style_rounded,
                            'words'.tr(),
                            locked
                                ? const Color(0xFF98A2B3)
                                : const Color(0xFF2E90FA),
                          ),
                        if (lesson.hasTests)
                          _contentTag(
                            Icons.quiz_rounded,
                            'testing'.tr(),
                            locked
                                ? const Color(0xFF98A2B3)
                                : const Color(0xFF12B76A),
                          ),
                        if (lesson.hasWorkbook)
                          _contentTag(
                            Icons.auto_stories_rounded,
                            'work_book'.tr(),
                            locked
                                ? const Color(0xFF98A2B3)
                                : const Color(0xFFF79009),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                locked ? Icons.lock_rounded : Icons.chevron_right_rounded,
                color: locked
                    ? const Color(0xFFD0D5DD)
                    : const Color(0xFF98A2B3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Frame.png', width: 120, height: 120),
              const SizedBox(height: 20),
              Text(
                'battle_premium_only'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              MyButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MySubscriptionPage(),
                    ),
                  );
                },
                width: double.infinity,
                buttonColor: const Color(0xFFFDB022),
                backButtonColor: const Color(0xFFF79009),
                borderRadius: 14,
                child: Text(
                  'battle_buy_premium'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              MyButton(
                onPressed: () => Navigator.of(context).pop(),
                width: double.infinity,
                buttonColor: Colors.white,
                backButtonColor: const Color(0xFFD0D5DD),
                borderRadius: 14,
                border: 1.5,
                borderColor: const Color(0xFFD0D5DD),
                child: Text(
                  'battle_got_it'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small icon + text tag showing available content type
  Widget _contentTag(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonItem {
  final int index;
  final String title;
  final bool hasLearningWords;
  final bool hasTests;
  final bool hasWorkbook;
  final int testCount;
  final int wordCount;
  final int learnedCount;

  _LessonItem({
    required this.index,
    required this.title,
    required this.hasLearningWords,
    required this.hasTests,
    required this.hasWorkbook,
    required this.testCount,
    required this.wordCount,
    required this.learnedCount,
  });
}
