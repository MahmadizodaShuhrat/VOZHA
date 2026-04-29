import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/feature/courses/presentation/providers/course_progress_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_test_page.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/lesson_player_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/choose_learn_know_page.dart';

/// Lesson hub — the page the user lands on after tapping a module on
/// the course-detail screen. Mirrors the Unity reference design:
/// a big intro video at the top, the sub-lessons listed below, then
/// a "Пройти тест" button (locked until every sub-lesson is done) and
/// an "Изучать слова X/Y" progress bar.
class LessonHubPage extends ConsumerWidget {
  final String courseId;
  final CourseModule module;
  final int moduleIndex;

  const LessonHubPage({
    super.key,
    required this.courseId,
    required this.module,
    required this.moduleIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedIds =
        ref.watch(courseProgressProvider(courseId)).asData?.value ??
            const <String>{};

    final completedSubLessons = module.lessons
        .where((l) => completedIds.contains(l.id))
        .length;
    final allSubDone = completedSubLessons == module.lessons.length &&
        module.lessons.isNotEmpty;

    final wordsLearned = module.lessons
        .where((l) => completedIds.contains(l.id))
        .fold<int>(0, (sum, l) => sum + l.words.length);

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (module.mainVideo != null) ...[
                      _MainVideoCard(video: module.mainVideo!),
                      const SizedBox(height: 14),
                      Text(
                        'lesson_hub_watch_to_unlock'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (int i = 0; i < module.lessons.length; i++) ...[
                      _SubLessonCard(
                        lesson: module.lessons[i],
                        isCompleted:
                            completedIds.contains(module.lessons[i].id),
                        courseId: courseId,
                        index: i,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (module.finalTest != null) ...[
                      const SizedBox(height: 8),
                      _FinalTestCard(
                        test: module.finalTest!,
                        unlocked: allSubDone,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _WordsProgressCard(
                      learned: wordsLearned,
                      total: module.totalWords,
                      module: module,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1D2939), size: 20),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  module.subtitle ??
                      '${'lesson_hub_lesson_word'.tr()} ${moduleIndex + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF98A2B3),
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  module.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MainVideoCard extends StatelessWidget {
  final LessonVideo video;
  const _MainVideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    // We just render a thumbnail/play badge here; tapping kicks the
    // user into the full player page. Keeps this hub page lightweight
    // (no native video controllers spinning while scrolling).
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonPlayerPage(
                lesson: CourseLesson(
                  id: 'hub_main_video',
                  type: LessonType.video,
                  title: 'lesson_hub_intro_title'.tr(),
                  durationLabel: '',
                  durationSeconds: 0,
                  status: LessonStatus.current,
                  video: video,
                  words: const [],
                  games: const [],
                  questions: const [],
                  test: null,
                ),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1D4ED8),
                        Color(0xFF2E90FA),
                        Color(0xFF60A5FA),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF1D4ED8),
                      size: 42,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.06, duration: 1100.ms),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubLessonCard extends StatelessWidget {
  final CourseLesson lesson;
  final bool isCompleted;
  final String courseId;
  final int index;

  const _SubLessonCard({
    required this.lesson,
    required this.isCompleted,
    required this.courseId,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonPlayerPage(lesson: lesson),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF12B76A).withValues(alpha: 0.5)
                  : const Color(0xFFE4E7EC),
              width: isCompleted ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail / play badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF2E90FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.durationLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(height: 6),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF12B76A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCompleted) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF12B76A), size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FinalTestCard extends StatelessWidget {
  final CourseTestData test;
  final bool unlocked;

  const _FinalTestCard({required this.test, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Always tappable for now — the lock icon is advisory. Wire
        // back the `!unlocked` gate once we want a real progression
        // requirement (e.g. "complete every sub-lesson first").
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourseTestPage(testData: test),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unlocked
                  ? const Color(0xFF2E90FA).withValues(alpha: 0.4)
                  : const Color(0xFFE4E7EC),
              width: unlocked ? 1.5 : 1,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFF2E90FA).withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: unlocked
                      ? const Color(0xFF2E90FA).withValues(alpha: 0.12)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  color: unlocked
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF98A2B3),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'lesson_hub_take_test'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: unlocked
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF98A2B3),
                  ),
                ),
              ),
              Icon(
                unlocked ? Icons.arrow_forward_rounded : Icons.lock_rounded,
                color: unlocked
                    ? const Color(0xFF2E90FA)
                    : const Color(0xFF98A2B3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordsProgressCard extends StatelessWidget {
  final int learned;
  final int total;
  final CourseModule module;

  const _WordsProgressCard({
    required this.learned,
    required this.total,
    required this.module,
  });

  void _openLearnFlow(BuildContext context) {
    HapticFeedback.lightImpact();
    final preloaded = [
      for (final lesson in module.lessons)
        for (final w in lesson.words) w.toGameWord(),
    ];
    if (preloaded.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChoseLearnKnowPage(
          categoryId: -1,
          preloadedWords: preloaded,
          lessonTitle: module.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (learned / total).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: total == 0 ? null : () => _openLearnFlow(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'lesson_hub_learn_words'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    '$learned/$total',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF12B76A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF98A2B3),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE4E7EC),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF12B76A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
