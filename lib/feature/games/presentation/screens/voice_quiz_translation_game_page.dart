import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/games_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/wrong_answer2.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';

class VoiceQuizTranslationGamePage extends ConsumerStatefulWidget {
  const VoiceQuizTranslationGamePage({super.key});

  @override
  ConsumerState<VoiceQuizTranslationGamePage> createState() =>
      _VoiceQuizTranslationGamePageState();
}

final AudioPlayer player = AudioPlayer();


class _VoiceQuizTranslationGamePageState
    extends ConsumerState<VoiceQuizTranslationGamePage> {
  int? _activeIndex;
  // ignore: unused_field - used for state management
  String? _resultMessage;
  bool? isCorrect;
  int? _correctIndex;

  /// Текущие варианты ответа (правильный + 3 дамми или все 4 learning words)
  List<Word> _options = [];

  void _buildOptions() {
    final words = ref.read(learningWordsProvider);
    final currentIndex = ref.read(currentWordIndexProvider);
    final pool = ref.read(dummyWordPoolProvider);

    if (currentIndex >= words.length) return;

    final correctWord = words[currentIndex];

    // Попробовать использовать дамми-слова из пула
    if (pool.isNotEmpty) {
      final dummies = ref
          .read(dummyWordPoolProvider.notifier)
          .pickForWord(correctWord, count: 3);

      if (dummies.isNotEmpty) {
        _options = [correctWord, ...dummies]..shuffle();
        return;
      }
    }

    // Fallback: Unity shows max 4 options
    _options = ([...words]..shuffle()).take(4).toList();
  }

  void _checkAnswer() async {
    if (_activeIndex == null) {
      setState(() {
        _resultMessage = "Пожалуйста, выберите вариант";
      });
      return;
    }

    final currentIndex = ref.read(currentWordIndexProvider);
    final words = ref.read(learningWordsProvider);
    if (currentIndex >= words.length) return;

    final correctWord = words[currentIndex];
    final selectedWord = _options[_activeIndex!];
    isCorrect = selectedWord.id == correctWord.id;

    setState(() {
      _correctIndex = _activeIndex;
      _resultMessage = isCorrect!
          ? "Правильно! 🎉"
          : "Неправильно. Попробуйте снова.";
    });

    if (isCorrect != null) {
      ref.read(dotsProvider.notifier).markAnswer(isCorrect: isCorrect!);
      // Fire-and-forget: use preloaded SFX (same as flashcard)
      try {
        if (isCorrect!) {
          AudioHelper.playCorrect();
        } else {
          AudioHelper.playWrong();
        }
      } catch (e) {
        debugPrint('Audio error (ignored): $e');
      }

      ref
          .read(gameResultProvider.notifier)
          .addResult(
            word: correctWord.word,
            translation: correctWord.translation,
            isCorrect: isCorrect!,
            gameIndex: 6,
            wordId: correctWord.id,
            gameName: GameNames.selectTranslationVoice,
          );
    }
    if (isCorrect != null && !isCorrect!) {
      await showAnswerFeedback(
        context,
        userAnswer: selectedWord.word,
        userTranslation: selectedWord.translation,
        correctAnswer: correctWord.word,
        correctTranslation: correctWord.translation,
        categoryId: correctWord.categoryId,
      );
    }
    if (!mounted) return;
    await Future.delayed(Duration(milliseconds: 200));

    setState(() {
      _activeIndex = null;
      _correctIndex = null;
      _resultMessage = null;
    });

    ref.read(currentWordIndexProvider.notifier).increment();

    // Перестроить варианты для следующего слова
    _buildOptions();

    final nextIndex = ref.read(currentWordIndexProvider);
    if (nextIndex >= words.length) {
      final stage = ref.read(gameStageProvider);
      ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
    }
  }

  void _setActive(int index) {
    setState(() {
      _activeIndex = index;
    });
  }

  final random = Random();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildOptions();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final words = ref.watch(learningWordsProvider);
    final currentIndex = ref.watch(currentWordIndexProvider);

    // Если варианты ещё не построены, построить сейчас
    if (_options.isEmpty && words.isNotEmpty) {
      _buildOptions();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEF2F6), width: 4),
                right: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                left: BorderSide(color: Color(0xFFEEF2F6), width: 1),
                top: BorderSide(color: Color(0xFFEEF2F6), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 35),
                Text(
                  'Выбери правильный перевод',
                  style: TextStyle(fontSize: 21, color: Colors.black12),
                ),
                SizedBox(height: 8),
                Text(
                  (currentIndex < words.length) ? words[currentIndex].word : "",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),
                Divider(color: Color(0xFFEEF2F6), height: 0),
                Column(
                  children: List.generate(_options.length, (index) {
                    final optionWord = _options[index];

                    bool? isCorrectAnswer;
                    if (_correctIndex != null && _correctIndex == index) {
                      isCorrectAnswer =
                          currentIndex < words.length &&
                          optionWord.id == words[currentIndex].id;
                    }
                    return AudioOption(
                      audioPath: "${optionWord.word}.mp3",
                      categoryId: optionWord.categoryId,
                      isActive: _activeIndex == index,
                      isCorrect: isCorrectAnswer,
                      onPressed: () => _setActive(index),
                      isLast: index == _options.length - 1,
                    );
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: MyButton(
              backButtonColor: Color(0xFF1570EF),
              buttonColor: Color(0xFF2E90FA),
              borderRadius: 10,
              padding: EdgeInsets.symmetric(vertical: 10),
              onPressed: _checkAnswer,
              child: Text(
                "Выбрать",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
