import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/current_indicator.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<String> _images = [
    'assets/images/uimotivation/choose_and_learn.png',
    'assets/images/uimotivation/fast_memorization.png',
    'assets/images/uimotivation/small_steps_big_results.png',
    'assets/images/uimotivation/your_app_your_rules.png',
  ];

  final List<Map<String, String>> _descriptions = [
    {'title': 'motivation_1', 'description': 'motivation_description_1'},
    {'title': 'motivation_2', 'description': 'motivation_description_2'},
    {'title': 'motivation_3', 'description': 'motivation_description_3'},
    {'title': 'motivation_4', 'description': 'motivation_description_4'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenColors,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: GestureDetector(
          onTap: () => context.go('/auth/start'),
          child: Icon(Icons.arrow_back_ios),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 30),
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _images.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      return SizedBox(child: Image.asset(_images[index]));
                    },
                  ),
                ),
                Gap(25),
                CurrentIndicator(
                  itempadding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  size: 4,
                  alignment: Alignment.center,
                  indicatorLength: _images.length,
                  currentIndex: _currentIndex,
                ),
              ],
            ),
          ),
          // Scrollable text area — prevents overflow on small screens
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _descriptions[_currentIndex]['title']!.tr(),
                    style: AppTextStyles.bigTextStyle.copyWith(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff202939),
                    ),
                    textAlign: TextAlign.start,
                  ),
                  Gap(15),
                  Text(
                    _descriptions[_currentIndex]['description']!.tr(),
                    style: AppTextStyles.hintextStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xff202939),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Button always visible at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: MyButton(
              height: 52,
              padding: EdgeInsets.zero,
              backButtonColor: Color(0xff0e77b1),
              buttonColor: AppColors.buttonColor,
              child: Center(
                child: Text(
                  'next'.tr(),
                  style: AppTextStyles.whiteTextStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                  ),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                if (_currentIndex < _images.length - 1) {
                  // Ба саҳифаи навбатӣ гузаред
                  _pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  // Дар саҳифаи охирин — ба SignUpPage равед
                  context.go('/auth/signup');
                }
              },
            ),
          ),
          Gap(40),
        ],
      ),
    );
  }
}
