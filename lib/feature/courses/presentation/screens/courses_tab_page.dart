import 'package:country_flags/country_flags.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:vozhaomuz/feature/courses/presentation/providers/course_fixture_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/providers/course_progress_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_detail_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Active segment of the Courses tab (0 = all courses, 1 = my
/// courses). Lifted out of widget state so callers from other pages
/// (e.g. the Continue CTA on the course-detail screen) can switch
/// the segment programmatically — `ref.read(coursesTabSegmentProvider
/// .notifier).state = 1` — and have the page rebuild on the right
/// segment when the user pops back to it.
final coursesTabSegmentProvider = StateProvider<int>((ref) => 0);

/// Bottom-bar tab for the Courses section. Until the backend ships,
/// this renders a single hand-built featured course card with mock
/// data so we can iterate on the visual design.
class CoursesTabPage extends ConsumerWidget {
  const CoursesTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(coursesTabSegmentProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
              child: _Header(),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _CoursesSegment(
                current: segment,
                onChanged: (i) =>
                    ref.read(coursesTabSegmentProvider.notifier).state = i,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // Default alignment is `Alignment.center`, which
                // visually pushes a single short card (My Courses
                // with one active enrollment) to the middle of the
                // tab area. Anchor children to the top instead so
                // content always starts right under the segment
                // switcher.
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    ?currentChild,
                  ],
                ),
                child: segment == 0
                    ? const _AllCoursesTab(key: ValueKey('all'))
                    : const _MyCoursesTab(key: ValueKey('my')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill-style two-button switcher between "All courses" and "My courses".
class _CoursesSegment extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _CoursesSegment({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'courses_segment_all'.tr(),
      'courses_segment_my'.tr(),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == current;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF667085),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Tab 1 — full catalogue (current featured course + coming-soon list).
class _AllCoursesTab extends StatelessWidget {
  const _AllCoursesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FeaturedCourseCard(
            courseId: 'english_a1',
            title: 'Английский с 0',
            author: 'Саади Тоирзода',
            authorRole: 'Преподаватель',
            totalDuration: '10 часов',
            lessonsCount: 32,
            studentsCount: 1240,
            level: 'A1 — Beginner',
            rating: 4.9,
          ),
          const SizedBox(height: 14),
          // Second course used to exercise the single-active-course
          // paywall gate. Real catalogue rendering will switch to
          // `allCoursesProvider` once we have more than two
          // hand-tuned cards.
          const _FeaturedCourseCard(
            courseId: 'english_a2',
            title: 'Английский A2',
            author: 'Саади Тоирзода',
            authorRole: 'Преподаватель',
            totalDuration: '4 часа',
            lessonsCount: 3,
            studentsCount: 320,
            level: 'A2 — Elementary',
            rating: 4.8,
          ),
          const SizedBox(height: 18),
          _SectionTitle(text: 'courses_more_title'.tr()),
          const SizedBox(height: 10),
          const _ComingSoonCard(),
        ],
      ),
    );
  }
}

/// Tab 2 — the course the user is currently enrolled in. Renders an
/// empty placeholder until the user crosses the 4-video threshold in
/// any course (the enrollment trigger fires from
/// [LessonPlayerPage.initState]).
class _MyCoursesTab extends ConsumerWidget {
  const _MyCoursesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIdAsync = ref.watch(activeCourseIdProvider);
    return activeIdAsync.when(
      // While SharedPreferences resolves we show nothing rather than
      // a flashing empty state — the lookup is sub-frame in practice.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const _MyCoursesEmpty(),
      data: (activeId) {
        if (activeId == null) return const _MyCoursesEmpty();
        return _ActiveCourseSection(courseId: activeId);
      },
    );
  }
}

class _MyCoursesEmpty extends StatelessWidget {
  const _MyCoursesEmpty();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF60A5FA).withValues(alpha: 0.18),
                  const Color(0xFF1D4ED8).withValues(alpha: 0.10),
                ],
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Color(0xFF1D4ED8),
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'courses_my_empty_title'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'courses_my_empty_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF667085),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card for the user's currently-enrolled course: title + progress
/// bar + tap-to-resume. Reads completion data from the existing
/// progress provider so the percentage stays in sync with the
/// course-detail screen.
class _ActiveCourseSection extends ConsumerWidget {
  final String courseId;
  const _ActiveCourseSection({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseByIdProvider(courseId));
    final completedAsync = ref.watch(courseProgressProvider(courseId));

    return courseAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _MyCoursesEmpty(),
      data: (course) {
        final completed = completedAsync.asData?.value ?? const <String>{};
        final total = course.totalLessons;
        final pct = total == 0 ? 0.0 : completed.length / total;
        final isFinished = completed.length >= total && total > 0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CourseDetailPage(courseId: courseId),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E90FA)
                              .withValues(alpha: 0.16),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFinished
                                    ? const Color(0xFF12B76A)
                                    : const Color(0xFF1D4ED8),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Enrolled / completed checkmark — visual
                                  // confirmation that the course "lives" in
                                  // this list now and isn't a preview.
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isFinished
                                        ? 'courses_my_finished_badge'.tr()
                                        : 'courses_my_active_badge'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(pct * 100).round()}%',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          course.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${course.instructor.name} • '
                          '${course.instructor.role}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE0EAFF),
                            valueColor: AlwaysStoppedAnimation(
                              isFinished
                                  ? const Color(0xFF12B76A)
                                  : const Color(0xFF2E90FA),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${completed.length} / $total '
                          '${'courses_lessons_word'.tr()}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'courses_tab_title'.tr(),
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'courses_tab_subtitle'.tr(),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
      ],
    );
  }
}

