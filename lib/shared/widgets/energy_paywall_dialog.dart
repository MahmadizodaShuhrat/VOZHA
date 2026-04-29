import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/core/services/energy_service.dart';
import 'package:vozhaomuz/core/services/unity_ad_service.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Show the energy dialog with a spring scale-in + fade entry. Content adapts
/// to the user's state: premium / full / partial / empty.
Future<void> showEnergyPaywallDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => const _EnergyPaywallDialog(),
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

enum _Variant { empty, partial, full, premium }

_Variant _variantFor(EnergyState e) {
  if (e.isPremium) return _Variant.premium;
  // "empty" means the user can't start a game — not just balance == 0.
  // A balance below the base cost (1.0) still blocks play, so the dialog
  // must use the blocking copy / Wait button, not "keep playing".
  if (e.balance < AppConstants.energyBaseCost) return _Variant.empty;
  if (e.balance >= e.max) return _Variant.full;
  return _Variant.partial;
}

class _Palette {
  final Color primary;
  final Color primaryDark;
  final List<Color> iconGradient;
  final List<Color> ringGlow;
  const _Palette({
    required this.primary,
    required this.primaryDark,
    required this.iconGradient,
    required this.ringGlow,
  });
}

_Palette _paletteFor(_Variant v) {
  switch (v) {
    case _Variant.premium:
      return const _Palette(
        primary: Color(0xFFFDB022),
        primaryDark: Color(0xFFB07306),
        iconGradient: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ringGlow: [Color(0x66FDB022), Color(0x00FDB022)],
      );
    case _Variant.empty:
      return const _Palette(
        primary: Color(0xFFEF4444),
        primaryDark: Color(0xFFB91C1C),
        iconGradient: [Color(0xFFFFC857), Color(0xFFFF6B35)],
        ringGlow: [Color(0x4DEF4444), Color(0x00EF4444)],
      );
    case _Variant.partial:
    case _Variant.full:
      return const _Palette(
        primary: Color(0xFFFFB020),
        primaryDark: Color(0xFFD97706),
        iconGradient: [Color(0xFFFFE27A), Color(0xFFFFB020)],
        ringGlow: [Color(0x4DFFB020), Color(0x00FFB020)],
      );
  }
}

class _EnergyPaywallDialog extends ConsumerStatefulWidget {
  const _EnergyPaywallDialog();

  @override
  ConsumerState<_EnergyPaywallDialog> createState() =>
      _EnergyPaywallDialogState();
}

