import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Trophy detail dialog. Two variants:
///   • [claimed] = false — progress card ("X / N слов" + "выучите N слов чтобы
///     получить…"). Blue accents.
///   • [claimed] = true  — celebration card ("Поздравляем! +N монет за X").
///     Warm gold accents, scale-in icon, shimmer over the coin chip.
void showTrophyDialog({
  required BuildContext context,
  required int countOfWords,
  required int countOfLearnedWords,
  required String gradeOfTrophy,
  required int giftInCoins,
  required String iconUrl,
  bool claimed = false,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => _TrophyDialog(
      countOfWords: countOfWords,
      countOfLearnedWords: countOfLearnedWords,
      gradeOfTrophy: gradeOfTrophy,
      giftInCoins: giftInCoins,
      iconUrl: iconUrl,
      claimed: claimed,
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
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

class _TrophyDialog extends StatelessWidget {
  final int countOfWords;
  final int countOfLearnedWords;
  final String gradeOfTrophy;
  final int giftInCoins;
  final String iconUrl;
  final bool claimed;

  const _TrophyDialog({
    required this.countOfWords,
    required this.countOfLearnedWords,
    required this.gradeOfTrophy,
    required this.giftInCoins,
    required this.iconUrl,
    required this.claimed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = countOfWords > 0
        ? (countOfLearnedWords / countOfWords).clamp(0.0, 1.0)
        : 0.0;

    final accent = claimed
        ? const _Palette(
            primary: Color(0xFFFDB022),
            primaryDark: Color(0xFFB45309),
            progress: Color(0xFF12B76A),
            progressBg: Color(0xFFD1FADF),
            nameColor: Color(0xFFB45309),
          )
        : const _Palette(
            primary: Color(0xFF2563EB),
            primaryDark: Color(0xFF1D4ED8),
            progress: Colors.blue,
            progressBg: Color(0xFFE4E7EC),
            nameColor: Colors.blueAccent,
          );

    return Align(
      alignment: Alignment.center,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TrophyIcon(
                iconUrl: iconUrl,
                claimed: claimed,
                accent: accent,
              ),
              const Gap(20),
              _RewardChip(giftInCoins: giftInCoins, claimed: claimed),
              const Gap(16),
              if (claimed) ...[
                // Celebration block: big "+N coins" + the achievement name.
                Text(
                  'trophy_earned_title'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2939),
                    height: 1.2,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 180.ms, duration: 340.ms)
                    .slideY(begin: 0.3, end: 0, delay: 180.ms, duration: 420.ms),
                const Gap(6),
                Text(
                  '«$gradeOfTrophy»',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accent.nameColor,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 260.ms, duration: 320.ms)
                    .slideY(begin: 0.3, end: 0, delay: 260.ms, duration: 360.ms),
                const Gap(10),
                Text(
                  'trophy_earned_subtitle'.tr(
                    namedArgs: {'coins': giftInCoins.toString()},
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF667085),
                    height: 1.45,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 340.ms, duration: 320.ms),
              ] else ...[
                // Progress block: numeric + bar + "to earn this one, learn N words".
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$countOfLearnedWords',
                      style: TextStyle(
                        color: accent.progress,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      ' /$countOfWords',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: accent.progressBg,
                  color: accent.progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(10),
                ),
                const Gap(14),
                Text(
                  'learn_words_to_earn'.tr(
                    namedArgs: {'count': '$countOfWords'},
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                Text(
                  '«$gradeOfTrophy»!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: accent.nameColor,
                  ),
                ),
              ],
              const Gap(24),
              MyButton(
                height: 52,
                width: double.infinity,
                buttonColor: accent.primary,
                backButtonColor: accent.primaryDark,
                child: Text(
                  textAlign: TextAlign.center,
                  'good'.tr(),
                  style: AppTextStyles.whiteTextStyle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trophy icon. When claimed, wraps the real icon in a soft gold glow plus
/// a spring-scale entry — feels like it just landed. When not claimed,
/// renders the regular (grey) icon without extras.
class _TrophyIcon extends StatelessWidget {
  final String iconUrl;
  final bool claimed;
  final _Palette accent;

  const _TrophyIcon({
    required this.iconUrl,
    required this.claimed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      width: 140,
      height: 140,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: iconUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Icon(
            Icons.emoji_events,
            size: 60,
            color: claimed ? accent.primary : Colors.grey,
          ),
        ),
      ),
    );

    if (!claimed) return image;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.primary.withValues(alpha: 0.28),
                accent.primary.withValues(alpha: 0.0),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
              begin: 0.95,
              end: 1.08,
              duration: 1400.ms,
              curve: Curves.easeInOut,
            ),
        image
            .animate()
            .scaleXY(
              begin: 0.3,
              end: 1.0,
              duration: 620.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 280.ms),
      ],
    );
  }
}

/// Small pill with the coin icon + "Reward: N coins" (or "+N coins" when
/// already earned). Subtle shimmer plays over the claimed state.
class _RewardChip extends StatelessWidget {
  final int giftInCoins;
  final bool claimed;

  const _RewardChip({required this.giftInCoins, required this.claimed});

  @override
  Widget build(BuildContext context) {
    final bg = claimed ? const Color(0xFFFFF7E5) : Colors.grey[100]!;
    final border = claimed
        ? Border.all(color: const Color(0xFFFFD699), width: 1.2)
        : null;
    final textColor =
        claimed ? const Color(0xFFB45309) : const Color(0xFF1D2939);
    final label = claimed
        ? 'trophy_earned_reward_chip'.tr(
            namedArgs: {'coins': giftInCoins.toString()},
          )
        : '${'Rewards'.tr()}: $giftInCoins ${'coin'.tr()}';

    final chip = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(17),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/cointroface.png',
            height: 24,
            width: 24,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    if (!claimed) return chip;
    return chip.animate().shimmer(
          delay: 650.ms,
          duration: 1400.ms,
          color: const Color(0xFFFDB022),
        );
  }
}

class _Palette {
  final Color primary;
  final Color primaryDark;
  final Color progress;
  final Color progressBg;
  final Color nameColor;

  const _Palette({
    required this.primary,
    required this.primaryDark,
    required this.progress,
    required this.progressBg,
    required this.nameColor,
  });
}
