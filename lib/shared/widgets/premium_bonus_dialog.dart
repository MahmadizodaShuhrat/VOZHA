import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/rating/data/models/premium_bonus_dto.dart';

/// "+1 day premium" celebration shown when the activity / sync
/// endpoints return a `premium_bonus.granted: true` block.
///
/// One modal per grant — the backend's UNIQUE constraint on
/// `(user_id, streak_run_id, milestone_streak)` guarantees the same
/// bonus can't ship twice in the same response, so callers don't need
/// to dedupe locally. After the modal closes the caller MUST refresh
/// the user profile so `userType`/`tariff_expired_at` reflect the
/// new bonus.
Future<void> showPremiumBonusDialog(
  BuildContext context, {
  required PremiumBonusDto bonus,
}) async {
  HapticFeedback.mediumImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => _PremiumBonusDialog(bonus: bonus),
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

class _PremiumBonusDialog extends StatelessWidget {
  final PremiumBonusDto bonus;
  const _PremiumBonusDialog({required this.bonus});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF7ED), Colors.white],
              stops: [0.0, 0.45],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFDB022).withValues(alpha: 0.3),
                blurRadius: 50,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CrownBadge(),
                const SizedBox(height: 14),
                Text(
                  'streak_premium_modal_title'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D2939),
                    letterSpacing: -0.3,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 240.ms, duration: 320.ms)
                    .slideY(begin: 0.2, end: 0, delay: 240.ms),
                const SizedBox(height: 8),
                Text(
                  'streak_premium_modal_subtitle'.tr(
                    namedArgs: {'days': '${bonus.milestoneStreak}'},
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 320.ms, duration: 280.ms),
                if (bonus.newPremiumUntil != null) ...[
                  const SizedBox(height: 14),
                  _UntilCard(date: bonus.newPremiumUntil!),
                ],
                const SizedBox(height: 18),
                _CloseButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CrownBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFDB022).withValues(alpha: 0.4),
                  const Color(0xFFFDB022).withValues(alpha: 0.0),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.85, end: 1.1, duration: 1300.ms)
              .fadeIn(duration: 320.ms),
          Container(
            width: 70,
            height: 70,
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
            alignment: Alignment.center,
            child: const Text('👑', style: TextStyle(fontSize: 36)),
          )
              .animate()
              .scaleXY(
                begin: 0.4,
                end: 1.0,
                duration: 520.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 280.ms),
        ],
      ),
    );
  }
}

class _UntilCard extends StatelessWidget {
  final DateTime date;
  const _UntilCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final localeTag = context.locale.toLanguageTag();
    final formatted = DateFormat.yMMMMd(localeTag).format(date.toLocal());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF6E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFDB022).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'streak_premium_modal_body'.tr(
                namedArgs: {'date': formatted},
              ),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
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
            child: Text(
              'streak_premium_modal_close'.tr(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
