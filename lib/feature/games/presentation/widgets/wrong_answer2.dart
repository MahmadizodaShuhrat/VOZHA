import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

final AudioPlayer _player = AudioPlayer();
Future<void> showAnswerFeedback(
  BuildContext context, {
  required String userAnswer,
  required String userTranslation,
  required String correctAnswer,
  required String correctTranslation,
  int? categoryId,
}) {
  return showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    isDismissible: false,
    enableDrag: false,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'pay_attention'.tr(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'your_answer'.tr(),
              style: AppTextStyles.whiteTextStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
                color: const Color(0xffF5FAFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userAnswer,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          userTranslation,
                          style: AppTextStyles.whiteTextStyle.copyWith(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.volume_up, color: Colors.blue, size: 35),
                    onPressed: () {
                      AudioHelper.playWord(
                        _player,
                        '',
                        '${userAnswer}.mp3',
                        categoryId: categoryId,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'correct_answer'.tr(),
              style: AppTextStyles.whiteTextStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
                color: const Color(0xffF5FAFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          correctAnswer,
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          correctTranslation,
                          style: AppTextStyles.whiteTextStyle.copyWith(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.volume_up, color: Colors.blue, size: 35),
                    onPressed: () {
                      AudioHelper.playWord(
                        _player,
                        '',
                        '${correctAnswer}.mp3',
                        categoryId: categoryId,
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            MyButton(
              width: double.infinity,
              buttonColor: Color(0xFF2E90FA),
              backButtonColor: Color(0xFF1570EF),
              child: Center(
                child: Text(
                  "next".tr(),
                  style: AppTextStyles.whiteTextStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}
