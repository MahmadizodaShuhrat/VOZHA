import 'package:country_flags/country_flags.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/language_button_child.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/change_learn_language.dart';
import 'package:vozhaomuz/shared/widgets/header_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class ChangeLanguage extends ConsumerStatefulWidget {
  const ChangeLanguage({super.key});

  @override
  ConsumerState<ChangeLanguage> createState() => _ChangeLanguageState();
}

class _ChangeLanguageState extends ConsumerState<ChangeLanguage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = context.locale;
      ref.read(localeProvider.notifier).set(initial);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final choosedLanguage = currentLocale.languageCode == 'tg' ? 0 : 1;

    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.screenColors),
      backgroundColor: AppColors.screenColors,
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderWidget(
              title: 'choose_your_own_language'.tr(),
              alignment: Alignment.centerLeft,
              textStyle: AppTextStyles.bigTextStyle,
            ),
            Column(
              children: [
                MyButton(
                  height: 52,
                  padding: EdgeInsets.zero,
                  backButtonColor: choosedLanguage == 0
                      ? const Color.fromARGB(255, 42, 133, 219)
                      : const Color.fromARGB(179, 189, 187, 187),
                  buttonColor: choosedLanguage == 0
                      ? AppColors.buttonColor
                      : null,
                  depth: 3,
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await context.setLocale(const Locale('tg'));
                    await StorageService.instance.setInterfaceLanguage('tg');
                    ref.read(localeProvider.notifier).set(const Locale('tg'));
                    setState(() {});
                  },
                  width: double.infinity,
                  child: LanguageButtonChild(
                    isActive: choosedLanguage == 0,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          width: 40,
                          height: 25,
                          child: CountryFlag.fromCountryCode('tj'),
                        ),
                      ),
                    ),
                    title: 'tajik'.tr(),
                  ),
                ),
                const Gap(10),
                MyButton(
                  height: 52,
                  padding: EdgeInsets.zero,
                  backButtonColor: choosedLanguage == 1
                      ? const Color.fromARGB(255, 42, 133, 219)
                      : const Color.fromARGB(179, 189, 187, 187),
                  buttonColor: choosedLanguage == 1
                      ? AppColors.buttonColor
                      : null,
                  depth: 3,
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await context.setLocale(const Locale('ru'));
                    await StorageService.instance.setInterfaceLanguage('ru');
                    ref.read(localeProvider.notifier).set(const Locale('ru'));
                    setState(() {});
                  },
                  width: double.infinity,
                  child: LanguageButtonChild(
                    isActive: choosedLanguage == 1,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          width: 40,
                          height: 25,
                          child: CountryFlag.fromCountryCode('ru'),
                        ),
                      ),
                    ),
                    title: 'russian'.tr(),
                  ),
                ),
              ],
            ),
            const Spacer(),
            MyButton(
              height: 52,
              padding: EdgeInsets.zero,
              backButtonColor: AppColors.backButtonColor,
              buttonColor: AppColors.buttonColor,
              width: double.infinity,
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangeLearnLanguage(),
                  ),
                );
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
            const Gap(30),
          ],
        ),
      ),
    );
  }
}
