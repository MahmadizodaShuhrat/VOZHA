import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/auth_notifier_provider.dart';
import 'package:vozhaomuz/feature/auth/state/auth_state.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/shared/widgets/header_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class SignUpPage extends HookConsumerWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      // Use freezed when() for pattern matching
      next.when(
        initial: () {},
        loading: () {},
        authenticated: (user) {
          // Existing user logged in → go directly to home
          context.go('/home');
        },
        needsSignUp: (data, provider) {
          context.go('/auth/referral');
        },
        error: (message) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${'error'.tr()}: $message')));
        },
      );
    });

    return Scaffold(
      backgroundColor: AppColors.buttonColor,
      body: Stack(
        children: [
          // ── Main content ──
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/vozhaomuz_background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  const Gap(15),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.go('/auth/about'),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.whiteText,
                      ),
                    ),
                  ),
                  const Gap(115),
                  CircleAvatar(
                    radius: 100,
                    backgroundColor: Color(0xff84CAFF),
                    child: Image.asset(
                      'assets/images/logo_vozha.png',
                      width: 150,
                      height: 130,
                    ),
                  ),
                  Gap(80),
                  HeaderWidget(
                    title: 'register'.tr(),
                    alignment: Alignment.center,
                    textStyle: AppTextStyles.bigTextStyle.copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Gap(40),
                  MyButton(
                    height: 48,
                    padding: EdgeInsets.zero,
                    depth: 6,
                    buttonColor: Colors.white,
                    backButtonColor: const Color.fromARGB(255, 226, 226, 226),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.go('/auth/signin', extra: true);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/whatsapp_logo.svg',
                          width: 35,
                          height: 33,
                        ),
                        const Gap(10),
                        Flexible(
                          child: Text(
                            'sign_up_with_phone'.tr(),
                            style: AppTextStyles.bigTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(25),
                  MyButton(
                    height: 45,
                    padding: EdgeInsets.zero,
                    depth: 6,
                    buttonColor: Colors.white,
                    backButtonColor: const Color.fromARGB(255, 226, 226, 226),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(authNotifierProvider.notifier).signInWithGoogle();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/google_logo.png',
                          width: 24,
                          height: 24,
                        ),
                        const Gap(10),
                        Text(
                          'sign_up_with_google'.tr(),
                          style: AppTextStyles.bigTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(25),
                  MyButton(
                    height: 45,
                    padding: EdgeInsets.zero,
                    depth: 6,
                    buttonColor: Colors.white,
                    backButtonColor: const Color.fromARGB(255, 226, 226, 226),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(authNotifierProvider.notifier).signInWithApple();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/apple_logo.png',
                          width: 24,
                          height: 24,
                        ),
                        const Gap(10),
                        Text(
                          'sign_up_with_apple'.tr(),
                          style: AppTextStyles.bigTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(10),
                ],
              ),
            ),
          ),

          // ── Loading overlay (shown during Google/Apple sign-in) ──
          if (authState is AsyncLoading || authState == const AuthState.loading())
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsating logo
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      onEnd: () {},
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Image.asset(
                          'assets/images/logo_vozha.png',
                          width: 60,
                          height: 52,
                        ),
                      ),
                    ),
                    const Gap(24),
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'loading'.tr(),
                      style: AppTextStyles.bigTextStyle.copyWith(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
