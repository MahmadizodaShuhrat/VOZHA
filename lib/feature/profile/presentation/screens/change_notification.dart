import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/screens/navigation_bar.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/services/notification_service.dart';
import 'package:vozhaomuz/feature/auth/presentation/widgets/time_slider_widget.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class ChangeNotification extends ConsumerStatefulWidget {
  const ChangeNotification({super.key});

  @override
  ConsumerState<ChangeNotification> createState() => _ChangeNotificationState();
}

class _ChangeNotificationState extends ConsumerState<ChangeNotification> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Icon(Icons.chevron_left_rounded, size: 50),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
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
                          fontWeight: FontWeight.w500,
                          fontSize: 25,
                        ),
                      ),

                      Text(
                        textAlign: TextAlign.center,
                        'enable_reminder'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 17,
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
            child: MyButton(
              height: 45,
              padding: EdgeInsets.zero,
              width: double.infinity,
              buttonColor: Colors.blue,
              backButtonColor: Colors.blueGrey,
              child: Text(
                textAlign: TextAlign.center,
                'next'.tr(),
                style: AppTextStyles.bigTextButton,
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();

                // Аз TimeSlider соати интихобшударо гирем
                final sliderValue = ref.read(timeSliderProvider);
                final totalMinutes = (sliderValue * 1).toInt();
                int hour = 6 + totalMinutes ~/ 60;
                final minute = totalMinutes % 60;
                if (hour >= 24) hour -= 24;

                // Иҷозат гирифтан ва notification schedule кардан
                final notifService = NotificationService.instance;
                await notifService.init();
                await notifService.requestPermission();
                await notifService.scheduleDailyReminder(
                  hour: hour,
                  minute: minute,
                );

                debugPrint(
                  '📢 Reminder set for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                );

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NavigationPage()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
