import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Celebration popup shown when the user opens the 4th video in a
/// course — the moment they implicitly "subscribe" and the course
/// joins their "My courses" list.
///
/// Pure UI; the caller is responsible for actually persisting the
/// enrollment (via `enrollInCourse`) once this returns.
Future<void> showEnrollmentCelebrationDialog(
  BuildContext context, {
  required String courseTitle,
}) async {
  HapticFeedback.mediumImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (_, _, _) =>
        _EnrollmentCelebrationDialog(courseTitle: courseTitle),
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class _EnrollmentCelebrationDialog extends StatelessWidget {
  final String courseTitle;
  const _EnrollmentCelebrationDialog({required this.courseTitle});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFDB022), Color(0xFFE48B0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE48B0B).withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 46,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.08, duration: 1200.ms),
            const SizedBox(height: 18),
            Text(
              'enrollment_celebration_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'enrollment_celebration_subtitle'.tr(
                args: [courseTitle],
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            MyButton(
              width: double.infinity,
              depth: 4,
              borderRadius: 14,
              buttonColor: const Color(0xFF2E90FA),
              backButtonColor: const Color(0xFF1570EF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).maybePop();
              },
              child: Center(
                child: Text(
                  'enrollment_celebration_continue'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
