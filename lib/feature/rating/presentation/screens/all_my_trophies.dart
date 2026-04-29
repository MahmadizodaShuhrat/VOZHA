import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/rating/data/models/achievement_dto.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/achievements_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/trophies_widget.dart';

class AllMyTrophies extends ConsumerStatefulWidget {
  const AllMyTrophies({super.key});

  @override
  ConsumerState<AllMyTrophies> createState() => _AllMyTrophiesState();
}

class _AllMyTrophiesState extends ConsumerState<AllMyTrophies> {
  /// Responsive column count for the trophy grids. 3 on phones keeps
  /// tiles readable; tablets and unfolded foldables get 4–5 so trophies
  /// don't balloon to oversized cards on a 10 " screen.
  int _trophyColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 900) return 5;
    if (w >= 600) return 4;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    // Маълумотро дубора fetch мекунем ки ҳамеша нав бошад
    Future.microtask(() {
      ref.invalidate(achievementsProvider);
      ref.invalidate(profileRatingProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final achievementsAsync = ref.watch(achievementsProvider);
    final ratingAsync = ref.watch(profileRatingProvider);
    final accurateLearnedWords =
        ratingAsync.whenOrNull(data: (r) => r?.countLearnedWords) ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.chevron_left_rounded, size: 50),
        ),
        title: Text(
          'my_trophies'.tr(),
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
      ),
      body: achievementsAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title shimmer
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 180,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Trophy cards grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // 3 columns on phones (<600dp), 4 on tablets, 5 on very
                // wide displays so trophy tiles don't look oversized on
                // an iPad or foldable unfolded.
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _trophyColumns(context),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.7,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon circle
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        Container(
                          width: 60,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Progress bar
                        Container(
                          width: double.infinity,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Text(
            'error_loading'.tr(),
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ),
        data: (achievements) {
          // Split by type like Unity: "words" and "streak"
          // Override word achievements progress with accurate count from profile-rating
          // Sort each list by conditionValue ascending — backend returns
          // in Go map iteration order (undefined), so we sort here for a
          // consistent 50 → 100 → 200 … layout.
          final wordsList = achievements
              .where((a) => a.type == 'words')
              .map(
                (a) => AchievementDto(
                  code: a.code,
                  name: a.name,
                  type: a.type,
                  claimed: accurateLearnedWords >= a.conditionValue,
                  progress: accurateLearnedWords,
                  conditionValue: a.conditionValue,
                  iconUrl: a.iconUrl,
                  coinsReward: a.coinsReward,
                ),
              )
              .toList()
            ..sort((a, b) => a.conditionValue.compareTo(b.conditionValue));
          final streakList = achievements
              .where((a) => a.type == 'streak')
              .toList()
            ..sort((a, b) => a.conditionValue.compareTo(b.conditionValue));

          return Container(
            color: Colors.white,
            padding: EdgeInsets.all(15),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wordsList.isNotEmpty) ...[
                    Text(
                      'Achievements_for_memorizing_words'.tr(),
                      style: AppTextStyles.bigTextStyle.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Gap(10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: wordsList.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _trophyColumns(context),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.74,
                      ),
                      itemBuilder: (context, index) =>
                          TrophiesWidget(achievement: wordsList[index]),
                    ),
                  ],
                  if (streakList.isNotEmpty) ...[
                    Gap(20),
                    Text(
                      'Daily_learning_achievement'.tr(),
                      style: AppTextStyles.bigTextStyle.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Gap(10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: streakList.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _trophyColumns(context),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.74,
                      ),
                      itemBuilder: (context, index) =>
                          TrophiesWidget(achievement: streakList[index]),
                    ),
                  ],
                  if (wordsList.isEmpty && streakList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'no_content_available'.tr(),
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
