import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Replace Russian words the backend still emits inside the `tg`
/// description field with their Tajik equivalents. This is a surgical
/// client-side patch until the content team cleans up the server data
/// — without it users see half-Russian "Обновление" text inside a
/// Tajik-titled dialog.
String _sanitizeTajik(String input) {
  if (input.isEmpty) return input;
  const replacements = <String, String>{
    // Nouns — various cases / numbers. Order matters: longer forms
    // must come before shorter ones so "обновления" isn't clobbered
    // by "обновление" first.
    'Обновления': 'Навсозиҳо',
    'обновления': 'навсозиҳо',
    'Обновление': 'Навсозӣ',
    'обновление': 'навсозӣ',
    'Обновлении': 'Навсозӣ',
    'обновлении': 'навсозӣ',
    'Обновлений': 'Навсозиҳо',
    'обновлений': 'навсозиҳо',
    'версии': 'версияи',
    'Версии': 'Версияи',
    'приложения': 'барнома',
    'Приложения': 'Барнома',
    'приложение': 'барнома',
    'Приложение': 'Барнома',
  };
  var out = input;
  replacements.forEach((from, to) {
    out = out.replaceAll(from, to);
  });
  return out;
}

/// Turn an inline numbered list ("... 1. Foo 2. Bar 3. Baz ...") into a
/// vertical list with each item on its own line. The regex is tight on
/// purpose — it needs a leading whitespace, 1–2 digits, a dot, and a
/// trailing space — so semver strings like "2.60" don't get cracked
/// open into "2. 60".
String _formatNumberedList(String input) {
  if (input.isEmpty) return input;
  return input.replaceAllMapped(
    RegExp(r'\s(\d{1,2})\.\s'),
    (m) => '\n${m[1]}. ',
  );
}

/// Shared bottom-shadow yellow "Update" CTA used by both dialogs so the
/// visual weight of the primary action is consistent.
class _UpdateCta extends StatefulWidget {
  final VoidCallback onTap;
  const _UpdateCta({required this.onTap});

  @override
  State<_UpdateCta> createState() => _UpdateCtaState();
}

class _UpdateCtaState extends State<_UpdateCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 90),
        offset: Offset(0, _pressed ? 0.04 : 0),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E90FA), Color(0xFF1570EF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(
                color: _pressed
                    ? Colors.transparent
                    : const Color(0xFF0E4FBB),
                width: 4,
              ),
            ),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: const Color(0xFF1570EF).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.system_update_alt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'update'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large illustrated "update available" hero at the top of the dialog:
/// a blue gradient disc with a phone icon and an upward arrow. Reads
/// as "your app has something new waiting".
class _UpdateHero extends StatelessWidget {
  const _UpdateHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft pulsing outer glow.
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2E90FA).withValues(alpha: 0.28),
                  const Color(0xFF2E90FA).withValues(alpha: 0.0),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.9, end: 1.1, duration: 1500.ms),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF2E90FA), Color(0xFF1570EF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.55, 1.0],
              ),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1570EF).withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Specular highlight for the glossy look.
                Positioned(
                  top: 8,
                  left: 14,
                  child: Container(
                    width: 30,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .scaleXY(
                begin: 0.4,
                end: 1.0,
                duration: 620.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 260.ms),
          // "UP" arrow badge that springs in to hint at "upgrade".
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFFDB022)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE48B0B).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            )
                .animate()
                .scaleXY(
                  begin: 0.1,
                  end: 1.0,
                  delay: 240.ms,
                  duration: 520.ms,
                  curve: Curves.elasticOut,
                )
                .rotate(
                  begin: -0.15,
                  end: 0.0,
                  delay: 240.ms,
                  duration: 520.ms,
                ),
          ),
        ],
      ),
    );
  }
}

/// Small version pill under the title — e.g. "v2.61.0".
class _VersionPill extends StatelessWidget {
  final String version;
  const _VersionPill({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2E90FA).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E90FA).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.new_releases_rounded,
            color: Color(0xFF1570EF),
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            'v$version',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1570EF),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny decorative sparkle field behind the hero — same visual
/// vocabulary as `rewards_celebration` so update / reward popups read
/// as part of the same family.
class _Sparkles extends StatelessWidget {
  const _Sparkles();

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(7);
    return Stack(
      children: List.generate(10, (i) {
        return _SparkleDot(
          left: 10 + rng.nextDouble() * 300,
          top: 6 + rng.nextDouble() * 130,
          size: 4 + rng.nextDouble() * 5,
          delay: Duration(milliseconds: 80 + rng.nextInt(700)),
          color: i.isEven
              ? const Color(0xFF2E90FA)
              : const Color(0xFFFDB022),
        );
      }),
    );
  }
}

