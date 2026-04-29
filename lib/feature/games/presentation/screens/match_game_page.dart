import 'package:audioplayers/audioplayers.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/wrong_answer2.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dummy_words_provider.dart';

class MatchGamePage extends ConsumerStatefulWidget {
  const MatchGamePage({super.key});

  @override
  ConsumerState<MatchGamePage> createState() => _MatchGamePageState();
}

class _MatchGamePageState extends ConsumerState<MatchGamePage> {
  final AudioPlayer player = AudioPlayer();

  // Unity 3D style: match game gets only its assigned words and plays them once
  List<Word> _selectedWords = [];
  List<Word> _shuffledTranslations = [];
  Set<int> _matchedPairIndices = {};
  Set<int> _temporaryHideIndices = {};
  int? _firstIndex;
  bool? _firstIsEnglish;
  int? _secondIndex;
  bool? _secondIsEnglish;
  bool? _lastResult;

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    debugPrint('🎮 [MatchGame] initState');

    Future.microtask(() {
      if (!mounted) return;
      final learningWords = ref.read(learningWordsProvider);
      debugPrint('🎮 [MatchGame] Got ${learningWords.length} assigned words');

      if (learningWords.isEmpty) {
        debugPrint('⚠️ [MatchGame] No words at all, skipping to next stage');
        final stage = ref.read(gameStageProvider);
        ref.read(currentWordIndexProvider.notifier).set(0);
        ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
        return;
      }

      // Memoria caps at 4 words per round (4 pairs + 1 distractor).
      // Anything beyond that overflows the screen and breaks the matching
      // UX, so extra words stay in other stages.
      _selectedWords = List<Word>.from(
        learningWords.length > 4 ? learningWords.sublist(0, 4) : learningWords,
      );

      // When fewer than 4 real words landed here (e.g. the "quince"
      // scenario where only one word's errorInGames = ["Memoria"]), pad
      // the round with words the user already reviewed earlier in this
      // same repeat session. Using previously-seen words keeps the
      // matching grid full without risking a random-dummy distractor
      // accidentally counting as a mistake.
      if (_selectedWords.length < 4) {
        final isRepeat = ref.read(isRepeatModeProvider);
        if (isRepeat) {
          final allRepeat = ref.read(allRepeatWordsProvider);
          final currentIds = _selectedWords.map((w) => w.id).toSet();
          final extras = allRepeat
              .where((w) => !currentIds.contains(w.id))
              .take(4 - _selectedWords.length)
              .toList();
          if (extras.isNotEmpty) {
            _selectedWords.addAll(extras);
            debugPrint(
              '🧩 [MatchGame] Padded round with ${extras.length} already-reviewed '
              'word(s) from this repeat session: ${extras.map((w) => w.word).join(", ")}',
            );
          }
        }
      }

      if (_selectedWords.length < 2) {
        debugPrint(
          '⚠️ [MatchGame] Still <2 words after padding; skipping to next stage',
        );
        final stage = ref.read(gameStageProvider);
        ref.read(currentWordIndexProvider.notifier).set(0);
        ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
        return;
      }

      // Create shuffled translations + 1 dummy distractor
      _shuffledTranslations = List<Word>.from(_selectedWords);

      final pool = ref.read(dummyWordPoolProvider);
      if (pool.isNotEmpty) {
        final dummies = ref
            .read(dummyWordPoolProvider.notifier)
            .pickForWord(_selectedWords[0], count: 1);
        if (dummies.isNotEmpty) {
          _shuffledTranslations.add(dummies[0]);
          debugPrint('✅ [MatchGame] Dummy from pool: ${dummies[0].translation}');
        } else {
          _addFallbackDummy();
        }
      } else {
        _addFallbackDummy();
      }

      _shuffledTranslations.shuffle();

      debugPrint(
        '🎮 [MatchGame] ${_selectedWords.length} words, '
        '${_shuffledTranslations.length} translations (incl. 1 dummy)',
      );

      setState(() {});
    });
  }

  void _addFallbackDummy() {
    if (_selectedWords.isNotEmpty) {
      // Калимаи сохтагӣ месозем бо тарҷумаи нодуруст,
      // то ки корбар онро match карда натавонад
      _shuffledTranslations.add(
        Word(
          id: -1,
          word: '---',
          translation: '???',
          transcription: '',
          status: '',
          categoryId: _selectedWords.first.categoryId,
        ),
      );
      debugPrint('⚠️ [MatchGame] No pool, using fallback distractor');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Center the grid of tiles vertically on the remaining screen space so
    // short lists don't cling to the top. SingleChildScrollView alone ignores
    // `mainAxisAlignment.center` because its viewport has unbounded height;
    // wrapping the column in a ConstrainedBox with the full viewport height
    // lets Flutter honor the center alignment while still allowing scroll
    // overflow on small phones when the grid is long.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _shuffledTranslations.length; i++) ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: i < _selectedWords.length
                                ? _buildMatchTile(
                                    text: _selectedWords[i].word,
                                    pairIndex: i,
                                    isEnglish: true,
                                  )
                                : const SizedBox(height: 80),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMatchTile(
                              text: _shuffledTranslations[i].translation,
                              pairIndex: _selectedWords.indexWhere(
                                (w) => w.id == _shuffledTranslations[i].id,
                              ),
                              isEnglish: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onTileTap(int pairIndex, bool isEnglish) async {
    if (pairIndex >= 0 && _matchedPairIndices.contains(pairIndex)) return;
    if (pairIndex >= 0 && _temporaryHideIndices.contains(pairIndex)) return;

    final controller = ref.read(dotsProvider.notifier);

    if (_firstIndex == null) {
      setState(() {
        _firstIndex = pairIndex;
        _firstIsEnglish = isEnglish;
        _lastResult = null;
      });
      return;
    }

    if (_secondIndex != null) return;

    // Deselect if tapping the same tile again
    if (_firstIndex == pairIndex && _firstIsEnglish == isEnglish) {
      setState(() {
        _firstIndex = null;
        _firstIsEnglish = null;
        _lastResult = null;
      });
      return;
    }
    if (_firstIsEnglish == isEnglish) {
      setState(() {
        _firstIndex = pairIndex;
        _firstIsEnglish = isEnglish;
        _secondIndex = null;
        _secondIsEnglish = null;
        _lastResult = null;
      });
      return;
    }

    final isMatch =
        (_firstIndex == pairIndex) && (_firstIsEnglish != isEnglish);
    final capturedFirstIndex = _firstIndex!;

    setState(() {
      _secondIndex = pairIndex;
      _secondIsEnglish = isEnglish;
      _lastResult = isMatch;
    });

    controller.markAnswer(isCorrect: isMatch);
    // Safely get current word for result tracking
    final learningWords = ref.read(learningWordsProvider);
    final currentIdx = ref.read(currentWordIndexProvider);
    final String currentWord;
    final String currentTranslation;
    final int currentId;
    if (capturedFirstIndex >= 0 && capturedFirstIndex < _selectedWords.length) {
      currentWord = _selectedWords[capturedFirstIndex].word;
      currentTranslation = _selectedWords[capturedFirstIndex].translation;
      currentId = _selectedWords[capturedFirstIndex].id;
    } else if (currentIdx >= 0 && currentIdx < learningWords.length) {
      currentWord = learningWords[currentIdx].word;
      currentTranslation = learningWords[currentIdx].translation;
      currentId = learningWords[currentIdx].id;
    } else {
      currentWord = '';
      currentTranslation = '';
      currentId = 0;
    }
    ref
        .read(gameResultProvider.notifier)
        .addResult(
          word: currentWord,
          translation: currentTranslation,
          isCorrect: isMatch,
          gameIndex: 2,
          wordId: currentId,
          gameName: GameNames.memoria,
        );
    try {
      if (isMatch) {
        await AudioHelper.playCorrect();
      } else {
        await AudioHelper.playWrong();
      }
    } catch (e) {
      debugPrint('Audio error (ignored): $e');
    }

    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      if (isMatch) {
        _matchedPairIndices.add(capturedFirstIndex);
      } else {
        _temporaryHideIndices.add(capturedFirstIndex);
        // Show feedback only if both indices are valid
        if (capturedFirstIndex >= 0 && capturedFirstIndex < _selectedWords.length &&
            pairIndex >= 0 && pairIndex < _selectedWords.length) {
          // We need to show dialog after setState, so we set a flag
        } else if (capturedFirstIndex >= 0 && capturedFirstIndex < _selectedWords.length) {
          // One is valid, one is dummy (-1)
        }
      }
      _firstIndex = null;
      _secondIndex = null;
      _firstIsEnglish = null;
      _secondIsEnglish = null;
    });

    // Show feedback dialog AFTER setState and await it
    if (!isMatch) {
      if (capturedFirstIndex >= 0 && capturedFirstIndex < _selectedWords.length &&
          pairIndex >= 0 && pairIndex < _selectedWords.length) {
        await showAnswerFeedback(
          context,
          userAnswer: _selectedWords[pairIndex].word,
          userTranslation: _selectedWords[pairIndex].translation,
          correctAnswer: _selectedWords[capturedFirstIndex].word,
          correctTranslation: _selectedWords[capturedFirstIndex].translation,
          categoryId: _selectedWords[capturedFirstIndex].categoryId,
        );
      } else if (capturedFirstIndex >= 0 && capturedFirstIndex < _selectedWords.length) {
        await showAnswerFeedback(
          context,
          userAnswer: currentWord,
          userTranslation: currentTranslation,
          correctAnswer: _selectedWords[capturedFirstIndex].word,
          correctTranslation: _selectedWords[capturedFirstIndex].translation,
          categoryId: _selectedWords[capturedFirstIndex].categoryId,
        );
      }
    }
    if (!mounted) return;

    // Advance word index; when all matched — next game stage
    final idx = ref.read(currentWordIndexProvider);
    final stage = ref.read(gameStageProvider);
    if (idx < _selectedWords.length - 1) {
      ref.read(currentWordIndexProvider.notifier).set(idx + 1);
    } else {
      // All assigned words played — move to next game stage
      debugPrint('🎮 [MatchGame] All ${_selectedWords.length} words done, next stage');
      ref.read(currentWordIndexProvider.notifier).set(0);
      ref.read(gameStageProvider.notifier).set(getNextStage(stage, ref));
    }
  }

  Color _backgroundColor(int pairIndex, bool isEnglish) {
    if (_matchedPairIndices.contains(pairIndex)) {
      return Color(0xFFF0FDF4);
    }
    if ((_firstIndex == pairIndex && _firstIsEnglish == isEnglish) ||
        (_secondIndex == pairIndex && _secondIsEnglish == isEnglish)) {
      if (_lastResult == true) return Color(0xFFF0FDF4);
      if (_lastResult == false) return Color(0xFFFEF2F2);
      return isEnglish ? Color(0xFFB2DDFF) : Color(0xFFEEF2F6);
    }
    return isEnglish ? Color(0xFFD1E9FF) : Colors.white;
  }

  Color _borderColor(int pairIndex, bool isEnglish) {
    if (_matchedPairIndices.contains(pairIndex)) {
      return Color(0xFF4ADE80);
    }
    if ((_firstIndex == pairIndex && _firstIsEnglish == isEnglish) ||
        (_secondIndex == pairIndex && _secondIsEnglish == isEnglish)) {
      if (_lastResult == true) return Color(0xFF4ADE80);
      if (_lastResult == false) return Color(0xFFF87171);
      return isEnglish ? Color(0xFF84CAFF) : Color(0xFFCDD5DF);
    }
    return isEnglish ? Color(0xFFB2DDFF) : Color(0xFFE3E8EF);
  }

  Widget _buildMatchTile({
    required String text,
    required int pairIndex,
    required bool isEnglish,
  }) {
    final bgColor = _backgroundColor(pairIndex, isEnglish);
    final borderColor = _borderColor(pairIndex, isEnglish);
    if (_matchedPairIndices.contains(pairIndex) ||
        _temporaryHideIndices.contains(pairIndex)) {
      return const SizedBox(height: 80);
    }

    // Dynamic font size based on text length
    final double fontSize;
    final int maxLines;
    if (text.length > 30) {
      fontSize = 12;
      maxLines = 3;
    } else if (text.length > 20) {
      fontSize = 13;
      maxLines = 2;
    } else {
      fontSize = 16;
      maxLines = 2;
    }

    return GestureDetector(
      onTap: () => _onTileTap(pairIndex, isEnglish),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            bottom: BorderSide(
              color: borderColor,
              width: (_firstIndex == pairIndex && _firstIsEnglish == isEnglish)
                  ? 2
                  : 6,
            ),
            right: BorderSide(color: borderColor, width: 2),
            left: BorderSide(color: borderColor, width: 2),
            top: BorderSide(color: borderColor, width: 2),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bigTextStyle.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: Color(0xFF202939),
          ),
        ),
      ),
    );
  }
}
