import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/auth/data/choosing_level_model.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/level_widget.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/selected_level_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/user_level_provider.dart';

class ChangeLevelEnglish extends ConsumerStatefulWidget {
  const ChangeLevelEnglish({super.key});

  @override
  ConsumerState<ChangeLevelEnglish> createState() => _ChangeLevelEnglishState();
}

class _ChangeLevelEnglishState extends ConsumerState<ChangeLevelEnglish> {
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
                  'choose_learning_language'.tr(),
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
                height: 45,
                padding: EdgeInsets.zero,
                buttonColor: Colors.blue,
                backButtonColor: Colors.blueGrey,
                child: Text(
                  textAlign: TextAlign.center,
                  'next'.tr(),
                  style: AppTextStyles.bigTextButton,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final selectedIndex = ref.read(selectedIndexProvider);
                  if (selectedIndex != null) {
                    final selectedLevel = sourses[selectedIndex];
                    ref.read(selectedLevelProvider.notifier).set(selectedLevel);
                    // Синхронизатсия бо categoryProvider: сатҳро (1-3) нигоҳ дор
                    ref
                        .read(userLevelProvider.notifier)
                        .setLevel(selectedIndex + 1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'level_changed'.tr(args: [selectedLevel.grade]),
                        ),
                      ),
                    );
                    Navigator.pop(context);
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
