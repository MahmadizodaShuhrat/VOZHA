import 'package:country_flags/country_flags.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/language_button_child.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/shared/widgets/header_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // First-launch default is Tajik. easy_localization remembers the
      // last saved locale across restarts, which for some users has
      // lingered as `ru` from an earlier build — so during onboarding
      // (before onboardingCompleted) we actively force Tajik.
      final onboardingDone =
          StorageService.instance.isOnboardingCompleted();
      if (!onboardingDone && context.locale.languageCode != 'tg') {
        await context.setLocale(const Locale('tg'));
        await StorageService.instance.setInterfaceLanguage('tg');
        if (!mounted) return;
        ref.read(localeProvider.notifier).set(const Locale('tg'));
        setState(() {});
      } else {
        ref.read(localeProvider.notifier).set(context.locale);
      }
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
                  height: 64,
                  padding: EdgeInsets.zero,
                  buttonColor: choosedLanguage == 0
                      ? AppColors.buttonColor
                      : Colors.white,
                  backButtonColor: choosedLanguage == 0
                      ? const Color(0xff0e77b1)
                      : const Color(0xFFD0D5DD),
                  depth: 4,
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
                    title: 'Тоҷикӣ',
                  ),
                ),
                const Gap(10),
                MyButton(
                  height: 64,
                  padding: EdgeInsets.zero,
                  buttonColor: choosedLanguage == 1
                      ? AppColors.buttonColor
                      : Colors.white,
                  backButtonColor: choosedLanguage == 1
                      ? const Color(0xff0e77b1)
                      : const Color(0xFFD0D5DD),
                  depth: 4,
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
                    title: 'Русский',
                  ),
                ),
                SizedBox(height: 15),
              ],
            ),
            const Spacer(),
            MyButton(
              height: 52,
              padding: EdgeInsets.zero,
              backButtonColor: Color(0xff0e77b1),

              buttonColor: AppColors.buttonColor,
              width: double.infinity,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go('/auth/learn-language');
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
            const Gap(30),
          ],
        ),
      ),
    );
  }
}
