import 'package:country_flags/country_flags.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';
import 'package:vozhaomuz/feature/courses/presentation/providers/course_fixture_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/providers/course_progress_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/certificate_pdf.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/courses_tab_page.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/lesson_hub_page.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/lesson_player_page.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/enrollment_confirm_dialog.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Course-detail screen with three tabs (Content / Info / Reviews).
///
/// Course content is loaded from `assets/courses/<id>/course.json` via
/// [courseByIdProvider] — this is a provisional asset-backed
/// "backend" until the real API ships. Reviews are still hard-coded
/// further down because the review feature has no backend yet.
class CourseDetailPage extends ConsumerStatefulWidget {
  final String courseId;

  const CourseDetailPage({super.key, this.courseId = 'english_a1'});

  @override
  ConsumerState<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends ConsumerState<CourseDetailPage> {
  int _tab = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setTab(int i) {
    setState(() => _tab = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncCourse = ref.watch(courseByIdProvider(widget.courseId));
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: asyncCourse.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить курс:\n$e',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF475569)),
            ),
          ),
        ),
        data: _buildLoaded,
      ),
    );
  }

  Widget _buildLoaded(CourseFixture course) {
    // Overlay the user's persisted completion set on top of the
    // fixture-provided statuses. The first non-completed lesson
    // becomes "current"; everything after it is "locked".
    final completedIds =
        ref.watch(courseProgressProvider(widget.courseId)).asData?.value ??
            const <String>{};
    final modules = applyProgress(course.modules, completedIds);
    final completed = completedIds.length;
    final total = course.totalLessons;

    // Once the user has watched the course intro video to the end,
    // we collapse the hero + heading + "Continue" CTA. The intro is
    // pure orientation material — re-showing it on every visit just
    // pushes the lesson list off-screen for someone who's already
    // ready to study.
    final introWatched =
        ref.watch(courseIntroWatchedProvider(widget.courseId)).asData?.value ??
            false;
    // No previewUrl in the JSON → nothing to play, so treat as "no
    // intro to show" and collapse straight away.
    final hasIntro = (course.previewUrl ?? '').isNotEmpty;
    final showIntroBlock = hasIntro && !introWatched;

    return Column(
      children: [
        SafeArea(bottom: false, child: _TopBar()),
        // Pinned hero + heading + tab bar — these stay at the top
        // while the user swipes between tabs below.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showIntroBlock) ...[
                _HeroVideo(
                  level: course.level,
                  courseId: widget.courseId,
                  previewUrl: course.previewUrl,
                ),
                const SizedBox(height: 14),
                _CourseHeading(
                  title: course.title,
                  instructor: course.instructor,
                ),
                const SizedBox(height: 14),
              ],
              _DetailTabBar(current: _tab, onChanged: _setTab),
            ],
          ),
        ),
        // Swipeable tab pages — each scrolls vertically on its own.
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _tab = i),
            children: [
              _TabPage(
                child: _ContentTab(
                  modules: modules,
                  completed: completed,
                  total: total,
                  courseId: widget.courseId,
                  unlockedModules:
                      unlockedModuleIndices(modules, completedIds),
                ),
              ),
              _TabPage(child: _InfoTab(course: course)),
              const _TabPage(child: _ReviewsTab()),
            ],
          ),
        ),
        if (showIntroBlock)
          _ContinueBar(
            currentLesson: _currentLessonOrNull(modules),
            courseId: widget.courseId,
          ),
      ],
    );
  }

  static CourseLesson? _currentLessonOrNull(List<CourseModule> modules) {
    for (final m in modules) {
      for (final l in m.lessons) {
        if (l.status == LessonStatus.current) return l;
      }
    }
    return null;
  }
}

// ─────────────────────────── tab page wrapper ───────────────────────────

/// Wraps each PageView page with the same vertical scroll + padding so
/// the tabs feel uniform when swiped between.
class _TabPage extends StatelessWidget {
  final Widget child;
  const _TabPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: child,
    );
  }
}

