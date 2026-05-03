import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/profile_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/shared/widgets/energy_paywall_dialog.dart';

/// Home page header section with user avatar, name, premium badge, and coins.
/// Extracted from home_page.dart for better maintainability.
class HomeHeaderSection extends ConsumerWidget {
  final bool isPremium;

  /// Premium expiry timestamp (UTC). The header picks the right unit
  /// — days, hours, or minutes — based on how much time is left so
  /// the last 24 hours don't display as "0 days left" anymore.
  final DateTime? expiryUtc;

  const HomeHeaderSection({super.key, required this.isPremium, this.expiryUtc});

  /// Returns the localized "premium left" label, picking the largest
  /// non-zero unit so the user never sees "0 days" while there's
  /// still time remaining.
  String _formatRemaining() {
    if (expiryUtc == null) return 'premium_days_left'.tr(args: ['0']);
    final remaining = expiryUtc!.difference(DateTime.now().toUtc());
    if (remaining.isNegative || remaining == Duration.zero) {
      return 'premium_expired'.tr();
    }
    if (remaining.inDays >= 1) {
      return 'premium_days_left'.tr(args: ['${remaining.inDays}']);
    }
    if (remaining.inHours >= 1) {
      return 'premium_hours_left'.tr(args: ['${remaining.inHours}']);
    }
    final minutes = remaining.inMinutes.clamp(1, 59);
    return 'premium_minutes_left'.tr(args: ['$minutes']);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileInfo = ref.watch(getProfileInfoProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            image: isPremium
                ? const DecorationImage(
                    fit: BoxFit.cover,
                    image: AssetImage("assets/images/Group 48095322.png"),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAvatarStack(context, ref, profileInfo),
                const SizedBox(width: 10),
                _buildNameColumn(context, ref, profileInfo),
              ],
            ),
          ),
        ),
        const _EnergyHeaderButton(),
      ],
    );
  }

  Widget _buildAvatarStack(
    BuildContext context,
    WidgetRef ref,
    AsyncValue profileInfo,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfilePage()),
            );
          },
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                    gradient: isPremium
                        ? const LinearGradient(
                            colors: [Color(0xFFFFE08A), Color(0xFFE48B0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: isPremium
                        ? null
                        : Border.all(
                            color: const Color(0xFFD9D9D9),
                            width: 0.5,
                          ),
                  ),
                  padding: isPremium ? const EdgeInsets.all(2.5) : null,
                  child: ClipOval(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: profileInfo.when(
                          data: (data) {
                            final url = data?.avatarUrl;
                            if (url != null && url.isNotEmpty) {
                              return CachedNetworkImage(
                                imageUrl: buildAvatarUrl(url),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Image.asset(
                                  'assets/images/UIHome/usercircle.png',
                                ),
                              );
                            } else {
                              return Image.asset(
                                'assets/images/UIHome/usercircle.png',
                              );
                            }
                          },
                          loading: () => Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          error: (_, __) => const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isPremium)
          Positioned(
            top: -20,
            right: 10,
            child: Image.asset(
              'assets/images/group_2.png',
              width: 30,
              height: 30,
            ),
          ),
      ],
    );
  }

  Widget _buildNameColumn(
    BuildContext context,
    WidgetRef ref,
    AsyncValue profileInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        profileInfo.when(
          data: (data) => Text(
            (data?.name?.isNotEmpty ?? false) ? data!.name! : 'Loading...'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          error: (_, __) => Text('Error'.tr()),
          loading: () => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: 70,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        isPremium
            ? Text(
                _formatRemaining(),
                style: const TextStyle(color: Colors.orange, fontSize: 11),
              )
            : GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MySubscriptionPage(),
                    ),
                  );
                },
                child: Text(
                  "buy_premium".tr(),
                  style: const TextStyle(color: Colors.orange, fontSize: 11),
                ),
              ),
      ],
    );
  }
}

/// Energy pill in the header. Owns a 30-second ticker that calls
/// `energyProvider.tick()` — applyRegen rolls whole minutes of elapsed
/// time into the balance without any network roundtrip, so the number
/// goes up live when a regen unit is earned (every 20 minutes) while
/// the user is sitting on the home page.
class _EnergyHeaderButton extends ConsumerStatefulWidget {
  const _EnergyHeaderButton();

  @override
  ConsumerState<_EnergyHeaderButton> createState() =>
      _EnergyHeaderButtonState();
}

class _EnergyHeaderButtonState extends ConsumerState<_EnergyHeaderButton> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.read(energyProvider.notifier).tick();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final energy = ref.watch(energyProvider);
    final display = energy.isPremium
        ? '∞'
        : energy.balance.toStringAsFixed(energy.balance % 1 == 0 ? 0 : 1);
    final accent = energy.isPremium
        ? const Color(0xFFFDB022)
        : const Color(0xFFFFB020);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showEnergyPaywallDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: accent.withOpacity(0.12),
          border: Border.all(color: accent.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              energy.isPremium ? '👑' : '⚡',
              style: const TextStyle(fontSize: 16),
            ),
            const Gap(4),
            Text(
              display,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1D2939),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