class _EnergyPaywallDialogState extends ConsumerState<_EnergyPaywallDialog>
    with TickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Slow heartbeat on the icon — scales 1.0 ↔ 1.08 forever.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      ref.read(energyProvider.notifier).tick();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final energy = ref.watch(energyProvider);
    final variant = _variantFor(energy);
    final palette = _paletteFor(variant);
    final balanceLabel = energy.balance.toStringAsFixed(
      energy.balance % 1 == 0 ? 0 : 1,
    );
    final namedArgs = {
      'balance': balanceLabel,
      'max': energy.max.toString(),
    };
    final titleKey = _titleKey(variant);
    final subtitleKey = _subtitleKey(variant);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withOpacity(0.12),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedIcon(
                pulse: _pulse,
                variant: variant,
                palette: palette,
              ),
              const SizedBox(height: 22),
              Text(
                titleKey.tr(namedArgs: namedArgs),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2939),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitleKey.tr(namedArgs: namedArgs),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF667085),
                  height: 1.45,
                ),
              ),
              // Progress bar — for non-premium users only (premium = infinite)
              if (variant != _Variant.premium) ...[
                const SizedBox(height: 20),
                _EnergyBar(
                  value: energy.balance / energy.max,
                  palette: palette,
                ),
              ],
              // Countdown — only when actively regenerating
              if (variant == _Variant.empty || variant == _Variant.partial) ...[
                const SizedBox(height: 14),
                _Countdown(
                  text: 'energy_paywall_next_refill'.tr(
                    namedArgs: {
                      'time': _formatDuration(
                        energy.nextRefillIn(DateTime.now()),
                      ),
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ..._buildActions(variant, palette),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle the "refill for N coins" button. Backend does coin deduction +
  /// energy top-up atomically; we sync the new money balance into the profile
  /// provider, then show a nice success / error dialog on top of the paywall.
  Future<void> _onCoinRefillPressed(BuildContext context) async {
    HapticFeedback.lightImpact();
    final priorCoins =
        ref.read(getProfileInfoProvider).value?.money ?? 0;
    try {
      final result = await ref.read(energyProvider.notifier).refillToMax();
      if (!mounted) return;
      if (result == null) {
        await _showRefillErrorDialog(
          context,
          titleKey: 'energy_refill_error_title_generic',
          messageKey: 'energy_refill_error_server',
          emoji: '⚠️',
        );
        return;
      }
      ref
          .read(getProfileInfoProvider.notifier)
          .syncMoneyFromServer(result.money.toInt());
      // Pop the paywall FIRST so the success dialog animates onto a clean
      // background rather than stacking on top of the now-stale paywall.
      Navigator.of(context).pop();
      await _showRefillSuccessDialog(
        context,
        newBalance: result.energy.balance.toInt(),
        max: result.energy.max,
        coinsSpent: result.coinsSpent,
      );
    } on EnergyRefillException catch (e) {
      if (!mounted) return;
      switch (e.error) {
        case EnergyRefillError.insufficientCoins:
          await _showRefillErrorDialog(
            context,
            titleKey: 'energy_refill_error_title_insufficient',
            messageKey: 'energy_refill_error_insufficient_details',
            namedArgs: {
              'price': AppConstants.energyRefillCoinPrice.toString(),
              'current': priorCoins.toString(),
            },
            emoji: '🪙',
          );
          break;
        case EnergyRefillError.alreadyFull:
          Navigator.of(context).pop();
          await _showRefillErrorDialog(
            context,
            titleKey: 'energy_refill_error_title_already_full',
            messageKey: 'energy_refill_error_already_full',
            emoji: '⚡',
          );
          break;
        case EnergyRefillError.premiumUser:
          Navigator.of(context).pop();
          await _showRefillErrorDialog(
            context,
            titleKey: 'energy_refill_error_title_premium',
            messageKey: 'energy_refill_error_premium',
            emoji: '👑',
          );
          break;
        case EnergyRefillError.unauthorized:
          await _showRefillErrorDialog(
            context,
            titleKey: 'energy_refill_error_title_generic',
            messageKey: 'energy_refill_error_unauthorized',
            emoji: '🔒',
          );
          break;
      }
    }
  }

  String _titleKey(_Variant v) => switch (v) {
        _Variant.empty => 'energy_paywall_title',
        _Variant.partial => 'energy_paywall_title_partial',
        _Variant.full => 'energy_paywall_title_full',
        _Variant.premium => 'energy_paywall_title_premium',
      };

  String _subtitleKey(_Variant v) => switch (v) {
        _Variant.empty => 'energy_paywall_subtitle',
        _Variant.partial => 'energy_paywall_subtitle_partial',
        _Variant.full => 'energy_paywall_subtitle_full',
        _Variant.premium => 'energy_paywall_subtitle_premium',
      };

  List<Widget> _buildActions(_Variant variant, _Palette palette) {
    if (variant == _Variant.premium) {
      return [
        SizedBox(
          width: double.infinity,
          child: MyButton(
            height: 52,
            borderRadius: 16,
            backButtonColor: palette.primaryDark,
            buttonColor: palette.primary,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MySubscriptionPage()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'energy_paywall_manage_subscription'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: MyButton(
            height: 52,
            borderRadius: 16,
            backButtonColor: const Color(0xFFD0D5DD),
            buttonColor: const Color(0xFFF2F4F7),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Text(
              'energy_paywall_close'.tr(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475467),
              ),
            ),
          ),
        ),
      ];
    }

    final dismissKey = variant == _Variant.empty
        ? 'energy_paywall_wait'
        : 'energy_paywall_ok';
    // Ads are only initialised after a few sign-ins (see UnityAdService) and
    // we don't waste the button slot on users who are already at cap.
    final showAdButton = UnityAdService.instance.isInitialized &&
        variant != _Variant.full;
    // Trade 50 coins → full energy. Always visible to non-full users so
    // they discover the feature — disabled style when coins < 50, and
    // tapping while disabled opens the "not enough coins" dialog instead
    // of hitting the server.
    final currentCoins =
        ref.watch(getProfileInfoProvider).value?.money ?? 0;
    final showCoinRefill = variant != _Variant.full;
    final canAffordRefill =
        currentCoins >= AppConstants.energyRefillCoinPrice;

    return [
      SizedBox(
        width: double.infinity,
        child: MyButton(
          height: 52,
          borderRadius: 16,
          backButtonColor: const Color(0xFF1D4ED8),
          buttonColor: const Color(0xFF2563EB),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MySubscriptionPage()),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'energy_paywall_go_premium'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      if (showAdButton) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: MyButton(
            height: 52,
            borderRadius: 16,
            backButtonColor: const Color(0xFF057A55),
            buttonColor: const Color(0xFF10B981),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
              // Rewarded ad → +1 on complete. Skipping or closing early
              // yields nothing — that's Unity's built-in behaviour.
              UnityAdService.instance.loadAndShowRewardedAd(
                onComplete: () {
                  ref.read(energyProvider.notifier).grantFromAd();
                },
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'energy_paywall_watch_ad'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      if (showCoinRefill) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: MyButton(
            height: 52,
            borderRadius: 16,
            // Greyed-out when the user can't afford the swap, so the
            // feature is discoverable but clearly inactive. Tapping while
            // disabled opens the "not enough coins" dialog with their
            // current / required balance so they know exactly what's missing.
            backButtonColor: canAffordRefill
                ? const Color(0xFFB45309)
                : const Color(0xFFD0D5DD),
            buttonColor: canAffordRefill
                ? const Color(0xFFFDB022)
                : const Color(0xFFF2F4F7),
            onPressed: canAffordRefill
                ? () => _onCoinRefillPressed(context)
                : () => _showRefillErrorDialog(
                      context,
                      titleKey: 'energy_refill_error_title_insufficient',
                      messageKey: 'energy_refill_error_insufficient_details',
                      namedArgs: {
                        'price':
                            AppConstants.energyRefillCoinPrice.toString(),
                        'current': currentCoins.toString(),
                      },
                      emoji: '🪙',
                    ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🪙',
                    style: TextStyle(
                      fontSize: 20,
                      color: canAffordRefill
                          ? Colors.white
                          : const Color(0xFF98A2B3),
                    )),
                const SizedBox(width: 8),
                Text(
                  'energy_paywall_buy_with_coins'.tr(
                    namedArgs: {
                      'price':
                          AppConstants.energyRefillCoinPrice.toString(),
                    },
                  ),
                  style: TextStyle(
                    color: canAffordRefill
                        ? Colors.white
                        : const Color(0xFF98A2B3),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: MyButton(
          height: 52,
          borderRadius: 16,
          backButtonColor: const Color(0xFFD0D5DD),
          buttonColor: const Color(0xFFF2F4F7),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: Text(
            dismissKey.tr(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475467),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Concentric glow + scaling bolt (or crown for premium) on an infinite
/// heartbeat. The glow ring pulses in the opposite direction of the icon for
/// a richer, more "alive" feel.
class _AnimatedIcon extends StatelessWidget {
  final Animation<double> pulse;
  final _Variant variant;
  final _Palette palette;

  const _AnimatedIcon({
    required this.pulse,
    required this.variant,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring — breathes opposite to icon scale
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final t = pulse.value;
              return Container(
                width: 112 + (12 * t),
                height: 112 + (12 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: palette.ringGlow,
                    stops: const [0.5, 1.0],
                  ),
                ),
              );
            },
          ),
          // Inner solid disk
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: palette.iconGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                  CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
                ),
                child: Text(
                  variant == _Variant.premium ? '👑' : '⚡',
                  style: const TextStyle(fontSize: 56),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Energy progress bar. Width animates smoothly when balance changes; fill
/// uses a gradient tinted by the current variant.
class _EnergyBar extends StatelessWidget {
  final double value; // 0..1
  final _Palette palette;

  const _EnergyBar({required this.value, required this.palette});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (_, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 10,
            color: const Color(0xFFF1F5F9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * clamped,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: palette.iconGradient,
                  ),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: palette.primary.withOpacity(0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Countdown extends StatelessWidget {
  final String text;
  const _Countdown({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF475467)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown after a successful coin→energy swap. Big ⚡ badge + balance line
/// + coins spent + single primary button. Pops on its own.
Future<void> _showRefillSuccessDialog(
  BuildContext context, {
  required int newBalance,
  required int max,
  required int coinsSpent,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => _RefillResultDialog(
      emoji: '⚡',
      badgeGradient: const [Color(0xFFFFE27A), Color(0xFFFFB020)],
      glow: const Color(0xFFFFB020),
      title: 'energy_refill_success_title'.tr(),
      message: 'energy_refill_success_message'.tr(
        namedArgs: {
          'balance': newBalance.toString(),
          'max': max.toString(),
          'coins': coinsSpent.toString(),
        },
      ),
      buttonLabel: 'energy_refill_success_play'.tr(),
      buttonColor: const Color(0xFF10B981),
      buttonDark: const Color(0xFF057A55),
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
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

/// Shown on any refill-side error that we want to surface prominently
/// (insufficient coins, already full, premium, unauthorized, generic).
Future<void> _showRefillErrorDialog(
  BuildContext context, {
  required String titleKey,
  required String messageKey,
  required String emoji,
  Map<String, String>? namedArgs,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _RefillResultDialog(
      emoji: emoji,
      badgeGradient: const [Color(0xFFFEE4E2), Color(0xFFFEC4C4)],
      glow: const Color(0xFFF04438),
      title: titleKey.tr(),
      message: messageKey.tr(namedArgs: namedArgs ?? const {}),
      buttonLabel: 'energy_paywall_close'.tr(),
      buttonColor: const Color(0xFFF2F4F7),
      buttonDark: const Color(0xFFD0D5DD),
      buttonTextColor: const Color(0xFF475467),
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
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

/// Reusable card for the post-refill outcome dialogs. Pulsing emoji badge,
/// title, message, single CTA button.
class _RefillResultDialog extends StatefulWidget {
  final String emoji;
  final List<Color> badgeGradient;
  final Color glow;
  final String title;
  final String message;
  final String buttonLabel;
  final Color buttonColor;
  final Color buttonDark;
  final Color buttonTextColor;

  const _RefillResultDialog({
    required this.emoji,
    required this.badgeGradient,
    required this.glow,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.buttonColor,
    required this.buttonDark,
    this.buttonTextColor = Colors.white,
  });

  @override
  State<_RefillResultDialog> createState() => _RefillResultDialogState();
}

class _RefillResultDialogState extends State<_RefillResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: widget.glow.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: 90 + (10 * _pulse.value),
                        height: 90 + (10 * _pulse.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.glow.withValues(alpha: 0.28),
                              widget.glow.withValues(alpha: 0.0),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: widget.badgeGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.glow.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                            CurvedAnimation(
                                parent: _pulse, curve: Curves.easeInOut),
                          ),
                          child: Text(
                            widget.emoji,
                            style: const TextStyle(fontSize: 42),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2939),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF667085),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: MyButton(
                  height: 48,
                  borderRadius: 14,
                  backButtonColor: widget.buttonDark,
                  buttonColor: widget.buttonColor,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    widget.buttonLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.buttonTextColor,
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
}
