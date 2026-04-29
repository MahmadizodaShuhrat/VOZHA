import 'package:country_flags/country_flags.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/language_button_child.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/screens/navigation_bar.dart';
import 'package:vozhaomuz/shared/widgets/header_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class ChangeLearnLanguage extends StatefulWidget {
  const ChangeLearnLanguage({super.key});

  @override
  State<ChangeLearnLanguage> createState() => _ChangeLearnLanguageState();
}

class _ChangeLearnLanguageState extends State<ChangeLearnLanguage> {
  bool _isEnglishSelected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
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
              height: 52,
              padding: EdgeInsets.zero,
              buttonColor: _isEnglishSelected
                  ? AppColors.buttonColor
                  : Colors.white,
              backButtonColor: _isEnglishSelected
                  ? const Color.fromARGB(255, 28, 111, 180)
                  : const Color.fromARGB(179, 189, 187, 187),
              depth: 3,
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isEnglishSelected = true;
                });
              },
              child: LanguageButtonChild(
                title: 'english',
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
                isActive: _isEnglishSelected,
              ),
            ),
            Spacer(),
            if (_isEnglishSelected)
              MyButton(
                height: 52,
                padding: EdgeInsets.zero,
                buttonColor: AppColors.buttonColor,
                backButtonColor: AppColors.backButtonColor,
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const NavigationPage(initialIndex: 0)),
                      (route) => false,
                    );
                  });
                },
                child: Center(
                  child: Text(
                    'next'.tr(),
                    style: AppTextStyles.whiteTextStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Gap(30),
          ],
        ),
      ),
    );
  }
}