// ─────────────────────────── tab bar ───────────────────────────

class _DetailTabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _DetailTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'course_tab_content'.tr(),
      'course_tab_info'.tr(),
      'course_tab_reviews'.tr(),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE4E7EC), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == current;
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onChanged(i);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      labels[i],
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF98A2B3),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        bottom: -12,
                        child: Container(
                          width: 50,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────── content tab ───────────────────────────

class _ContentTab extends StatelessWidget {
  final List<CourseModule> modules;
  final int completed;
  final int total;
  final String courseId;

  /// Indices of modules the user is allowed to open. Computed by the
  /// parent off the same `completedIds` set it already has, so we
  /// don't subscribe to `courseProgressProvider` a second time and
  /// rebuild this whole tab independently.
  final Set<int> unlockedModules;

  const _ContentTab({
    required this.modules,
    required this.completed,
    required this.total,
    required this.courseId,
    required this.unlockedModules,
  });

  @override
  Widget build(BuildContext context) {
    final isCourseFinished = completed == total && total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressCard(completed: completed, total: total),
        const SizedBox(height: 18),
        for (int i = 0; i < modules.length; i++) ...[
          _ModuleHubCard(
            index: i + 1,
            module: modules[i],
            courseId: courseId,
            isLocked: !unlockedModules.contains(i),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        _InfoLabel(text: 'course_certificate_section'.tr()),
        const SizedBox(height: 10),
        _CertificateRow(unlocked: isCourseFinished),
      ],
    );
  }
}

// ─────────────────────────── certificate row ───────────────────────────

class _CertificateRow extends StatelessWidget {
  final bool unlocked;
  const _CertificateRow({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          showCertificatePreview(context, unlocked: unlocked);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unlocked
                  ? const Color(0xFFFDB022).withValues(alpha: 0.5)
                  : const Color(0xFFE4E7EC),
              width: unlocked ? 1.5 : 1,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: const Color(0xFFFDB022).withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: unlocked
                        ? const [Color(0xFFFDB022), Color(0xFFE48B0B)]
                        : const [Color(0xFFFCA5A5), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
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
                      'course_certificate_title'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unlocked
                          ? 'course_certificate_unlocked'.tr()
                          : 'course_certificate_locked'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: unlocked
                            ? const Color(0xFFB45309)
                            : const Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                unlocked ? Icons.visibility_rounded : Icons.lock_rounded,
                color: unlocked
                    ? const Color(0xFFB45309)
                    : const Color(0xFF98A2B3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── certificate preview ───────────────────────────

/// Show the certificate as a centered dialog. Locked variant has a
/// subtle blur + lock badge so the user can still see what they're
/// working towards.
Future<void> showCertificatePreview(
  BuildContext context, {
  required bool unlocked,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => _CertificatePreview(unlocked: unlocked),
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class _CertificatePreview extends StatelessWidget {
  final bool unlocked;
  const _CertificatePreview({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: _CertificateCard(unlocked: unlocked),
          ),
          const SizedBox(height: 14),
          if (unlocked)
            _CertificateActionButton(
              icon: Icons.download_rounded,
              label: 'course_certificate_download'.tr(),
              onPressed: () async {
                HapticFeedback.lightImpact();
                await shareCertificatePdf(
                  studentName: 'Vozhaomuz Student',
                  courseTitle: 'Английский с 0 (A1)',
                  instructor: 'Саади Тоирзода',
                  date: '10.03.2024',
                );
              },
            )
          else
            _CertificateActionButton(
              icon: Icons.flag_rounded,
              label: 'course_certificate_continue_to_unlock'.tr(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final bool unlocked;
  const _CertificateCard({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDB022).withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFDB022).withValues(alpha: 0.6),
          width: 2.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _CornerOrnament(),
              const _SealBadge(),
              const _CornerOrnament(flipped: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'certificate_heading'.tr().toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              letterSpacing: 4,
              color: const Color(0xFFB45309),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'certificate_of_completion'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2939),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 2,
            width: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFDB022), Color(0xFFE48B0B)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'certificate_awarded_to'.tr(),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF667085),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vozhaomuz Student',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'certificate_for_course'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF667085),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Английский с 0 (A1)',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2939),
            ),
          ),
          const Spacer(),
          // Footer: signature + date.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Саади Тоирзода',
                      style: GoogleFonts.dancingScript(
                        fontSize: 18,
                        color: const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      height: 1,
                      color: const Color(0xFFD0D5DD),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                    ),
                    Text(
                      'certificate_instructor_role'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '10.03.2024',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    Container(
                      height: 1,
                      color: const Color(0xFFD0D5DD),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                    ),
                    Text(
                      'certificate_date'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: const Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (unlocked) return card;
    // Locked: keep the preview readable but show a lock overlay.
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: 0.55, child: card),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'course_certificate_locked'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerOrnament extends StatelessWidget {
  final bool flipped;
  const _CornerOrnament({this.flipped = false});

  @override
  Widget build(BuildContext context) {
    final orn = SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(painter: _CornerPainter()),
    );
    if (flipped) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.14159),
        child: orn,
      );
    }
    return orn;
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFDB022)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(
          size.width * 0.5, 0, size.width, size.height * 0.6);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SealBadge extends StatelessWidget {
  const _SealBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFDB022), Color(0xFFE48B0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE48B0B).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.workspace_premium_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.08, duration: 1300.ms);
  }
}

class _CertificateActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CertificateActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MyButton(
      depth: 4,
      borderRadius: 14,
      buttonColor: const Color(0xFFFDB022),
      backButtonColor: const Color(0xFFE48B0B),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── info tab ───────────────────────────

class _InfoTab extends StatelessWidget {
  final CourseFixture course;
  const _InfoTab({required this.course});

  @override
  Widget build(BuildContext context) {
    final timeLabel = '${course.totalMinutes ~/ 60} часов';
    final studentsLabel = course.students >= 1000
        ? '${(course.students / 1000).toStringAsFixed(1)}k'
        : '${course.students}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLabel(text: 'course_info_name'.tr()),
        const SizedBox(height: 6),
        Text(
          course.title,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF1D2939),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFE4E7EC)),
        const SizedBox(height: 18),
        _InfoLabel(text: 'course_info_description'.tr()),
        const SizedBox(height: 8),
        Text(
          course.description,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            height: 1.55,
            color: const Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 22),
        _InfoLabel(text: 'course_info_details'.tr()),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoStat(
                icon: Icons.person_rounded,
                label: 'course_info_students'.tr(),
                value: studentsLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoStat(
                icon: Icons.calendar_today_rounded,
                label: 'course_info_publish_date'.tr(),
                value: course.publishedAt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoStat(
                icon: Icons.access_time_rounded,
                label: 'course_info_time'.tr(),
                value: timeLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoStat(
                icon: Icons.groups_rounded,
                label: 'course_info_seats'.tr(),
                value: '100',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoLabel extends StatelessWidget {
  final String text;
  const _InfoLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

class _InfoStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1D4ED8), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF667085),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── reviews tab ───────────────────────────

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab();

  @override
  Widget build(BuildContext context) {
    final reviews = _mockReviews;
    final avg = reviews.map((r) => r.stars).reduce((a, b) => a + b) /
        reviews.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          avg.toStringAsFixed(2),
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        _StarRow(stars: avg, size: 20),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${reviews.length} ${'course_reviews_word'.tr()}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFE4E7EC)),
        const SizedBox(height: 14),
        for (int i = 0; i < reviews.length; i++) ...[
          _ReviewCard(review: reviews[i]),
          if (i < reviews.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  final double stars;
  final double size;
  const _StarRow({required this.stars, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = stars >= i + 1;
        final half = !filled && stars > i;
        return Icon(
          half
              ? Icons.star_half_rounded
              : (filled ? Icons.star_rounded : Icons.star_outline_rounded),
          color: const Color(0xFFFDB022),
          size: size,
        );
      }),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: review.avatarGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    review.author.characters.first.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _StarRow(stars: review.stars.toDouble(), size: 13),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF344054),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review.date,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF98A2B3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── top bar ───────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            child: Text(
              'course_detail_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            onPressed: () => HapticFeedback.lightImpact(),
            icon: const Icon(Icons.bookmark_border_rounded,
                color: Color(0xFF1D2939), size: 22),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── hero video ───────────────────────────

class _HeroVideo extends ConsumerWidget {
  final String level;
  final String courseId;
  final String? previewUrl;

  const _HeroVideo({
    required this.level,
    required this.courseId,
    required this.previewUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = previewUrl;
    final hero = ClipRRect(
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
            const Positioned(
              top: -40,
              right: -30,
              child: _Orb(size: 160, color: Color(0x44FFFFFF)),
            ),
            const Positioned(
              bottom: -50,
              left: -30,
              child: _Orb(size: 180, color: Color(0x33FFE08A)),
            ),
            // Glassy play badge.
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 44,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 32,
                          height: 22,
                          child: CountryFlag.fromCountryCode('gb'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      level,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (url == null || url.isEmpty) return hero;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonPlayerPage(
              // Synthetic intro lesson — `courseId` is null on purpose
              // so the auto-enrollment trigger doesn't count this watch
              // (intro is meta-content about the course, not a lesson).
              lesson: CourseLesson(
                id: 'course_${courseId}_intro',
                type: LessonType.video,
                title: '',
                durationLabel: '',
                durationSeconds: 0,
                status: LessonStatus.current,
                video: LessonVideo(url: url),
                words: const [],
                games: const [],
                questions: const [],
                test: null,
              ),
              // Pressing the bottom CTA implies the user got through
              // the intro. Mark watched so the next visit collapses
              // the hero block straight to the lesson list.
              onCompleted: () async {
                await markCourseIntroWatched(ref, courseId);
                if (!context.mounted) return;
                Navigator.of(context).maybePop();
              },
            ),
          ),
        );
      },
      child: hero,
    );
  }
}

// ─────────────────────────── heading ───────────────────────────

class _CourseHeading extends StatelessWidget {
  final String title;
  final CourseInstructor instructor;

  const _CourseHeading({required this.title, required this.instructor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${instructor.name} • ${instructor.role}',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF667085),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── progress card ───────────────────────────

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressCard({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E90FA).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular progress.
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
                    value: pct,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFFE0EAFF),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2E90FA)),
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'course_progress_title'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed / $total ${'courses_lessons_word'.tr()}',
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

// ─────────────────────────── module hub card ───────────────────────────

/// Compact card representation of a module ("Урок"). Replaces the
/// older expandable roadmap row — tap navigates to [LessonHubPage]
/// where the user gets the main video, sub-lessons, and final test.
///
/// [isLocked] cascades from the previous module's completion state:
/// the first module is always tappable; later modules stay disabled
/// (lock icon, no navigation) until the prior one is fully done.
class _ModuleHubCard extends StatelessWidget {
  final int index;
  final CourseModule module;
  final String courseId;
  final bool isLocked;

  const _ModuleHubCard({
    required this.index,
    required this.module,
    required this.courseId,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final completedLessons = module.lessons
        .where((l) => l.status == LessonStatus.completed)
        .length;
    final total = module.lessons.length;
    final pct = total == 0 ? 0.0 : completedLessons / total;
    final isFinished =
        !isLocked && completedLessons == total && total > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLocked
            ? null
            : () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LessonHubPage(
                      courseId: courseId,
                      module: module,
                      moduleIndex: index - 1,
                    ),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLocked
                ? const Color(0xFFF2F4F7)
                : isFinished
                    ? const Color(0xFFECFDF3)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLocked
                  ? const Color(0xFFE4E7EC)
                  : isFinished
                      ? const Color(0xFF12B76A).withValues(alpha: 0.4)
                      : const Color(0xFFE4E7EC),
              width: isFinished ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLocked
                      ? const Color(0xFF98A2B3)
                      : isFinished
                          ? const Color(0xFF12B76A)
                          : const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${'course_module_label'.tr()} $index',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isLocked
                            ? const Color(0xFF98A2B3)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    if (!isLocked) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFE4E7EC),
                                valueColor: AlwaysStoppedAnimation(
                                  isFinished
                                      ? const Color(0xFF12B76A)
                                      : const Color(0xFF2E90FA),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$completedLessons/$total',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLocked
                    ? Icons.lock_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: isLocked ? 18 : 16,
                color: isLocked
                    ? const Color(0xFF98A2B3)
                    : isFinished
                        ? const Color(0xFF12B76A)
                        : const Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── module section ───────────────────────────

/// Collapsible group: a header that, when tapped, expands or collapses
/// the rail of lessons below it. Defaults to expanded for the module
/// containing the user's current lesson.
class CourseModuleSection extends StatefulWidget {
  final int index;
  final CourseModule module;
  final bool isLastModule;
  final bool initiallyExpanded;
  final String courseId;

  const CourseModuleSection({
    super.key,
    required this.index,
    required this.module,
    required this.isLastModule,
    required this.initiallyExpanded,
    required this.courseId,
  });

  @override
  State<CourseModuleSection> createState() => CourseModuleSectionState();
}

class CourseModuleSectionState extends State<CourseModuleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = widget.module.lessons
        .where((l) => l.status == LessonStatus.completed)
        .length;
    final totalCount = widget.module.lessons.length;
    final isCompleted = completedCount == totalCount && totalCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFECFDF3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF12B76A).withValues(alpha: 0.4)
              : const Color(0xFFE4E7EC),
          width: isCompleted ? 1.5 : 1,
        ),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: const Color(0xFF12B76A).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header — tap to expand/collapse.
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF12B76A)
                            : const Color(0xFF1D4ED8),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCompleted) ...[
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            '${'course_module_label'.tr()} ${widget.index}',
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.module.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$completedCount / $totalCount '
                            '${'courses_lessons_word'.tr()}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF667085),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Body — animated expand/collapse.
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 12, 12),
                    child: Column(
                      children: [
                        for (int i = 0;
                            i < widget.module.lessons.length;
                            i++)
                          _RoadmapRow(
                            lesson: widget.module.lessons[i],
                            isFirst: i == 0,
                            isLast: i == widget.module.lessons.length - 1,
                            stopAfter: false,
                            indexInModule: i,
                            courseId: widget.courseId,
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _RoadmapRow extends StatelessWidget {
  final CourseLesson lesson;
  final bool isFirst;
  final bool isLast;
  final bool stopAfter;
  final int indexInModule;
  final String courseId;

  const _RoadmapRow({
    required this.lesson,
    required this.isFirst,
    required this.isLast,
    required this.stopAfter,
    required this.indexInModule,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(lesson.status);
    final lineAbove = lesson.status == LessonStatus.locked
        ? const Color(0xFFD0D5DD)
        : const Color(0xFF12B76A);
    final lineBelow = lesson.status == LessonStatus.completed
        ? const Color(0xFF12B76A)
        : const Color(0xFFD0D5DD);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Rail column.
        SizedBox(
          width: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top half of the line (skipped on the very first lesson).
              SizedBox(
                width: 3,
                height: 12,
                child: isFirst
                    ? const SizedBox.shrink()
                    : DecoratedBox(decoration: BoxDecoration(color: lineAbove)),
              ),
              _RailNode(status: lesson.status, color: color),
              // Bottom half (skipped on the last lesson of the last module).
              SizedBox(
                width: 3,
                height: 12,
                child: (isLast)
                    ? const SizedBox.shrink()
                    : DecoratedBox(decoration: BoxDecoration(color: lineBelow)),
              ),
            ],
          ),
        ),
        // Card column.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _LessonCard(
              lesson: lesson,
              statusColor: color,
              courseId: courseId,
            ),
          ),
        ),
      ],
    );
  }
}

class _RailNode extends StatelessWidget {
  final LessonStatus status;
  final Color color;

  const _RailNode({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status == LessonStatus.locked ? const Color(0xFFE4E7EC) : color,
        boxShadow: status == LessonStatus.locked
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Icon(
        _statusIcon(status),
        color: status == LessonStatus.locked
            ? const Color(0xFF98A2B3)
            : Colors.white,
        size: 16,
      ),
    );

    if (status == LessonStatus.current) {
      // Pulsing ring around the active node.
      return SizedBox(
        width: 50,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.85, end: 1.1, duration: 1100.ms),
            inner,
          ],
        ),
      );
    }
    return SizedBox(width: 50, height: 50, child: Center(child: inner));
  }
}

