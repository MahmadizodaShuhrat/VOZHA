import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/services/notification_service.dart';
import 'package:vozhaomuz/shared/widgets/header_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _navigating = false;

  /// Push-notification permission is requested once here, on the landing
  /// screen, so the user sees the OS dialog upfront. Microphone
  /// permission is intentionally NOT bootstrapped here — too many users
  /// click "Deny" without reading and then can't use the speech games.
  /// It's now requested lazily inside the speech game (with our own
  /// explainer dialog first) so the ask has clear context.
  static const _permissionsBootstrappedKey = 'permissions_bootstrapped_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestInitialPermissions());
  }

  Future<void> _requestInitialPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_permissionsBootstrappedKey) == true) return;

      await NotificationService.instance.requestPermission();
      if (!mounted) return;

      await prefs.setBool(_permissionsBootstrappedKey, true);
    } catch (_) {
      // Deliberately swallow: permissions being denied here must not
      // block the user from seeing the landing page.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scale the large decorative gaps with screen height so the lower
    // button ("I already have an account") stays on-screen on small
    // devices. Previously fixed `Gap(90)` + `Gap(50)` + 180pt avatar
    // overflowed the 550-pt Android emulator by 76 px.
    final screenH = MediaQuery.of(context).size.height;
    final topGap = (screenH * 0.11).clamp(28.0, 90.0);
    final avatarRadius = (screenH * 0.11).clamp(64.0, 90.0);
    final bottomGap = (screenH * 0.06).clamp(20.0, 50.0);
    final midGap = (screenH * 0.03).clamp(14.0, 26.0);

    return Scaffold(
      backgroundColor: AppColors.buttonColor,

      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/vozhaomuz_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(15.0),
        // Scroll fallback so even the tightest combination of font
        // scale + split-screen can never hide a button behind the nav
        // bar. On tall devices the content still expands to fill via
        // the ConstrainedBox below.
        child: SafeArea(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Gap(10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () =>
                                context.go('/auth/learn-language'),
                            child: Icon(
                              Icons.arrow_back_ios,
                              color: AppColors.whiteText,
                            ),
                          ),
                        ),
                        Gap(topGap),
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: AppColors.whiteText,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Image.asset(
                              'assets/images/logo_vozha.png',
                              width:
                                  MediaQuery.of(context).size.width * 0.5,
                              height: avatarRadius * 1.33,
                            ),
                          ),
                        ),
                        HeaderWidget(
                          title: 'VozhaOmuz',
                          alignment: Alignment.center,
                          textStyle: AppTextStyles.bigTextButton.copyWith(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.7,
                          child: Text(
                            'let\'s_learn_english_together'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.whiteTextStyle.copyWith(
                              fontSize: 25,
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                        ),
                        const Spacer(),
                        MyButton(
                          height: 52,
                          padding: EdgeInsets.zero,
                          buttonColor: AppColors.goldButtonColor,
                          backButtonColor: AppColors.goldBackButtonColor,
                          onPressed: () {
                            if (_navigating) return;
                            _navigating = true;
                            HapticFeedback.lightImpact();
                            context.go('/auth/about');
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () => _navigating = false,
                            );
                          },
                          child: Center(
                            child: Text(
                              'start'.tr(),
                              style: AppTextStyles.whiteTextStyle.copyWith(
                                fontWeight: FontWeight.w200,
                                fontSize: 17,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Gap(midGap),
                        MyButton(
                          height: 52,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            if (_navigating) return;
                            _navigating = true;
                            HapticFeedback.lightImpact();
                            context.go('/auth/signin');
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () => _navigating = false,
                            );
                          },
                          child: Center(
                            child: Text(
                              'i_also_have_an_account'.tr(),
                              style: AppTextStyles.whiteTextStyle.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Gap(bottomGap),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
