import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Lightweight "this step is locked" popup shown when the user taps a
/// step in a lesson hub that prerequisite gating doesn't let them
/// access yet (sub-lesson tapped before main video, final test
/// tapped before sub-lessons, ...).
///
/// Pure UI; the caller passes the title + body text so we can reuse
/// this dialog for every gating reason without piling enum branches
/// inside the widget itself.
Future<void> showLockedStepDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  HapticFeedback.lightImpact();
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
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFEF3C7),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFFE48B0B),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            MyButton(
              width: double.infinity,
              depth: 3,
              borderRadius: 12,
              buttonColor: const Color(0xFF2E90FA),
              backButtonColor: const Color(0xFF1570EF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () => Navigator.of(ctx).maybePop(),
              child: Center(
                child: Text(
                  'locked_step_ok'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
