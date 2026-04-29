import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/feature/profile/data/model/profile_info_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/category_setting.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/animation_button.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/match_words.dart';
import 'package:vozhaomuz/feature/my_words/presentation/screens/repeat_word_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';

/// Агар калимаҳои такрор аз ин ҳад зиёд бошанд, тугмаи "Омӯзиш" (хурд)
/// КОР НАМЕКУНАД — корбар бояд аввал такрор кунад. Banner-и зард барои
/// 3с пайдо мешавад то ин маҳдудиятро шарҳ диҳад. Зери 10 — омӯзиш мисли
/// қаблӣ дастрас.
const int _kRepeatBlockThreshold = 10;

/// Home page action buttons section (word review, learn words, configure categories).
/// Extracted from home_page.dart for better maintainability.
class HomeActionButtons extends ConsumerStatefulWidget {
  final AsyncValue<ProfileInfoDto?> userAsync;

  const HomeActionButtons({super.key, required this.userAsync});

  @override
  ConsumerState<HomeActionButtons> createState() =>
      _HomeActionButtonsState();
}

class _HomeActionButtonsState extends ConsumerState<HomeActionButtons> {
  bool _showBanner = false;
  Timer? _bannerTimer;

  void _flashBanner() {
    HapticFeedback.lightImpact();
    setState(() => _showBanner = true);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repeatState = ref.watch(repeatStateProvider);
    final isRepeatMode = repeatState.needsRepeat;
    final repeatCount = repeatState.repeatCount;
    final isBlocked = repeatCount >= _kRepeatBlockThreshold;

    return Column(
      children: [
        // Banner-и огоҳӣ — танҳо вақте корбар "Омӯзиш"-ро дар ҳолати
        // блокшуда мезанад пайдо мешавад. AnimatedSwitcher баъди 3с
        // онро бо fade-out бартараф мекунад.
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1.0,
                child: child,
              ),
            ),
            child: _showBanner
                ? Padding(
                    key: const ValueKey('repeat-banner'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RepeatBlockedBanner(repeatCount: repeatCount),
                  )
                : const SizedBox.shrink(key: ValueKey('no-banner')),
          ),
        ),
        // Word review button — wait for repeat state before rendering
        // so we don't flash "Word_review" then switch to "learn_word" on slow nets
        if (!repeatState.isReady)
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: (MediaQuery.of(context).size.height * 0.06)
                  .clamp(48.0, 64.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: Colors.white,
              ),
            ),
          )
        else
          GestureDetector(
            // Secondary action — opposite of the big button.
            //   - When the big button is in Repeat mode (isRepeatMode=true),
            //     this offers Learn → opens category dialog / settings,
            //     UNLESS repeat count >= threshold, in which case the tap
            //     is blocked with the yellow banner above.
            //   - When the big button is in Learn mode (isRepeatMode=false),
            //     this offers Word_review → opens the repeat overview page
            //     so the user can see what's pending even if they're below
            //     the auto-Repeat threshold.
            onTap: () {
              if (isRepeatMode) {
                if (isBlocked) {
                  _flashBanner();
                  return;
                }
                HapticFeedback.lightImpact();
                _openLearnFlow(context, ref);
              } else {
                HapticFeedback.lightImpact();
                _openRepeatOverview(context, ref);
              }
            },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: (MediaQuery.of(context).size.height * 0.06)
                  .clamp(48.0, 64.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: const Color(0xFFD7E7F8),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFB8D3F1), width: 4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isRepeatMode
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF5E83A9),
                            BlendMode.srcATop,
                          ),
                          child: Image.asset(
                            "assets/images/Lamp.png",
                            width: 24,
                            color: const Color(0xFF5E83A9),
                          ),
                        )
                      : SvgPicture.asset("assets/images/Vector (1).svg"),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isRepeatMode
                            ? "learn_word".tr()
                            : "Word_review".tr(),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF5E83A9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        // Learn word button (animated)
        HomeBattonsWidget(
          wordName: "learn_word".tr(),
          image: "assets/images/Lamp.png",
          buttonColor: const Color(0xFF2E90FA),
          borderColor: const Color(0xFF1570EF),
        ),
        const SizedBox(height: 10),
        // Configure categories button
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: (MediaQuery.of(context).size.height * 0.06)
              .clamp(48.0, 64.0),
          child: ListView.builder(
            itemCount: 1,
            itemBuilder: (context, index) {
              return widget.userAsync.when(
                data: (user) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategorySetting(user: user),
                          ),
                        ).then((_) {
                          if (context.mounted) {
                            ref.invalidate(categoriesFlutterProvider);
                          }
                        });
                      }
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: (MediaQuery.of(context).size.height * 0.06)
                  .clamp(48.0, 64.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        color: const Color(0xFFD7E7F8),
                        border: const Border(
                          bottom: BorderSide(
                            color: Color(0xFFB8D3F1),
                            width: 4,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset("assets/images/Vector.svg"),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "Configure_categories".tr(),
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Color(0xFF5E83A9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(child: Text("error_loading_user".tr())),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Opens the categorized "words to repeat" overview page if there's anything
/// to show; otherwise tells the user nothing is pending. Called from the
/// secondary "Word_review" button when the big button is in Learn mode (i.e.
/// the user is below the auto-Repeat threshold but may still have a few
/// words queued up).
///
/// If the user has zero accessible repeat words but DOES have words locked
/// behind a premium category they no longer have access to, the SnackBar
/// surfaces that as a soft upsell instead of a flat "nothing to do" — those
/// users would otherwise feel the feature is just broken.
void _openRepeatOverview(BuildContext context, WidgetRef ref) {
  final repeatState = ref.read(repeatStateProvider);
  if (repeatState.repeatCount > 0) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RepeadWordPage()),
    );
    return;
  }
  // Zero accessible — but check if premium-lock is the reason.
  final messenger = ScaffoldMessenger.of(context);
  if (repeatState.lockedRepeatCount > 0) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "repeat_locked_by_premium".tr(
            args: ['${repeatState.lockedRepeatCount}'],
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text("no_words_to_repeat_yet".tr()),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Opens the new-words learning flow. Mirrors HomeBattonsWidget's Learn
/// branch (animation_button.dart): if no valid category is selected, take
/// the user to settings; otherwise show the category dialog. Called from
/// the secondary "learn_word" button when the big button is in Repeat
/// mode (and only when repeat count is below the hard-block threshold —
/// гейтро caller аз рӯи `_kRepeatBlockThreshold` дар бар мегирад).
void _openLearnFlow(BuildContext context, WidgetRef ref) {
  final selectedIds = ref.read(progressProvider).selectedIds;
  final allCategories = ref.read(categoriesFlutterProvider).value ?? [];
  final validCategoryIds = allCategories.map((c) => c.id).toSet();
  final hasValidSelection =
      selectedIds.any((id) => validCategoryIds.contains(id));

  if (!hasValidSelection) {
    final user = ref.read(getProfileInfoProvider).value;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CategorySetting(user: user)),
      ).then((_) {
        if (context.mounted) {
          ref.invalidate(categoriesFlutterProvider);
        }
      });
    }
    return;
  }
  showCategoryDialog(context);
}

/// Banner-и зард дар боли тугмаҳо вақте корбар "Омӯзиш"-ро ҳангоми
/// ҳадди такрор зер мекунад. 3 сония пайдо мешавад, баъд худкорона
/// нопадид мешавад.
class _RepeatBlockedBanner extends StatelessWidget {
  final int repeatCount;

  const _RepeatBlockedBanner({required this.repeatCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4C2), Color(0xFFFCD60D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAB308), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAB308).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            child: const Center(
              child: Icon(
                Icons.replay_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'repeat_blocked_banner'.tr(
                namedArgs: {'count': '$repeatCount'},
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A4D00),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