class _FeaturedCourseCard extends ConsumerWidget {
  /// ID of the course this card represents — passed straight to the
  /// "Start course" button so the paywall gate knows which course the
  /// user is trying to start.
  final String courseId;
  final String title;
  final String author;
  final String authorRole;
  final String totalDuration;
  final int lessonsCount;
  final int studentsCount;
  final String level;
  final double rating;

  const _FeaturedCourseCard({
    required this.courseId,
    required this.title,
    required this.author,
    required this.authorRole,
    required this.totalDuration,
    required this.lessonsCount,
    required this.studentsCount,
    required this.level,
    required this.rating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show a check badge on the card when this course is the user's
    // currently-enrolled one. Helps them spot it on the catalogue.
    final activeId = ref.watch(activeCourseIdProvider).asData?.value;
    final isEnrolled = activeId == courseId;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E90FA).withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CourseIcon(level: level, rating: rating),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (isEnrolled) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF12B76A),
                              size: 22,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      _AuthorRow(name: author, role: authorRole),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatChip(
                            icon: Icons.menu_book_rounded,
                            label: '$lessonsCount '
                                '${'courses_lessons_word'.tr()}',
                            color: const Color(0xFF12B76A),
                          ),
                          _StatChip(
                            icon: Icons.people_alt_rounded,
                            label: _formatStudents(studentsCount),
                            color: const Color(0xFF7A5AF8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _StartButton(courseId: courseId),
        ],
      ),
    );
  }

  static String _formatStudents(int count) {
    if (count >= 1000) {
      final k = (count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1);
      return '$k ${'courses_students_word'.tr()}';
    }
    return '$count ${'courses_students_word'.tr()}';
  }
}

/// Compact left-side icon panel: gradient background with a play badge,
/// the course level pill at the top, and the rating chip at the bottom.
/// Sits next to the textual info on the right.
class _CourseIcon extends StatelessWidget {
  final String level;
  final double rating;
  const _CourseIcon({required this.level, required this.rating});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 110,
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
            const Positioned(
              top: -25,
              right: -20,
              child: _Orb(size: 90, color: Color(0x44FFFFFF)),
            ),
            const Positioned(
              bottom: -25,
              left: -15,
              child: _Orb(size: 90, color: Color(0x33FFE08A)),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: 64,
                        height: 48,
                        child: CountryFlag.fromCountryCode('gb'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  level,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D4ED8),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFDB022), size: 12),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final String name;
  final String role;
  const _AuthorRow({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        Text(
          role,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF667085),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends ConsumerWidget {
  /// Course this button starts. The paywall gate uses this ID to
  /// decide whether the user can open it for free or has to pay.
  final String courseId;
  const _StartButton({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If this is the user's currently active course, swap the CTA
    // copy from "Start course" to "Continue course" — they already
    // joined it, so "Start" reads as a regression.
    final activeId = ref.watch(activeCourseIdProvider).asData?.value;
    final isEnrolled = activeId == courseId;
    return MyButton(
      width: double.infinity,
      depth: 4,
      borderRadius: 14,
      buttonColor: const Color(0xFF2E90FA),
      backButtonColor: const Color(0xFF1570EF),
      padding: const EdgeInsets.symmetric(vertical: 12),
      onPressed: () async {
        HapticFeedback.lightImpact();
        // Resolve the gate synchronously off the cached future so the
        // tap feels instant. If the gate denies start, surface the
        // paywall dialog instead of opening the course.
        final canStart = await ref.read(
          canStartCourseProvider(courseId).future,
        );
        if (!context.mounted) return;
        if (!canStart) {
          await _showIncompleteCourseDialog(context, ref);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailPage(courseId: courseId),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isEnrolled
                ? 'course_continue_button'.tr()
                : 'courses_start_button'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 18),
        ],
      ),
    );
  }
}

/// Mock paywall shown when the user has an incomplete enrolled course
/// and tries to start a different one. Replace the "Pay" button's
/// onTap with the real billing flow once it lands.
Future<void> _showIncompleteCourseDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final activeId = await ref.read(activeCourseIdProvider.future);
  if (activeId == null || !context.mounted) return;
  final activeCourse =
      await ref.read(courseByIdProvider(activeId).future);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFEF3C7),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFFE48B0B),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'courses_lock_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'courses_lock_subtitle'.tr(
                args: [activeCourse.title, activeCourse.title],
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).maybePop(),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: const Color(0xFF475569),
                    ),
                    child: Text(
                      'courses_lock_cancel'.tr(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MyButton(
                    depth: 3,
                    borderRadius: 12,
                    buttonColor: const Color(0xFFFDB022),
                    backButtonColor: const Color(0xFFE48B0B),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      // Real billing flow not wired yet — for now we
                      // just close the dialog. When payments land,
                      // kick into the purchase sheet here and only
                      // call `enrollInCourse(targetCourseId)` after
                      // a successful charge.
                      Navigator.of(ctx).maybePop();
                    },
                    child: Center(
                      child: Text(
                        'courses_lock_pay'.tr(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1D2939),
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: Color(0xFF667085),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'courses_coming_soon_title'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'courses_coming_soon_subtitle'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