class _LessonCard extends ConsumerWidget {
  final CourseLesson lesson;
  final Color statusColor;
  final String courseId;

  const _LessonCard({
    required this.lesson,
    required this.statusColor,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = lesson.status == LessonStatus.locked;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          HapticFeedback.lightImpact();
          if (isLocked) return;
          if (lesson.video != null) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LessonPlayerPage(
                  lesson: lesson,
                  courseId: courseId,
                ),
              ),
            );
            // When the user returns from the player (or the games
            // flow it kicks off), mark this lesson as completed.
            // Idempotent — safe even if already completed.
            await markLessonCompleted(ref, courseId, lesson.id);
          }
          // Words/quiz/pronunciation flows without video will be
          // wired in a follow-up step.
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: lesson.status == LessonStatus.current
                  ? statusColor.withValues(alpha: 0.6)
                  : const Color(0xFFE4E7EC),
              width: lesson.status == LessonStatus.current ? 1.5 : 1,
            ),
            boxShadow: lesson.status == LessonStatus.current
                ? [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.25),
                      blurRadius: 16,
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
                  color: _typeColor(lesson.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _typeIcon(lesson.type),
                  color: _typeColor(lesson.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isLocked
                            ? const Color(0xFF98A2B3)
                            : const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12,
                            color: isLocked
                                ? const Color(0xFFB6B6B6)
                                : const Color(0xFF667085)),
                        const SizedBox(width: 4),
                        Text(
                          lesson.durationLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isLocked
                                ? const Color(0xFFB6B6B6)
                                : const Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                _typeColor(lesson.type).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _typeLabel(lesson.type),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: _typeColor(lesson.type),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (lesson.status == LessonStatus.current)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 18),
                )
              else if (isLocked)
                const Icon(Icons.lock_rounded,
                    color: Color(0xFF98A2B3), size: 18)
              else
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF12B76A), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── continue bar ───────────────────────────

