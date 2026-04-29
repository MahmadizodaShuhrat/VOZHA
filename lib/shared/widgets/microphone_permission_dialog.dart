import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Pre-prompt dialog explaining why we need the microphone — shown
/// before the OS permission dialog so users don't reflexively dismiss
/// the system prompt without context.
///
/// Resolves with `true` when the user taps "Continue" (caller should
/// then trigger the actual `Permission.microphone.request()`),
/// `false` when they cancel or dismiss.
Future<bool> showMicPermissionExplainer(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => const _MicPermissionDialog(
      variant: _Variant.explainer,
    ),
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
  return result ?? false;
}

/// Variant of the dialog shown when the OS reports the permission as
/// permanently denied (user previously hit "Don't ask again"). Resolves
/// with `true` if the user agrees to open app settings.
Future<bool> showMicPermissionSettings(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => const _MicPermissionDialog(
      variant: _Variant.settings,
    ),
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
  return result ?? false;
}

enum _Variant { explainer, settings }

class _MicPermissionDialog extends StatelessWidget {
  final _Variant variant;

  const _MicPermissionDialog({required this.variant});

  @override
  Widget build(BuildContext context) {
    final isExplainer = variant == _Variant.explainer;
    final accent = const Color(0xFF3B82F6); // brand blue
    final accentDark = const Color(0xFF1D4ED8);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEFF6FF), Colors.white],
              stops: [0.0, 0.4],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MicIconBadge(accent: accent, accentDark: accentDark),
                const SizedBox(height: 18),
                Text(
                  'mic_permission_title'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 120.ms, duration: 260.ms)
                    .slideY(begin: 0.2, end: 0, delay: 120.ms),
                const SizedBox(height: 10),
                Text(
                  isExplainer
                      ? 'mic_permission_explainer_message'.tr()
                      : 'mic_permission_settings_message'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 260.ms),
                if (isExplainer) ...[
                  const SizedBox(height: 16),
                  // Visual cue showing the exact button label the user
                  // should tap on the OS dialog. Pulses gently to draw
                  // the eye.
                  _AllowButtonHint(accent: accent),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label: 'cancel'.tr(),
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _PrimaryButton(
                        label: isExplainer
                            ? 'continue'.tr()
                            : 'open_settings'.tr(),
                        accent: accent,
                        accentDark: accentDark,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 320.ms, duration: 260.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MicIconBadge extends StatelessWidget {
  final Color accent;
  final Color accentDark;
  const _MicIconBadge({required this.accent, required this.accentDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft pulsing halo behind the badge.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.35),
                  accent.withValues(alpha: 0.0),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.8, end: 1.05, duration: 1300.ms)
              .fadeIn(duration: 300.ms),
          // Solid gradient badge with the mic glyph.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, accentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
          )
              .animate()
              .scaleXY(
                begin: 0.6,
                end: 1.0,
                duration: 420.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 280.ms),
        ],
      ),
    );
  }
}

class _AllowButtonHint extends StatelessWidget {
  final Color accent;
  const _AllowButtonHint({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: accent, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
                children: const [
                  TextSpan(text: '«'),
                  TextSpan(
                    text: 'Разрешить',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: '» / '),
                  TextSpan(
                    text: 'Allow',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.03, duration: 900.ms);
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color accent;
  final Color accentDark;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.accent,
    required this.accentDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [accent, accentDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
