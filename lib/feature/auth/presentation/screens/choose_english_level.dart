import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/auth/data/choosing_level_model.dart';
import 'package:vozhaomuz/feature/auth/presentation/screens/referral_source_page.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/selected_level_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/level_widget.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/user_level_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class ChooseEnglishLevel extends ConsumerStatefulWidget {
  const ChooseEnglishLevel({super.key});

  @override
  ConsumerState<ChooseEnglishLevel> createState() => _ChooseEnglishLevelState();
}

class _ChooseEnglishLevelState extends ConsumerState<ChooseEnglishLevel> {
  @override
  Widget build(BuildContext context) {
    List<ChoosingLevelModel> sourses = [
      ChoosingLevelModel(
        grade: 'level_beginner'.tr(),
        description: 'level_beginner_desc'.tr(),
      ),
      ChoosingLevelModel(
        grade: 'level_intermediate'.tr(),
        description: 'level_intermediate_desc'.tr(),
      ),
      ChoosingLevelModel(
        grade: 'level_advanced'.tr(),
        description: 'level_advanced_desc'.tr(),
      ),
    ];
    return Scaffold(
      backgroundColor: Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5FAFF),
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Icon(Icons.chevron_left_rounded, size: 50),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'choose_learning_level'.tr(),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
                Gap(10),
                ...sourses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final model = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: LevelWidget(model: model, index: index),
                  );
                }),
                Gap(6),
                Text(
                  'can_change_level_later'.tr(),
                  style: TextStyle(
                    color: Color(0xFF9AA4B2),
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: MyButton(
                width: double.infinity,
                height: 52,
                padding: EdgeInsets.zero,
                buttonColor: Colors.blue,
                backButtonColor: Color(0xff0e77b1),
                child: Text(
                  textAlign: TextAlign.center,
                  'next'.tr(),
                  style: AppTextStyles.whiteTextStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final selectedIndex = ref.read(selectedIndexProvider);
                  if (selectedIndex != null) {
                    final selectedLevel = sourses[selectedIndex];
                    ref.read(selectedLevelProvider.notifier).set(selectedLevel);
                    // Save user level (1-3) for category word counts
                    ref
                        .read(userLevelProvider.notifier)
                        .setLevel(selectedIndex + 1);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReferralSourcePage(),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('please_select_level'.tr())),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
