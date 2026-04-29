import 'package:country_flags/country_flags.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/rating/data/models/progress_model.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/progress_widget.dart';

class MyProgress extends ConsumerWidget {
  const MyProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(profileRatingProvider);

    // Real stats from backend (api/v1/dict/profile-rating)
    // Same as Unity: UIStatisticsPage.cs lines 228-230
    final earnedMoney =
        ratingAsync.whenOrNull(data: (r) => r?.earnedMoney) ?? 0;
    final winsCount = ratingAsync.whenOrNull(data: (r) => r?.winsCount) ?? 0;
    final learnedWords =
        ratingAsync.whenOrNull(data: (r) => r?.countLearnedWords) ?? 0;

    final List<ProgressModel> progresses = [
      ProgressModel(
        image: Image.asset('assets/images/coin.png', width: 20, height: 20),
        count: '$earnedMoney',
        titleKey: 'coins_earned',
        backgroundColor: Color.fromARGB(255, 255, 243, 216),
      ),
      ProgressModel(
        image: Image.asset(
          'assets/images/malenkiy_vozha.png',
          width: 25,
          height: 25,
        ),
        iconColor: Colors.teal,
        count: '$winsCount',
        titleKey: 'wins_in_battles',
        backgroundColor: Color.fromARGB(255, 230, 255, 247),
      ),
      ProgressModel(
        image: Image.asset('assets/images/note-2.png', height: 20, width: 20),
        iconColor: Colors.blue,
        count: '$learnedWords',
        titleKey: 'words_learned',
        backgroundColor: Color.fromARGB(255, 230, 244, 255),
      ),
    ];

    if (ratingAsync.isLoading) {
      return Container(
        padding: const EdgeInsets.all(25),
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 4),
          ),
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 70,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  3,
                  (_) => Container(
                    width: MediaQuery.of(context).size.width * 0.24,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(25),
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 4),
        ),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'my_progress'.tr(),
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          Gap(1),
          Text(
            'learning_languages'.tr(),
            style: AppTextStyles.whiteTextStyle.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Gap(1),
          Container(
            width: MediaQuery.of(context).size.width * 0.2,
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 214, 236, 255),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    width: 18,
                    height: 10,
                    child: CountryFlag.fromCountryCode('gb'),
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  'English',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Gap(10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: progresses
                .map((item) => ProgressWidget(item: item))
                .toList(),
          ),
        ],
      ),
    );
  }
}
