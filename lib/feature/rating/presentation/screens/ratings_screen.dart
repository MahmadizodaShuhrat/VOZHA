import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/achievements_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_3_users_day_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/my_progress.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/my_trophies.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/statistic.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/top_vozhaomuz.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/user_info.dart';

class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  Future<void> _refreshData() async {
    // Profile: дубора fetch мекунем (invalidate null мекунад, чунки build() null бармегардонад)
    ref.read(getProfileInfoProvider.notifier).getProfile();

    // Рейтинг ва дигар провайдерҳоро invalidate мекунем (автоматикӣ дубора fetch мекунанд)
    ref.invalidate(achievementsProvider);
    ref.invalidate(profileRatingProvider);
    ref.invalidate(top3UsersDayProvider);

    // Интизор мешавем то маълумот боргирӣ шавад
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 30),
          child: Column(
            children: [
              // Statistiks
              Statistic(),
              // User Information
              UserInfo(),
              Gap(15),
              // My Progress
              MyProgress(),
              Gap(15),
              // My Trophies
              MyTrophies(),
              Gap(15),
              //Top 30 - Vozhaomuz
              TopVozhaomuz(),
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
