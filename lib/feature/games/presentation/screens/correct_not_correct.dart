import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

final currentWordIndexProvider =
    NotifierProvider<CorrectNotCorrectIndexNotifier, int>(
      CorrectNotCorrectIndexNotifier.new,
    );

class CorrectNotCorrectIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}

final isShowProvider = NotifierProvider<IsShowNotifier, bool?>(
  IsShowNotifier.new,
);

class IsShowNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  void set(bool? value) => state = value;
}

class CorrectNotCorrect extends ConsumerWidget {
  const CorrectNotCorrect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShow = ref.watch(isShowProvider);
    final wordss = ref.watch(learningWordsProvider);

    // гирем 4-тои аввал
    final limitedWords = wordss.take(4).toList();

    // интихоб кун калимаи ҳозира
    final currentIndexx = ref.watch(currentWordIndexProvider);
    final wordData = (currentIndexx < limitedWords.length)
        ? limitedWords[currentIndexx]
        : null;

    final wordd = wordData?.word ?? '';
    final translationn = wordData?.translation ?? '';
    final transciptionn = wordData?.transcription ?? '';

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFF),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'True False'.tr(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 10),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),

                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 6,
                        ),
                        right: BorderSide(
                          color: Colors.grey.shade200,
                          width: 2,
                        ),
                        left: BorderSide(color: Colors.grey.shade200, width: 2),
                        top: BorderSide(color: Colors.grey.shade200, width: 2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(height: 50),
                        Image.asset("assets/images/image 123.png", height: 190),
                        SizedBox(height: 30),
                        Divider(color: Colors.grey.shade200),
                        Text(
                          wordd,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          transciptionn,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          translationn,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(height: 20),
                          SizedBox(
                            height: 30,
                            child: isShow != null
                                ? vernoNeverno(isShow)
                                : SizedBox(),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                      SizedBox(height: 16),
                      MyButton(
                        width: double.infinity,
                        height: 48,
                        buttonColor: Color(0xFF22C55E),
                        backButtonColor: Color(0xFF16A34A),
                        child: Center(
                          child: Text(
                            '  ${'correct'.tr()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(isShowProvider.notifier).set(true);
                          Future.delayed(Duration(seconds: 2), () {
                            ref.read(isShowProvider.notifier).set(null);

                            // Баъди нишон додани натиҷа, мегузарем ба калимаи навбатӣ
                            final index = ref.read(currentWordIndexProvider);
                            if (index < 3) {
                              ref
                                  .read(currentWordIndexProvider.notifier)
                                  .set(index + 1);
                            } else {
                              // агар расидем ба охир, аз нав сар мекунем
                              ref
                                  .read(currentWordIndexProvider.notifier)
                                  .set(0);
                            }
                          });
                        },
                      ),
                      SizedBox(height: 15),
                      MyButton(
                        width: double.infinity,
                        height: 48,
                        buttonColor: Color(0xFFEF4444),
                        backButtonColor: Color(0xFFDC2626),
                        child: Center(
                          child: Text(
                            '  ${'incorrect'.tr()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(isShowProvider.notifier).set(false);
                          Future.delayed(Duration(seconds: 2), () {
                            ref.read(isShowProvider.notifier).set(null);
                            final index = ref.read(currentWordIndexProvider);
                            if (index < 3) {
                              ref
                                  .read(currentWordIndexProvider.notifier)
                                  .set(index + 1);
                            } else {
                              // агар расидем ба охир, аз нав сар мекунем
                              ref
                                  .read(currentWordIndexProvider.notifier)
                                  .set(0);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget vernoNeverno(bool isTrue) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border(bottom: BorderSide(color: Color(0xFFEEF2F6), width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTrue ? Color(0xFF22C55E) : Color(0xFFEF4444),
                ),
                child: Center(
                  child: isTrue
                      ? Icon(Icons.check, color: Colors.white, size: 17)
                      : Icon(Icons.close, color: Colors.white, size: 17),
                ),
              ),
              SizedBox(width: 5),
              Text(
                isTrue ? 'correct'.tr() : 'incorrect'.tr(),
                style: TextStyle(
                  color: isTrue ? Color(0xFF22C55E) : Color(0xFFEF4444),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
