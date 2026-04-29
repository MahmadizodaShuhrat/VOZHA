import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/providers/user_provider.dart';
import 'package:vozhaomuz/feature/auth/business/auth_error_translator.dart';
import 'package:vozhaomuz/feature/auth/business/auth_repository.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/auth_notifier_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/referral_sourse_widget.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/time_slider_widget.dart';
import 'package:vozhaomuz/feature/auth/state/auth_state.dart';
import 'package:vozhaomuz/feature/auth/state/pending_phone_registration.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class PushNotification extends ConsumerStatefulWidget {
  const PushNotification({super.key});

  @override
  ConsumerState<PushNotification> createState() => _PushNotificationState();
}

class _PushNotificationState extends ConsumerState<PushNotification> {
  bool _isRegistering = false;

  /// Complete registration via registerOauth2 API, then navigate to /home
  Future<void> _completeRegistration(BuildContext context) async {
    if (_isRegistering) return;
    setState(() => _isRegistering = true);

    try {
      final authState = ref.read(authNotifierProvider);

      // Extract registration data from auth state
      Map<String, dynamic>? registerData;
      authState.when(
        initial: () {},
        loading: () {},
        authenticated: (_) {},
        needsSignUp: (data, provider) {
          registerData = data;
        },
        error: (_) {},
      );

      // ── Phone / email registration branch ──
      // The account is ALREADY created at this point — `code_message.dart`
      // calls `_registerNow` the instant the SMS code is verified, which
      // saves tokens and seeds `userProvider`. This screen is just the
      // final wizard step (notifications permission prompt + referral
      // storage). If a token is already in StorageService we know we
      // came through the phone/email flow and we can jump straight to
      // /home without touching `/auth/register` again.
      final alreadyAuthed =
          (await StorageService.instance.getAccessToken())?.isNotEmpty ??
              false;
      // Clear the old pending-phone stash if anything's left — it's no
      // longer used once `_registerNow` runs.
      ref.read(pendingPhoneRegistrationProvider.notifier).clear();
      if (alreadyAuthed) {
        debugPrint('✅ already registered via code_message → /home');
        if (context.mounted) context.go('/home');
        return;
      }

      if (registerData == null) {
        // Not in needsSignUp state — maybe already logged in, just go home
        debugPrint('⚠️ registerOauth2: no registerData in state, going home');
        if (context.mounted) context.go('/home');
        return;
      }

      final email = registerData?['email'] as String? ?? '';
      final name = registerData?['name'] as String? ?? '';

      // Get referral source from referral page selection
      final referralIndex = ref.read(selectedIndexProvider);
      String aboutUs = '';
      switch (referralIndex) {
        case 0:
          aboutUs = 'From instagram';
          break;
        case 1:
          aboutUs = 'From facebook';
          break;
        case 2:
          aboutUs = 'At friend';
          break;
      }

      debugPrint('📝 registerOauth2: START');
      debugPrint('📝 registerOauth2: email=$email');
      debugPrint('📝 registerOauth2: name=$name');
      debugPrint('📝 registerOauth2: aboutUs=$aboutUs');
      debugPrint('📝 registerOauth2: referralIndex=$referralIndex');

      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.registerOauth2(
        email: email,
        name: name,
        age: '',
        inviteCode: '',
        userCategory: '',
        aboutUs: aboutUs,
      );

      debugPrint('✅ registerOauth2: Response=$result');

      // Save tokens from response (same structure as Unity's RegisterUser)
      final accessToken = result['access_token'] as String?;
      final refreshToken = result['refresh_token'] as String?;
      final userId = result['id']?.toString() ?? '';
      final userName = result['name'] as String? ?? name;

      debugPrint(
        '✅ registerOauth2: accessToken=${accessToken != null ? '${accessToken.substring(0, 20)}...' : 'null'}',
      );
      debugPrint(
        '✅ registerOauth2: refreshToken=${refreshToken != null ? '${refreshToken.substring(0, 20)}...' : 'null'}',
      );
      debugPrint('✅ registerOauth2: userId=$userId, userName=$userName');

      if (accessToken != null && accessToken.isNotEmpty) {
        await StorageService.instance.setAccessToken(accessToken);
        if (refreshToken != null) {
          await StorageService.instance.setRefreshToken(refreshToken);
        }
        ref
            .read(userProvider.notifier)
            .set(User(id: userId, name: userName, jwtToken: accessToken));
        debugPrint('✅ registerOauth2: Tokens saved, navigating to /home');
      } else {
        debugPrint('⚠️ registerOauth2: No access token in response');
      }

      if (context.mounted) context.go('/home');
    } catch (e, s) {
      debugPrint('❌ registerOauth2: Error=$e');
      debugPrint('❌ registerOauth2: Stack=$s');
      if (context.mounted) {
        // Strip Dart's "Exception: " prefix, then translate known codes
        // (code_used, code_expired, register_failed, ...) so the user
        // sees a localized message instead of a snake_case token.
        final raw = e.toString();
        final cleaned =
            raw.startsWith('Exception: ') ? raw.substring(11) : raw;
        final localized = translateAuthError(cleaned);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'registration_error'.tr()}: $localized'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: GestureDetector(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/auth/referral');
            }
          },
          child: Icon(Icons.chevron_left_rounded, size: 50),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: GestureDetector(
              onTap: _isRegistering
                  ? null
                  : () => _completeRegistration(context),
              child: Text(
                'later'.tr(),
                style: TextStyle(fontWeight: FontWeight.w400, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            // 35 % of screen height clamped to [220, 320]. The 230×230
            // image inside needs ~290 pt of vertical room; without the
            // clamp on iPhone SE (667pt) the container is only 233pt
            // and the image is clipped by the rounded bottom corners.
            height: (MediaQuery.of(context).size.height * 0.35)
                .clamp(220.0, 320.0),
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(40),
                bottomLeft: Radius.circular(40),
              ),
            ),
            child: Image.asset(
              'assets/images/privichka.png',
              width: 230,
              height: 230,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        textAlign: TextAlign.center,
                        'create_new_habit'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 27,
                        ),
                      ),
                      Gap(30),
                      Text(
                        textAlign: TextAlign.center,
                        'enable_reminder'.tr(),
                        style: AppTextStyles.whiteTextStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  TimeSliderWidget(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 25, left: 20, right: 20),
            child: _isRegistering
                ? const Center(child: CircularProgressIndicator())
                : MyButton(
                    height: 52,
                    padding: EdgeInsets.zero,
                    width: double.infinity,
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
                      _completeRegistration(context);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
