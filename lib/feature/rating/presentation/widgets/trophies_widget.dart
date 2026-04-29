import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/rating/data/models/achievement_dto.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/show_dialog.dart';

class TrophiesWidget extends StatelessWidget {
  final AchievementDto achievement;
  const TrophiesWidget({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    String formatTitle(String title) {
      if (title.length > 15) {
        return title.replaceFirst(' ', '\n');
      }
      return title;
    }

    final progress = achievement.conditionValue > 0
        ? (achievement.progress / achievement.conditionValue).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            showTrophyDialog(
              context: context,
              countOfWords: achievement.conditionValue,
              countOfLearnedWords: achievement.progress,
              gradeOfTrophy: achievement.name,
              giftInCoins: achievement.coinsReward,
              // Show colored icon when earned, grey otherwise — matches
              // the card thumbnail on the trophies screen.
              iconUrl: achievement.claimed
                  ? achievement.iconUrl
                  : achievement.displayIconUrl,
              claimed: achievement.claimed,
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 5),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 4),
              ),
              color: const Color(0xFFF0F5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 53,
                  height: 53,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: achievement.displayIconUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.emoji_events,
                        size: 24,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Gap(achievement.name.length > 15 ? 13 : 26),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    formatTitle(achievement.name),
                    style: AppTextStyles.whiteTextStyle.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w200,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${achievement.progress > achievement.conditionValue ? achievement.conditionValue : achievement.progress} ',
                style: TextStyle(color: Colors.blue, fontSize: 10),
              ),
              Text(
                '/${achievement.conditionValue}',
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          // Green when the achievement is fully earned, blue while progressing
          // — makes the "done" state visually obvious at a glance.
          color: achievement.claimed
              ? const Color(0xFF12B76A)
              : Colors.blue,
          minHeight: 8,
          borderRadius: BorderRadius.circular(10),
          stopIndicatorColor: Colors.red,
          stopIndicatorRadius: 6,
          trackGap: 2,
        ),
      ],
    );
  }
}
