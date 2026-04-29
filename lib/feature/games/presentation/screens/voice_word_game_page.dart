import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/core/utils/zip_resource_loader.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/listen_again.dart';

class VoiceCardPage extends ConsumerStatefulWidget {
  @override
  _VoiceCardPageState createState() => _VoiceCardPageState();
}

final currentWordIndexProvider = StateProvider<int>((ref) => 0);

class _VoiceCardPageState extends ConsumerState<VoiceCardPage> {
  final AudioPlayer player = AudioPlayer();
  bool isTapped = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final words = ref.read(learningWordsProvider);
      final currentIndex = ref.read(currentWordIndexProvider);
      AudioHelper.playWord(
        player,
        '',
        '${words[currentIndex].word}.mp3',
        categoryId: words[currentIndex].categoryId,
      );
    });
  }

  @override
  void dispose() {
    ZipResourceLoader.clear(); // выгружаем архивы из RAM
    player.dispose(); // если используете AudioPlayer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = ref.watch(learningWordsProvider);
    final currentIndex = ref.watch(currentWordIndexProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.794,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                      right: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                      top: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                      left: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'choose_translation'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF697586),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        words[currentIndex].word,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF202939),
                        ),
                      ),
                      SizedBox(height: 20),
                      IconButton(
                        icon: Image.asset(
                          "assets/images/ooui_volume-up-ltr.png",
                          width: 40,
                          height: 40,
                        ),
                        onPressed: () {
                          AudioHelper.playWord(
                            player,
                            '',
                            '${words[currentIndex].word}.mp3',
                            categoryId: words[currentIndex].categoryId,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isTapped = true;
                    });
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.794,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: isTapped ? Color(0xFFD1E9FF) : Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFEEF2F6), width: 4),
                        right: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                        top: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                        left: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          isTapped
                              ? "say_the_word".tr()
                              : "press_to_record".tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: isTapped
                                ? Color(0xFF2E90FA)
                                : Color(0xFF697586),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            // Сабти овоз
                          },
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.blue,
                            child: Image.asset(
                              "assets/images/microphone-2.png",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            showListenAgainBottomSheet(context, ref);
          },
          child: Text(
            "cant_listen_now".tr(),
            style: TextStyle(
              color: Color(0xFF2E90FA),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
