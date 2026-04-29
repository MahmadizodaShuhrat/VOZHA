import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';

// ─────────────────── Banner Config ───────────────────

/// Data class holding all visual config for a banner type.
class _BannerConfig {
  final Color startColor;
  final Color endColor;
  final String title;
  final String subtitle;
  final Widget icon;
  final String? buttonText;
  final Color? buttonTextColor;
  final double circleSize;

  const _BannerConfig({
    required this.startColor,
    required this.endColor,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.buttonText,
    this.buttonTextColor,
    this.circleSize = 160,
  });
}

// ─────────────────── Builder ───────────────────

/// Builds a Flutter widget for each banner type.
class BannerWidgetBuilder {
  BannerWidgetBuilder._();

  static Widget buildBanner(BannerDto banner) {
    final config = _configs[banner.title];
    if (config != null) return _BannerCard(config: config);

    // Unknown banner type — generic fallback
    return _BannerCard(
      config: _BannerConfig(
        startColor: const Color(0xFF2E90FA),
        endColor: const Color(0xFF1570EF),
        title: banner.title,
        subtitle: '',
        icon: const Icon(Icons.info_outline, color: Colors.white, size: 48),
      ),
    );
  }

  /// All banner configs in one place — easy to add/edit.
  static final Map<String, _BannerConfig> _configs = {
    'UIBannerDiscount': _BannerConfig(
      startColor: const Color(0xFFFF512F),
      endColor: const Color(0xFFDD2476),
      title: 'banner_discount_title'.tr(),
      subtitle: 'banner_discount_subtitle'.tr(),
      icon: const Text('🔥', style: TextStyle(fontSize: 48)),
      buttonText: 'coin_buy'.tr(),
      buttonTextColor: const Color(0xFFDD2476),
    ),
    'UIBannerInstagram': _BannerConfig(
      startColor: const Color(0xFF833AB4),
      endColor: const Color(0xFFE1306C),
      title: 'banner_instagram_title'.tr(),
      subtitle: '@vozhaomuz.app',
      icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 48),
    ),
    'UIBannerInviteFriend': _BannerConfig(
      startColor: const Color(0xFF20CD7F),
      endColor: const Color(0xFF11998E),
      title: 'banner_invite_title'.tr(),
      subtitle: 'banner_invite_subtitle'.tr(),
      icon: const Icon(
        Icons.person_add_alt_1_rounded,
        color: Colors.white,
        size: 48,
      ),
    ),
    'UIBannerBattle': _BannerConfig(
      startColor: const Color(0xFF2E90FA),
      endColor: const Color(0xFF1565C0),
      title: 'banner_battle_title'.tr(),
      subtitle: 'banner_battle_subtitle'.tr(),
      circleSize: 180,
      icon: Image.asset(
        'assets/images/Textures/Banners/image 178.png',
        width: 65,
        height: 65,
        errorBuilder: (_, __, ___) =>
            const Text('⚔️', style: TextStyle(fontSize: 48)),
      ),
      buttonText: 'banner_battle_play'.tr(),
      buttonTextColor: const Color(0xFF2E90FA),
    ),
    'UIEnglish24': _BannerConfig(
      startColor: const Color(0xFF667EEA),
      endColor: const Color(0xFF764BA2),
      title: 'banner_english24_title'.tr(),
      subtitle: 'banner_english24_subtitle'.tr(),
      icon: const Text('🇬🇧', style: TextStyle(fontSize: 48)),
    ),
    'UIWithNewUsers': _BannerConfig(
      startColor: const Color(0xFF20CD7F),
      endColor: const Color(0xFF0D8B6D),
      title: 'banner_newusers_title'.tr(),
      subtitle: 'banner_newusers_subtitle'.tr(),
      icon: Image.asset(
        'assets/images/Textures/Banners/Frame.png',
        width: 60,
        height: 60,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.groups_rounded, color: Colors.white, size: 48),
      ),
    ),
    'UIBannerPremium': _BannerConfig(
      startColor: const Color(0xFFF7971E),
      endColor: const Color(0xFFFFD200),
      title: 'banner_premium_title'.tr(),
      subtitle: 'banner_premium_subtitle'.tr(),
      icon: Image.asset(
        'assets/images/crownuserpremium.png',
        width: 52,
        height: 52,
        errorBuilder: (_, __, ___) =>
            const Text('👑', style: TextStyle(fontSize: 48)),
      ),
      buttonText: 'coin_buy'.tr(),
      buttonTextColor: const Color(0xFFF57C00),
    ),
  };
}

// ─────────────────── Banner Card ───────────────────

/// A single premium banner card rendered from [_BannerConfig].
class _BannerCard extends StatelessWidget {
  final _BannerConfig config;
  const _BannerCard({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [config.startColor, config.endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: config.startColor.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // ── Shimmer overlay ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.transparent,
                      Colors.black.withOpacity(0.08),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // ── Decorative circle (top-left) ──
            Positioned(
              left: -30,
              top: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),

            // ── Main circle with icon (right) ──
            Positioned(
              right: -config.circleSize * 0.2,
              top: -(config.circleSize * 0.15),
              bottom: -(config.circleSize * 0.15),
              child: Container(
                width: config.circleSize,
                height: config.circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Center(child: config.icon),
              ),
            ),

            // ── Text content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 100, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    config.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    config.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Action button (optional)
                  if (config.buttonText != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        config.buttonText!,
                        style: TextStyle(
                          color: config.buttonTextColor ?? config.startColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
