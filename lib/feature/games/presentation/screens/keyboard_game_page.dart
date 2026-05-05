import 'package:audioplayers/audioplayers.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/selected_level_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/key_board_notifier.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/shared/widgets/my_key_board.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';

class KeyboardGamePage extends ConsumerStatefulWidget {
  const KeyboardGamePage({super.key});

  @override
  ConsumerState<KeyboardGamePage> createState() => _KeyboardGamePageState();
}

final isClickedProvider = NotifierProvider<IsClickedNotifier, bool>(
  IsClickedNotifier.new,
);

class IsClickedNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool value) => state = value;
}

final typedWordProvider = NotifierProvider<TypedWordNotifier, String>(
  TypedWordNotifier.new,
);

class TypedWordNotifier extends Notifier<String> {
  @override
  String build() => "";
  void add(String char) => state += char;
  void clear() => state = "";
  void removeLast() {
    if (state.isNotEmpty) {
      state = state.substring(0, state.length - 1);
    }
  }

  void set(String value) => state = value;
}

final canTapSpaceProvider = Provider<bool>((ref) {
  final idx = ref.watch(currentWordIndexProvider);
  final word = ref.watch(learningWordsProvider)[idx].word;
  final typed = ref.watch(typedWordProvider);

  // Count how many spaces the word has
  final wordSpaceCount = ' '.allMatches(word).length;

  // No spaces in the word → disable space button
  if (wordSpaceCount == 0) return false;

  // Allow space only if typed spaces < word spaces
  final typedSpaceCount = ' '.allMatches(typed).length;
  return typedSpaceCount < wordSpaceCount;
});

final row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', "'"];
final row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', "-"];
final row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm', '?'];
final rowNumbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

class _KeyboardGamePageState extends ConsumerState<KeyboardGamePage> {
  // State variables - inside class, not global!
  bool iDontKnow = false;
  bool isCorrect = false;
  bool isWrong = false;
  bool _isCapsLock = false;
  bool _isLevel3 = false; // Level 3 = all keys active (no hints)
  final AudioPlayer _player = AudioPlayer();

  void _playClickLetter() {
    AudioHelper.playClick();
  }

  void _playRemoveLetter() {
    AudioHelper.playRemove();
  }

