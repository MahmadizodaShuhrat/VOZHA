import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class InviteFriendPage extends HookConsumerWidget {
  const InviteFriendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileInfo = ref.watch(getProfileInfoProvider);
    final userId = profileInfo.whenOrNull(data: (data) => data?.id);
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 11, 112, 228),
                const Color.fromARGB(255, 120, 95, 218),
              ],
              end: Alignment.topLeft,
              begin: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Icon(
                            Icons.keyboard_arrow_left_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.2,
                        ),
                        Text(
                          'Invite_a_friend'.tr(),
                          style: AppTextStyles.bigTextStyle.copyWith(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Center(
                        child: Text(
                          'Invite_your_friends_and_get_rewards'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/images/coins.png',
                        width: double.infinity,
                        height: 450,
                      ),
                    ),
                    RichText(
                      textAlign: TextAlign.start,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 16, height: 1.4),
                        children: [
                          TextSpan(
                            text: '20 ${'coins'.tr()} ',
                            style: TextStyle(
                              color: Colors.amber.shade600,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          TextSpan(
                            text: '${'for_each_new_user'.tr()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${userId ?? '...'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final code = userId?.toString() ?? '';
                                SharePlus.instance.share(
                                  ShareParams(
                                    text: 'invite_share_message'.tr(
                                      namedArgs: {'code': code},
                                    ),
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.ios_share_outlined,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: double.infinity,
                          height: 1,
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: MyButton(
                        height: 52,
                        borderRadius: 10,
                        padding: EdgeInsets.zero,
                        buttonColor: Colors.blue.shade500,
                        backButtonColor: const Color.fromARGB(255, 25, 75, 125),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final code = userId?.toString() ?? '';
                          SharePlus.instance.share(
                            ShareParams(
                              text: 'invite_share_message'.tr(
                                namedArgs: {'code': code},
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Invite_a_friend'.tr(),
                          style: AppTextStyles.whiteTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 50, top: 10),
                      child: Text(
                        '${'descrip_invest_your_friends'.tr()}',
                        style: AppTextStyles.whiteTextStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 110,
                  right: 150,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/Group 1000002676.png',
                      width: 600,
                      height: 600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
