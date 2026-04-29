import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/feature/rating/data/models/achievement_dto.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Congratulatory popup shown when user earns a new achievement.
/// Mirrors Unity's UIClaimedAchievement popup (UIResults.cs:356-381).
///
/// [onAccept] is called when user presses "Accept" button —
/// we use this to mark the achievement as acknowledged locally
/// so it won't be shown again.
void showAchievementCongratulation({
  required BuildContext context,
  required AchievementDto achievement,
  required VoidCallback onAccept,
}) {
  showDialog(
    context: context,
    barrierDismissible: false, // User MUST press Accept
    builder: (context) {
      return Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🎉 Congratulations header
                Text(
                  'congratulations'.tr(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
                Gap(8),
                Text(
                  'new_achievement'.tr(),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Gap(20),

                // Achievement icon — responsive size so it doesn't crowd
                // the iPhone SE dialog and doesn't look tiny on tablets.
                Container(
                  width: (MediaQuery.of(context).size.width * 0.25)
                      .clamp(88.0, 140.0),
                  height: (MediaQuery.of(context).size.width * 0.25)
                      .clamp(88.0, 140.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl:
                          achievement.iconUrl, // Bright version (not 0.png)
                      // Fill the parent Container (which is already sized
                      // responsively), instead of a fixed 100x100 that
                      // doesn't match the outer widget on small/tablet.
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.emoji_events,
                        size: 50,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
                Gap(16),

                // Achievement name
                Text(
                  '«${achievement.name}»',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                Gap(12),

                // Coins reward badge
                if (achievement.coinsReward > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/coin.png',
                          width: 20,
                          height: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '+${achievement.coinsReward}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                Gap(12),

                // Progress (completed!)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${achievement.conditionValue}',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' / ${achievement.conditionValue}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Gap(8),

                // Full progress bar
                LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: Colors.grey[300],
                  color: Colors.green,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),
                Gap(24),

                // Accept button
                MyButton(
                  height: 50,
                  width: double.infinity,
                  buttonColor: Colors.blue,
                  backButtonColor: Colors.blueAccent,
                  child: Text(
                    'accept'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onAccept();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
