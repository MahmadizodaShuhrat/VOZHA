import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// "Are you sure you want to enroll?" prompt shown when the user taps
/// the Continue CTA on the course-detail page. Returns `true` when
/// the user confirms enrollment, `false` (or null on dismiss) when
/// they back out.
Future<bool> showEnrollmentConfirmDialog(
  BuildContext context, {
  required String courseTitle,
}) async {
  HapticFeedback.lightImpact();
  final result = await showDialog<bool>(
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
                color: Color(0xFFEFF6FF),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Color(0xFF1D4ED8),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'enrollment_confirm_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'enrollment_confirm_subtitle'.tr(args: [courseTitle]),
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
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: const Color(0xFF475569),
                    ),
                    child: Text(
                      'enrollment_confirm_no'.tr(),
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
                    buttonColor: const Color(0xFF2E90FA),
                    backButtonColor: const Color(0xFF1570EF),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(ctx).pop(true);
                    },
                    child: Center(
                      child: Text(
                        'enrollment_confirm_yes'.tr(),
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
  return result ?? false;
}
