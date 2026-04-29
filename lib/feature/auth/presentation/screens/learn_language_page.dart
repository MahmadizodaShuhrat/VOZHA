import 'package:country_flags/country_flags.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/language_button_child.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/shared/widgets/header_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class LearnLanguagePage extends StatefulWidget {
  const LearnLanguagePage({super.key});

  @override
  State<LearnLanguagePage> createState() => _LearnLanguagePageState();
}

class _LearnLanguagePageState extends State<LearnLanguagePage> {
  // Start unselected so the page feels like a real choice instead of a
  // pre-filled step. Next appears only after the user actively taps English.
  bool _englishSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => context.go('/auth/language'),
          child: Icon(Icons.arrow_back_ios),
        ),
        backgroundColor: AppColors.screenColors,
      ),
      backgroundColor: AppColors.screenColors,
      body: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderWidget(
              title: 'choose_learning_language'.tr(),
              alignment: Alignment.centerLeft,
              textStyle: AppTextStyles.bigTextStyle,
            ),
            Gap(15),
            MyButton(
              height: 64,
              padding: EdgeInsets.zero,
              buttonColor:
                  _englishSelected ? AppColors.buttonColor : Colors.white,
              backButtonColor: _englishSelected
                  ? const Color(0xff0e77b1)
                  : const Color(0xFFD0D5DD),
              depth: 4,
              width: double.infinity,
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _englishSelected = true);
              },
              child: LanguageButtonChild(
                title: 'English'.tr(),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: SizedBox(
                      width: 40,
                      height: 25,
                      child: CountryFlag.fromCountryCode('gb'),
                    ),
                  ),
                ),
                isActive: _englishSelected,
              ),
            ),
            Spacer(),
            // Next button is revealed only after a language is picked, so
            // the user can't skip through with nothing selected.
            if (_englishSelected) ...[
              MyButton(
                height: 52,
                padding: EdgeInsets.zero,
                buttonColor: AppColors.buttonColor,
                backButtonColor: const Color(0xff0e77b1),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await StorageService.instance.setOnboardingCompleted(true);
                  if (context.mounted) context.go('/auth/start');
                },
                child: Center(
                  child: Text(
                    'next'.tr(),
                    style: AppTextStyles.whiteTextStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Gap(30),
            ],
          ],
        ),
      ),
    );
  }
}
