import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/feature/rating/data/models/achievement_dto.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/achievements_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/all_my_trophies.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/trophies_widget.dart';

class MyTrophies extends ConsumerWidget {
  const MyTrophies({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);
    final ratingAsync = ref.watch(profileRatingProvider);

    // Wait for profileRating data before using its value
    final accurateLearnedWords =
        ratingAsync.whenOrNull(data: (r) => r?.countLearnedWords) ?? 0;

    // If profileRating is still loading, show loading state for trophies too
    final isRatingLoading = ratingAsync is AsyncLoading;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 4),
        ),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'my_trophies'.tr(),
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AllMyTrophies()),
                  );
                },
                child: Text(
                  'all'.tr(),
                  style: TextStyle(
                    color: Colors.lightBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 11),
          // Show loading if either provider is still loading
          if (isRatingLoading || achievementsAsync is AsyncLoading)
            _shimmerRow()
          else
            achievementsAsync.when(
              data: (achievements) {
                // Unity: filter by type == "words" and take first 3
                final wordAchievements = achievements
                    .where((a) => a.type == 'words')
                    .take(3)
                    .toList();

                // First time the rating screen opens, the achievements list
                // can briefly be empty while the backend response is still
                // in flight or the user has no progress yet. Showing a
                // localized "Маълумот нест" notice in that window looked
                // like a hard failure — keep the shimmer rail visible
                // instead so the UI feels like "still loading" and then
                // smoothly reveals the trophy cards once data lands.
                if (wordAchievements.isEmpty) {
                  return _shimmerRow();
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: wordAchievements.map((achievement) {
                    // Override progress with accurate count from profile-rating
                    final correctedAchievement = AchievementDto(
                      code: achievement.code,
                      name: achievement.name,
                      type: achievement.type,
                      claimed: accurateLearnedWords >= achievement.conditionValue,
                      progress: accurateLearnedWords,
                      conditionValue: achievement.conditionValue,
                      iconUrl: achievement.iconUrl,
                      coinsReward: achievement.coinsReward,
                    );
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: TrophiesWidget(achievement: correctedAchievement),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: _shimmerRow,
              error: (e, st) {
                debugPrint('📢 MyTrophies ERROR: $e');
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      '${'error'.tr()}: $e',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Three-card shimmer placeholder used as both the explicit loading state
  /// and the "data arrived but empty" fallback. Keeping them unified makes
  /// the first-time rating-screen entry smooth — no flash of "no data" text.
  Widget _shimmerRow() {
    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          3,
          (_) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
