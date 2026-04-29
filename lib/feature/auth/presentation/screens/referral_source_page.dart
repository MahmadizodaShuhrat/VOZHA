import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/auth/data/referral_sourse_model.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/referral_sourse_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class ReferralSourcePage extends ConsumerStatefulWidget {
  const ReferralSourcePage({super.key});

  @override
  ConsumerState<ReferralSourcePage> createState() => _ReferralSourcePageState();
}

class _ReferralSourcePageState extends ConsumerState<ReferralSourcePage> {
  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    List<ReferralSourseModel> sourses = [
      ReferralSourseModel(
        name: 'referral_instagram'.tr(),
        image: 'assets/images/UIStepsSignUp/instagram.png',
        isChecked: false,
      ),
      ReferralSourseModel(
        name: 'referral_facebook'.tr(),
        image: 'assets/images/UIStepsSignUp/facebook.png',
        isChecked: false,
      ),
      ReferralSourseModel(
        name: 'referral_friend'.tr(),
        image: 'assets/images/UIStepsSignUp/user.png',
        isChecked: false,
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
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'where_did_you_hear'.tr(),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
                ...sourses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final model = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ReferralSourseWidget(model: model, index: index),
                  );
                }),
                if (selectedIndex == 2) ...[
                  Gap(40),
                  Container(
                    color: Colors.blue.shade200,
                    width: double.infinity,
                    height: 2,
                  ),
                  Gap(40),
                  Text(
                    'referral_code'.tr(),
                    style: AppTextStyles.whiteTextStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  Gap(10),
                  TextFormField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelText: 'enter_referral_code'.tr(),
                      labelStyle: TextStyle(
                        color: Color(0xFF9AA4B2),
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Gap(6),
                  Text(
                    'referral_code_hint'.tr(),
                    style: TextStyle(
                      color: Color(0xFF9AA4B2),
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
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
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.go('/auth/notifications');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
