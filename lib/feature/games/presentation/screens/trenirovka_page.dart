import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/time_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/close_page.dart';
import 'package:vozhaomuz/shared/widgets/like_ListTile.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/shared/widgets/words_box.dart';

class TrenirovkaPage extends ConsumerWidget {
  const TrenirovkaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(learningWordsProvider);
    return WillPopScope(
      onWillPop: () async {
        if (ref.read(allowGameFlowPopProvider)) return true;
        showExitConfirmationDialog(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF5FAFF),
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Color(0xFFF5FAFF),
          leading: IconButton(
            onPressed: () {
              showExitConfirmationDialog(context);
            },
            icon: Icon(Icons.close, color: Colors.black, size: 30),
          ),
          title: Text(
            "Training".tr(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202939),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: WordsBox(
                  isVolume: false,
                  topWidthContainer: 65,
                  topColorContainer: Colors.yellowAccent.shade700,
                  topTextContainer: "Carefully read these words".tr(),
                  topTextStyleContainer: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202939),
                  ),
                  onPressed: () {},
                  child: Column(
                    children: [
                      Divider(color: Colors.white, height: 0),
                      for (int i = 0; i < words.length; i++) ...[
                        likeListTile(
                          words[i].displayWord,
                          transcription: words[i].transcription,
                          translation: words[i].translation,
                        ),
                        Divider(
                          color: i < words.length - 1
                              ? Colors.grey.shade200
                              : Colors.white,
                          height: 0,
                        ),
                      ],
                      Divider(color: Colors.grey.shade200, height: 0),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: MyButton(
                  width: double.infinity,
                  buttonColor: Color(0xFF2E90FA),
                  backButtonColor: Color(0xFF1570EF),
                  borderRadius: 10,
                  child: Center(
                    child: Text(
                      "Start".tr(),
                      style: AppTextStyles.whiteTextStyle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CountdownPage()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
