import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/pay_premium_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class MySubscriptionPage extends HookConsumerWidget {
  const MySubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.only(bottom: 40, left: 10, right: 10),
        child: MyButton(
          height: 52,
          padding: EdgeInsets.zero,
          backButtonColor: const Color.fromARGB(255, 102, 146, 125),
          borderRadius: 10,
          buttonColor: Color(0xff20CD7F),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PayPremiumPage()),
            );
          },
          child: Text(
            'next'.tr(),
            style: AppTextStyles.whiteTextStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: SweepGradient(
                center: Alignment(0, -0.6),
                colors: List.generate(60, (index) {
                  return index.isEven ? Colors.amber.shade50 : Colors.white;
                }),
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Gap(75),

                  Container(
                    height: 210,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(blurRadius: 4, color: Colors.grey)],
                    ),
                    child: Image.asset(
                      'assets/images/Frame.png',
                      height: 170,
                      width: 170,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'sub_learn_smart'.tr(),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 60,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 37,
                          width: MediaQuery.of(context).size.width * 0.55,
                          decoration: BoxDecoration(
                            color: const Color(0xffF9A628),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'sub_premium_benefits'.tr(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          top: -20,
                          right: -16,
                          child: Image.asset(
                            'assets/images/crown 1.png',
                            height: 40,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildListofRow(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Positioned(
            child: Container(
              padding: EdgeInsets.all(30),
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Icon(Icons.clear, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheck() {
    return const Icon(Icons.check, color: Color(0xFF4AAFFF), size: 24);
  }

  Widget _buildEmpty() {
    return const SizedBox(width: 28, height: 28);
  }

  Widget _buildRow(String text, bool isFree, bool isPremium) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xff333333),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Center(child: isFree ? _buildCheck() : _buildEmpty()),
              ),
              SizedBox(
                width: 90,
                child: Center(child: isPremium ? _buildCheck() : _buildEmpty()),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }

  Widget _buildListofRow() {
    final features = [
      ('sub_7_categories'.tr(), true, true),
      ('sub_create_battle'.tr(), false, true),
      ('sub_ai_pronunciation'.tr(), false, true),
      ('sub_36_categories'.tr(), false, true),
      ('sub_book_1001'.tr(), false, true),
      ('sub_shop'.tr(), false, true),
      ('sub_word_repeat'.tr(), true, true),
      ('sub_export_words'.tr(), true, true),
      ('sub_daily_rewards'.tr(), true, true),
      ('sub_change_level'.tr(), true, true),
      ('sub_5_exercises'.tr(), true, true),
      ('sub_access_36_categories'.tr(), true, true),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: IntrinsicHeight(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Continuous white card behind premium column
            Positioned(
              right: 0,
              top: -10,
              bottom: 0,
              width: 90,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 90, 86, 86),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Column(
              children: [
                // Column headers
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      SizedBox(
                        width: 80,
                        child: Center(
                          child: Text(
                            'sub_free'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff333333),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF9A628),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Text(
                                  'sub_premium'.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -10,
                                right: -7,
                                child: Image.asset(
                                  'assets/images/crown 1.png',
                                  height: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ...features.map((f) => _buildRow(f.$1, f.$2, f.$3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
