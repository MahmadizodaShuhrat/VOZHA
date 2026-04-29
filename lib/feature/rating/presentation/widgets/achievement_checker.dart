import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/rating/data/models/achievement_dto.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/achievements_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/achievement_congratulation_dialog.dart';

/// A widget that wraps the app and listens for new earned achievements.
/// When an achievement's progress >= conditionValue and the user
/// has NOT yet acknowledged it (pressed Accept), it shows a congratulatory popup.
///
/// Place this widget high in the widget tree (e.g. wrapping MaterialApp's home/router).
class AchievementChecker extends ConsumerStatefulWidget {
  final Widget child;

  const AchievementChecker({super.key, required this.child});

  @override
  ConsumerState<AchievementChecker> createState() => _AchievementCheckerState();
}

class _AchievementCheckerState extends ConsumerState<AchievementChecker> {
  bool _isShowingPopup = false;

  @override
  Widget build(BuildContext context) {
    // Listen to achievements changes
    ref.listen<AsyncValue<List<AchievementDto>>>(achievementsProvider, (
      previous,
      next,
    ) {
      next.whenData((achievements) {
        _checkForNewAchievements(achievements);
      });
    });

    return widget.child;
  }

  void _checkForNewAchievements(List<AchievementDto> achievements) {
    if (_isShowingPopup) return;

    final acknowledged = StorageService.instance.getAcknowledgedAchievements();

    // Get accurate learned words from profile-rating
    final ratingState = ref.read(profileRatingProvider);
    final accurateLearnedWords =
        ratingState.whenOrNull(data: (r) => r?.countLearnedWords) ?? 0;

    // Find achievements that are earned but not yet acknowledged
    for (final achievement in achievements) {
      // Determine effective progress based on type
      final effectiveProgress = achievement.type == 'words'
          ? accurateLearnedWords
          : achievement.progress;

      // Check if earned (progress >= conditionValue) AND not yet acknowledged
      if (effectiveProgress >= achievement.conditionValue &&
          !acknowledged.contains(achievement.code)) {
        _showCongratulation(achievement);
        return; // Show one at a time
      }
    }
  }

  void _showCongratulation(AchievementDto achievement) {
    if (!mounted || _isShowingPopup) return;

    _isShowingPopup = true;
    debugPrint(
      '🎉 New achievement earned: ${achievement.name} (${achievement.code})',
    );

    showAchievementCongratulation(
      context: context,
      achievement: achievement,
      onAccept: () async {
        // Mark as acknowledged so popup won't show again
        await StorageService.instance.addAcknowledgedAchievement(
          achievement.code,
        );
        debugPrint('✅ Achievement acknowledged: ${achievement.code}');

        _isShowingPopup = false;

        // Check if there are more unacknowledged achievements
        if (mounted) {
          final currentState = ref.read(achievementsProvider);
          currentState.whenData((achievements) {
            // Small delay before showing next popup
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _checkForNewAchievements(achievements);
              }
            });
          });
        }
      },
    );
  }
}