class _SparkleDot extends StatelessWidget {
  final double left;
  final double top;
  final double size;
  final Duration delay;
  final Color color;

  const _SparkleDot({
    required this.left,
    required this.top,
    required this.size,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.5),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 600.ms, delay: delay)
          .scaleXY(begin: 0.3, end: 1.0, duration: 900.ms, delay: delay),
    );
  }
}

/// Shared container that gives both update dialogs the same soft-gradient
/// header, shadow, and rounded corners. Pulled out so the two dialogs
/// don't drift apart visually over time.
class _UpdateDialogShell extends StatelessWidget {
  final Widget child;
  const _UpdateDialogShell({required this.child});

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
              colors: [
                Color(0xFFEFF6FF), // soft blue at top — update-themed
                Colors.white,
              ],
              stops: [0.0, 0.45],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E90FA).withValues(alpha: 0.2),
                blurRadius: 50,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top accent band with a blue-gold gradient.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDDEBFE),
                        Color(0xFFEFF6FF),
                        Color(0xFFFFF4E1),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(child: _Sparkles()),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Forced (mandatory) update dialog — cannot be dismissed.
/// Matches Unity UINewUpdateRequire.
class ForceUpdateDialog extends StatelessWidget {
  final String version;
  final String description;

  const ForceUpdateDialog({
    required this.version,
    required this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final shownDescription = _formatNumberedList(
      locale == 'tg' ? _sanitizeTajik(description) : description,
    );
    return PopScope(
      canPop: false,
      child: _UpdateDialogShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _UpdateHero(),
              const SizedBox(height: 14),
              Text(
                'mandatory_update'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2939),
                  letterSpacing: -0.3,
                ),
              )
                  .animate()
                  .fadeIn(delay: 240.ms, duration: 320.ms)
                  .slideY(
                    begin: 0.25,
                    end: 0,
                    delay: 240.ms,
                    duration: 360.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 10),
              _VersionPill(version: version)
                  .animate()
                  .fadeIn(delay: 320.ms, duration: 280.ms)
                  .slideY(begin: 0.3, end: 0, delay: 320.ms),
              if (shownDescription.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    shownDescription,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF475467),
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 420.ms, duration: 320.ms)
                    .slideY(begin: 0.15, end: 0, delay: 420.ms),
              ],
              const SizedBox(height: 22),
              _UpdateCta(onTap: _openStore)
                  .animate()
                  .fadeIn(delay: 540.ms, duration: 300.ms)
                  .slideY(begin: 0.3, end: 0, delay: 540.ms, duration: 320.ms),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optional update dialog — can be dismissed with Cancel.
/// Matches Unity UINewUpdate.
class OptionalUpdateDialog extends StatelessWidget {
  final String version;
  final String description;

  const OptionalUpdateDialog({
    required this.version,
    required this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final shownDescription = _formatNumberedList(
      locale == 'tg' ? _sanitizeTajik(description) : description,
    );
    return _UpdateDialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _UpdateHero(),
            const SizedBox(height: 14),
            Text(
              'new_update'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D2939),
                letterSpacing: -0.3,
              ),
            )
                .animate()
                .fadeIn(delay: 240.ms, duration: 320.ms)
                .slideY(
                  begin: 0.25,
                  end: 0,
                  delay: 240.ms,
                  duration: 360.ms,
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 10),
            _VersionPill(version: version)
                .animate()
                .fadeIn(delay: 320.ms, duration: 280.ms)
                .slideY(begin: 0.3, end: 0, delay: 320.ms),
            if (shownDescription.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  shownDescription,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF475467),
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 420.ms, duration: 320.ms)
                  .slideY(begin: 0.15, end: 0, delay: 420.ms),
            ],
            const SizedBox(height: 20),
            _UpdateCta(onTap: _openStore)
                .animate()
                .fadeIn(delay: 540.ms, duration: 300.ms)
                .slideY(begin: 0.3, end: 0, delay: 540.ms, duration: 320.ms),
            const SizedBox(height: 10),
            // Cancel stays a neutral ghost button so it doesn't compete
            // with the primary Update CTA above.
            MyButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              buttonColor: const Color(0xFFF2F4F7),
              backButtonColor: const Color(0xFFD0D5DD),
              width: double.infinity,
              depth: 3,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'cancel'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475467),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 640.ms, duration: 280.ms),
          ],
        ),
      ),
    );
  }
}

/// Opens the appropriate store based on platform.
void _openStore() {
  final String url;
  if (Platform.isIOS) {
    url = 'https://apps.apple.com/tj/app/vozhaomuz/id6476831935';
  } else {
    url = 'https://play.google.com/store/apps/details?id=com.vozhaomuz';
  }
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