  @override
  void initState() {
    super.initState();
    // Reset state on each game start
    iDontKnow = false;
    isCorrect = false;
    isWrong = false;
    debugPrint('🎮 [KeyboardGame] initState - State reset');

    // Reset providers on each game start
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Reset word index to 0
      ref.read(currentWordIndexProvider.notifier).set(0);
      // Clear typed word
      ref.read(typedWordProvider.notifier).clear();

      // Check user level — level 3 = all keys active
      final level = await SelectedLevelNotifier.getSavedLevelValue();
      if (mounted) {
        setState(() {
          _isLevel3 = (level == 3);
        });
      }
      debugPrint('🎮 [KeyboardGame] User level: $level, isLevel3: $_isLevel3');

      // Initialize keyboard with first word's letters
      final words = ref.read(learningWordsProvider);
      if (words.isNotEmpty) {
        final firstWord = words[0].word;
        ref.read(letterCountProvider.notifier).initForWord(0, firstWord);
        debugPrint('🎮 [KeyboardGame] Initialized with word: $firstWord');
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(currentWordIndexProvider, (prev, next) {
      if (prev != next) {
        setState(() => iDontKnow = false);
      }
    });
    final currentttIndex = ref.watch(currentWordIndexProvider);
    String typedWord = ref.watch(typedWordProvider);
    final currentIndex = ref.watch(currentWordIndexProvider);
    final letterCounts = ref.watch(letterCountForIndexProvider(currentIndex));
    final words = ref.watch(learningWordsProvider);
    final word = words[currentttIndex].word;
    final translation = words[currentttIndex].translation;
    final canTapSpace = ref.watch(canTapSpaceProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 60),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Make a word / Build a word".tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF697586),
                        ),
                      ),
                      Center(
                        child: Text(
                          translation,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF202939),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFEEF2F6), width: 4),
                  ),
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iDontKnow || isWrong
                        ? Text(
                            word,
                            style: AppTextStyles.whiteTextStyle.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFACC15),
                            ),
                          )
                        : SizedBox.shrink(),
                    Text(
                      typedWord,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                            ? Colors.red
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Чап тугма: "Не знаю" ↔ "Пропустить"
                  if (!iDontKnow)
                    MyButton(
                      width: 140,
                      height: 35,
                      depth: 3,
                      padding: EdgeInsets.zero,
                      backButtonColor: Color.fromARGB(255, 220, 225, 229),
                      borderRadius: 20,
                      child: Text(
                        "i_dont_know".tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: Color(0xFF202939),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          iDontKnow = true;
                        });
                      },
                    )
                  else
                    MyButton(
                      width: 140,
                      height: 35,
                      depth: 3,
                      padding: EdgeInsets.zero,
                      backButtonColor: Color(0xFFCDD5DF),
                      buttonColor: Color(0xFFEEF2F6),
                      borderRadius: 20,
                      child: Text(
                        "skip".tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Color(0xFF202939),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final skippedWord = words[currentIndex];
                        ref
                            .read(gameResultProvider.notifier)
                            .addResult(
                              word: skippedWord.word,
                              translation: skippedWord.translation,
                              isCorrect: false,
                              gameIndex: 4,
                              wordId: skippedWord.id,
                              gameName: GameNames.writeTranslation,
                            );
                        ref
                            .read(dotsProvider.notifier)
                            .markAnswer(isCorrect: false);
                        final nextIdx = currentIndex + 1;
                        final stage = ref.read(gameStageProvider);
                        if (nextIdx < words.length) {
                          final nextWord = words[nextIdx].word;
                          ref
                              .read(currentWordIndexProvider.notifier)
                              .set(nextIdx);
                          ref
                              .read(letterCountProvider.notifier)
                              .resetWithWord(nextIdx, nextWord);
                        } else {
                          ref.read(currentWordIndexProvider.notifier).set(0);
                          ref
                              .read(gameStageProvider.notifier)
                              .set(getNextStage(stage, ref));
                        }
                        ref.read(typedWordProvider.notifier).clear();
                        setState(() {
                          iDontKnow = false;
                          isCorrect = false;
                          isWrong = false;
                        });
                      },
                    ),
                  SizedBox(width: 20),
                  // Рост тугма: "Проверить" — фаъол танҳо вақте калима пурра навишта шавад
                  MyButton(
                    width: 130,
                    height: 35,
                    depth: 3,
                    padding: EdgeInsets.zero,
                    backButtonColor: typedWord.length >= word.length
                        ? Color.fromARGB(255, 33, 86, 143)
                        : Color.fromARGB(255, 227, 231, 235),
                    buttonColor: typedWord.length >= word.length
                        ? Color(0xFF2E90FA)
                        : Color(0xFF2E90FA),
                    borderRadius: 20,
                    child: Text(
                      "check".tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: typedWord.length >= word.length
                        ? () async {
                            HapticFeedback.lightImpact();
                            final typed = ref.read(typedWordProvider);
                            final currentIdx = ref.read(
                              currentWordIndexProvider,
                            );
                            final wordsList = ref.read(learningWordsProvider);
                            final currentWordData = wordsList[currentIdx];
                            final correctWord = currentWordData.word;
                            final stage = ref.read(gameStageProvider);

                            if (typed.toLowerCase() ==
                                correctWord.toLowerCase()) {
                              setState(() {
                                isCorrect = true;
                                isWrong = false;
                              });
                              try {
                                AudioHelper.playCorrect();
                              } catch (e) {
                                debugPrint('Audio error (ignored): $e');
                              }
                              ref
                                  .read(gameResultProvider.notifier)
                                  .addResult(
                                    word: currentWordData.word,
                                    translation: currentWordData.translation,
                                    isCorrect: true,
                                    gameIndex: 4,
                                    wordId: currentWordData.id,
                                    gameName: GameNames.writeTranslation,
                                  );
                              await Future.delayed(Duration(milliseconds: 200));
                              final nextIdx = currentIdx + 1;
                              if (nextIdx < wordsList.length) {
                                ref
                                    .read(dotsProvider.notifier)
                                    .markAnswer(isCorrect: true);
                                final nextWord = wordsList[nextIdx].word;
                                ref
                                    .read(currentWordIndexProvider.notifier)
                                    .set(nextIdx);
                                ref
                                    .read(letterCountProvider.notifier)
                                    .resetWithWord(nextIdx, nextWord);
                                ref.read(typedWordProvider.notifier).clear();
                                setState(() {
                                  isCorrect = false;
                                  isWrong = false;
                                });
                              } else {
                                ref
                                    .read(dotsProvider.notifier)
                                    .markAnswer(isCorrect: true);
                                ref
                                    .read(currentWordIndexProvider.notifier)
                                    .set(0);
                                ref
                                    .read(gameStageProvider.notifier)
                                    .set(getNextStage(stage, ref));
                              }
                            } else {
                              setState(() {
                                isWrong = true;
                                isCorrect = false;
                              });
                              try {
                                AudioHelper.playWrong();
                              } catch (e) {
                                debugPrint('Audio error (ignored): $e');
                              }
                              ref
                                  .read(gameResultProvider.notifier)
                                  .addResult(
                                    word: currentWordData.word,
                                    translation: currentWordData.translation,
                                    isCorrect: false,
                                    gameIndex: 4,
                                    wordId: currentWordData.id,
                                    gameName: GameNames.writeTranslation,
                                  );
                              // Hold the mistake on screen long enough for
                              // the user to actually read what they typed
                              // (red) vs. the correct word (yellow). 200 ms
                              // was effectively invisible — users reported
                              // "the app jumped before I saw my mistake".
                              await Future.delayed(
                                const Duration(milliseconds: 1500),
                              );
                              final nextIdx = currentIdx + 1;
                              if (nextIdx < wordsList.length) {
                                final nextWord = wordsList[nextIdx].word;
                                ref
                                    .read(dotsProvider.notifier)
                                    .markAnswer(isCorrect: false);
                                ref
                                    .read(currentWordIndexProvider.notifier)
                                    .set(nextIdx);
                                ref
                                    .read(letterCountProvider.notifier)
                                    .resetWithWord(nextIdx, nextWord);
                                ref.read(typedWordProvider.notifier).clear();
                                setState(() {
                                  isCorrect = false;
                                  isWrong = false;
                                });
                              } else {
                                ref
                                    .read(dotsProvider.notifier)
                                    .markAnswer(isCorrect: false);
                                ref
                                    .read(currentWordIndexProvider.notifier)
                                    .set(0);
                                ref
                                    .read(gameStageProvider.notifier)
                                    .set(getNextStage(stage, ref));
                              }
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: 5),
            Container(
              width: double.infinity,
              color: Color(0xFFF5FAFF),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Number row
                  Row(
                    children: [
                      SizedBox(width: 3),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: rowNumbers.map((char) {
                            final count = letterCounts[char]?.count ?? 0;
                            // Once the user taps "I don't know" the word is
                            // revealed — they shouldn't be able to keep
                            // typing, otherwise they could see the answer
                            // and still type it for free credit.
                            final enabled =
                                !iDontKnow && (_isLevel3 || count > 0);
                            return buildKeyBoard(
                              char,
                              _isLevel3 ? null : letterCounts[char],
                              enabled
                                  ? () {
                                      if (!mounted) return;
                                      HapticFeedback.lightImpact();
                                      _playClickLetter();
                                      if (!_isLevel3) {
                                        ref
                                            .read(letterCountProvider.notifier)
                                            .useLetter(currentIndex, char);
                                      }
                                      ref
                                          .read(typedWordProvider.notifier)
                                          .add(char);
                                    }
                                  : null,
                              forceEnabled: _isLevel3 && !iDontKnow,
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(width: 3),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      SizedBox(width: 3),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children:
                              row1.map((char) {
                                final count = letterCounts[char]?.count ?? 0;
                                final enabled =
                                    !iDontKnow && (_isLevel3 || count > 0);
                                final displayChar = _isCapsLock
                                    ? char.toUpperCase()
                                    : char;
                                return buildKeyBoard(
                                  displayChar,
                                  _isLevel3 ? null : letterCounts[char],
                                  enabled
                                      ? () {
                                          if (!mounted) return;
                                          HapticFeedback.lightImpact();
                                          _playClickLetter();
                                          if (!_isLevel3) {
                                            ref
                                                .read(
                                                  letterCountProvider
                                                      .notifier,
                                                )
                                                .useLetter(
                                                  currentIndex,
                                                  char,
                                                );
                                          }
                                          ref
                                              .read(
                                                typedWordProvider.notifier,
                                              )
                                              .add(displayChar);
                                        }
                                      : null,
                                  forceEnabled: _isLevel3 && !iDontKnow,
                                );
                              }).toList(),
                        ),
                      ),
                      SizedBox(width: 3),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (int i = 0; i < row2.length; i++) ...[
                              buildKeyBoard(
                                _isCapsLock ? row2[i].toUpperCase() : row2[i],
                                _isLevel3 ? null : letterCounts[row2[i]],
                                (!iDontKnow &&
                                        (_isLevel3 ||
                                            (letterCounts[row2[i]]?.count ?? 0) >
                                                0))
                                    ? () {
                                        if (!mounted) return;
                                        HapticFeedback.lightImpact();
                                        _playClickLetter();
                                        if (!_isLevel3) {
                                          ref
                                              .read(
                                                letterCountProvider.notifier,
                                              )
                                              .useLetter(currentIndex, row2[i]);
                                        }
                                        ref
                                            .read(typedWordProvider.notifier)
                                            .add(
                                              _isCapsLock
                                                  ? row2[i].toUpperCase()
                                                  : row2[i],
                                            );
                                      }
                                    : null,
                                forceEnabled: _isLevel3 && !iDontKnow,
                              ),
                              SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    children: [
                      SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment
                              .spaceEvenly, // spaceBetween ro be start taghir dahid
                          children: [
                            comeBack(false),
                            SizedBox(width: 4),
                            for (int i = 0; i < row3.length; i++) ...[
                              buildKeyBoard(
                                _isCapsLock ? row3[i].toUpperCase() : row3[i],
                                _isLevel3 ? null : letterCounts[row3[i]],
                                (!iDontKnow &&
                                        (_isLevel3 ||
                                            (letterCounts[row3[i]]?.count ?? 0) >
                                                0))
                                    ? () {
                                        if (!mounted) return;
                                        HapticFeedback.lightImpact();
                                        _playClickLetter();
                                        if (!_isLevel3) {
                                          ref
                                              .read(
                                                letterCountProvider.notifier,
                                              )
                                              .useLetter(currentIndex, row3[i]);
                                        }
                                        ref
                                            .read(typedWordProvider.notifier)
                                            .add(
                                              _isCapsLock
                                                  ? row3[i].toUpperCase()
                                                  : row3[i],
                                            );
                                      }
                                    : null,
                                forceEnabled: _isLevel3 && !iDontKnow,
                              ),
                              SizedBox(width: 4),
                            ],
                            comeBack(true),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                  ),

                  SizedBox(height: 8),
                  Builder(builder: (context) {
                    final totalSpaces =
                        ' '.allMatches(word).length;
                    final typedSpaces =
                        ' '.allMatches(typedWord).length;
                    final remainingSpaces = totalSpaces - typedSpaces;
                    final spaceEnabled = !iDontKnow && canTapSpace;
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: spaceEnabled
                              ? () {
                                  if (!mounted) return;
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(typedWordProvider.notifier)
                                      .add(' ');
                                }
                              : null,
                          child: Container(
                            width: 232,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: spaceEnabled
                                  ? Colors.white
                                  : Color(0xFFCDD5DF),
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFB1BCCA),
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                "space".tr(),
                                style: TextStyle(
                                  fontSize: 20,
                                  color: spaceEnabled
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Match the corner-count badge shown on letter keys
                        // so users know how many spaces are still required
                        // in multi-word phrases (e.g. "hello world wide web"
                        // → badge shows "3" until they've typed enough).
                        if (remainingSpaces > 1)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(0xFF2E90FA),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(7),
                                  topRight: Radius.circular(5),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                remainingSpaces.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            //SizedBox(height: 1,)
          ],
        ),
      ],
    );
  }

  Widget comeBack(bool isClean) {
    final isShiftActive = !isClean && _isCapsLock;
    return MyButton(
      child: Icon(
        isClean ? Icons.backspace_outlined : Icons.arrow_upward,
        color: isShiftActive ? Colors.white : Colors.black,
      ),
      width: 38,
      height: 42,
      borderRadius: 5,
      backButtonColor: isShiftActive ? Color(0xFF1570EF) : Color(0xFFCDD5DF),
      borderColor: isShiftActive ? Color(0xFF1570EF) : Colors.grey.shade200,
      buttonColor: isShiftActive ? Color(0xFF2E90FA) : Colors.white,
      depth: 2,
      onPressed: () {
        HapticFeedback.lightImpact();
        if (isClean) {
          _playRemoveLetter();
          final typed = ref.read(typedWordProvider);
          if (typed.isNotEmpty) {
            final removedLetter = typed[typed.length - 1];

            ref.read(typedWordProvider.notifier).removeLast();

            final currentIndex = ref.watch(currentWordIndexProvider);

            ref
                .read(letterCountProvider.notifier)
                .addLetter(currentIndex, removedLetter.toLowerCase());
          }
        } else {
          setState(() {
            _isCapsLock = !_isCapsLock;
          });
        }
      },
      padding: EdgeInsets.zero,
    );
  }
}

Widget buildKeyBoard(
  String letter,
  LetterCount? letterCount,
  void Function()? onTap, {
  bool forceEnabled = false,
}) {
  final count = letterCount?.count ?? 0;
  final isEnabled = forceEnabled || count > 0;
  return Stack(
    children: [
      GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: MyKeyBoard(
          width: 28,
          height: 42,
          borderRadius: 5,
          padding: EdgeInsets.zero,
          backButtonColor: isEnabled ? Color(0xFFCDD5DF) : Color(0xFFB1BCCA),
          buttonColor: isEnabled ? Colors.white : Color(0xFFCDD5DF),
          borderWidth: 2,
          onPressed: onTap,
          child: Center(
            child: Text(
              letter,
              style: AppTextStyles.whiteTextStyle.copyWith(
                fontWeight: FontWeight.w400,
                fontSize: 20,
                color: isEnabled ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
      if (count > 1)
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Color(0xFF2E90FA),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
    ],
  );
}