class _ContinueBar extends ConsumerWidget {
  final CourseLesson? currentLesson;
  final String courseId;
  const _ContinueBar({required this.currentLesson, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: MyButton(
          width: double.infinity,
          depth: 4,
          borderRadius: 14,
          buttonColor: const Color(0xFF2E90FA),
          backButtonColor: const Color(0xFF1570EF),
          padding: const EdgeInsets.symmetric(vertical: 12),
          onPressed: () async {
            HapticFeedback.lightImpact();
            // Confirmation step before we commit the enrollment —
            // the user might have hit "Continue" by accident or just
            // wanted to scroll past the hero. If they back out, we
            // do nothing (intro stays visible, no enrollment, no
            // navigation).
            final course =
                await ref.read(courseByIdProvider(courseId).future);
            if (!context.mounted) return;
            final confirmed = await showEnrollmentConfirmDialog(
              context,
              courseTitle: course.title,
            );
            if (!confirmed) return;
            if (!context.mounted) return;
            // Confirmed → collapse the intro on next visit, enroll the
            // user (no-op if they're already enrolled in a different
            // course — the paywall gate handles switching), flip the
            // courses tab to "My courses", and pop back so the user
            // lands directly on their new course card.
            await markCourseIntroWatched(ref, courseId);
            final activeId =
                await ref.read(activeCourseIdProvider.future);
            if (activeId == null) {
              await enrollInCourse(ref, courseId);
            }
            ref.read(coursesTabSegmentProvider.notifier).state = 1;
            if (!context.mounted) return;
            Navigator.of(context).maybePop();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text(
                currentLesson == null
                    ? 'course_start_button'.tr()
                    : 'course_continue_button'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── helpers ───────────────────────────

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

Color _statusColor(LessonStatus s) {
  switch (s) {
    case LessonStatus.completed:
      return const Color(0xFF12B76A);
    case LessonStatus.current:
      return const Color(0xFFF79009);
    case LessonStatus.locked:
      return const Color(0xFF98A2B3);
  }
}

IconData _statusIcon(LessonStatus s) {
  switch (s) {
    case LessonStatus.completed:
      return Icons.check_rounded;
    case LessonStatus.current:
      return Icons.play_arrow_rounded;
    case LessonStatus.locked:
      return Icons.lock_rounded;
  }
}

Color _typeColor(LessonType t) {
  switch (t) {
    case LessonType.video:
    case LessonType.videoWithWords:
      return const Color(0xFF2E90FA);
    case LessonType.quiz:
      return const Color(0xFFF79009);
    case LessonType.words:
      return const Color(0xFF12B76A);
    case LessonType.pronunciation:
      return const Color(0xFF7A5AF8);
  }
}

IconData _typeIcon(LessonType t) {
  switch (t) {
    case LessonType.video:
      return Icons.play_circle_filled_rounded;
    case LessonType.videoWithWords:
      return Icons.video_library_rounded;
    case LessonType.quiz:
      return Icons.quiz_rounded;
    case LessonType.words:
      return Icons.menu_book_rounded;
    case LessonType.pronunciation:
      return Icons.record_voice_over_rounded;
  }
}

String _typeLabel(LessonType t) {
  switch (t) {
    case LessonType.video:
    case LessonType.videoWithWords:
      return 'lesson_type_video'.tr().toUpperCase();
    case LessonType.quiz:
      return 'lesson_type_quiz'.tr().toUpperCase();
    case LessonType.words:
      return 'lesson_type_words'.tr().toUpperCase();
    case LessonType.pronunciation:
      return 'lesson_type_pron'.tr().toUpperCase();
  }
}

// ─────────────────────────── reviews mock ───────────────────────────
//
// Modules / lessons / description are now loaded from
// `assets/courses/<id>/course.json` via the fixture provider.
// Reviews stay hard-coded here because the review feature has no
// backend yet — wire it up the same way (asset → repository →
// provider) once review data is available.

class _Review {
  final String author;
  final int stars;
  final String text;
  final String date;
  final List<Color> avatarGradient;

  const _Review({
    required this.author,
    required this.stars,
    required this.text,
    required this.date,
    required this.avatarGradient,
  });
}

const _mockReviews = <_Review>[
  _Review(
    author: 'Сабрина А.',
    stars: 5,
    text: 'Курс просто супер! Всё объясняется понятным языком, никаких '
        'сложных терминов. Начала с нуля и уже могу строить простые '
        'предложения.',
    date: '10 марта 2024',
    avatarGradient: [Color(0xFFFDA4AF), Color(0xFFE11D48)],
  ),
  _Review(
    author: 'Игорь Т.',
    stars: 5,
    text: 'Давно хотел начать учить английский, но всё откладывал. Этот '
        'курс — отличная отправная точка. Особенно понравились тесты '
        'после тем, помогают закрепить материал.',
    date: '10 марта 2024',
    avatarGradient: [Color(0xFF93C5FD), Color(0xFF1D4ED8)],
  ),
];

