import 'dart:math';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart'; // For AudioContext
import 'package:vozhaomuz/core/database/data_base_helper.dart'; // For Word class
import 'package:vozhaomuz/feature/games/data/remember_new_words_repository.dart'; // For learned words API
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart'; // For locale
import 'package:vozhaomuz/feature/courses/data/models/course_models.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/trenirovka_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/close_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

// Providers for course word learning flow
final courseLearningWordsProvider =
    NotifierProvider<CourseLearningWordsNotifier, List<CourseWord>>(
      CourseLearningWordsNotifier.new,
    );

class CourseLearningWordsNotifier extends Notifier<List<CourseWord>> {
  @override
  List<CourseWord> build() => [];
  void set(List<CourseWord> value) => state = value;
}

final courseCurrentIndexProvider =
    NotifierProvider<CourseCurrentIndexNotifier, int>(
      CourseCurrentIndexNotifier.new,
    );

class CourseCurrentIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}

final courseLearningCountProvider =
    NotifierProvider<CourseLearningCountNotifier, int>(
      CourseLearningCountNotifier.new,
    );

class CourseLearningCountNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
  void increment() => state++;
}

final courseLessonDirProvider =
    NotifierProvider<CourseLessonDirNotifier, String?>(
      CourseLessonDirNotifier.new,
    );

class CourseLessonDirNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

/// Get translation for CourseWord based on current locale
/// Returns Russian translation when interface is Russian, otherwise Tajik (default)
String getTranslationForLocale(CourseWord word, String localeCode) {
  if (localeCode == 'ru') {
    // Russian interface - prefer Russian translation
    return word.translations['Russian'] ?? word.translation;
  }
  // Tajik interface or fallback
  return word.translations['Tajik'] ?? word.translation;
}

/// Page for selecting words to learn from a course (swipe cards interface)
class CourseLearnKnowPage extends ConsumerStatefulWidget {
  final List<CourseWord> words;
  final String lessonTitle;
  final String lessonDir;

  const CourseLearnKnowPage({
    required this.words,
    required this.lessonTitle,
    required this.lessonDir,
    super.key,
  });

  @override
  ConsumerState<CourseLearnKnowPage> createState() =>
      _CourseLearnKnowPageState();
}

class _CourseLearnKnowPageState extends ConsumerState<CourseLearnKnowPage> {
  late List<CourseWord> _remainingWords;
  Set<int> _learnedWordIds = {};
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _lastPlayedIndex;

  @override
  void initState() {
    super.initState();
    _remainingWords = List.from(widget.words);

    // Reset providers
    Future.microtask(() {
      ref.read(courseLearningWordsProvider.notifier).set([]);
      ref.read(courseCurrentIndexProvider.notifier).set(0);
      ref.read(courseLearningCountProvider.notifier).set(0);
      ref.read(courseLessonDirProvider.notifier).set(widget.lessonDir);

      // Set audio context so AudioHelper knows where to load audio from
      AudioContext.currentLessonDir = widget.lessonDir;

      _loadLearnedWordsAndFilter();
    });
  }

  /// Fetch learned word IDs from server and filter them out
  Future<void> _loadLearnedWordsAndFilter() async {
    debugPrint('📚 [CourseLearnKnow] Starting word selection...');
    debugPrint(
      '📚 [CourseLearnKnow] Total words in lesson: ${widget.words.length}',
    );

    try {
      // Import and call repository
      final repo = RememberNewWordsRepository(baseUrl: ApiConstants.baseUrl);
      final progress = await repo.getUserProgressWords();

      if (progress != null) {
        // Server returns Dictionary<string, List> where key is learning language (e.g., "EnToRu")
        // Each entry has: WordId, CategoryId, CurrentLearningState, Timeout, IsFirstSubmitIsLearning, ErrorInGames
        debugPrint(
          '📋 [CourseLearnKnow] Response keys: ${progress.keys.toList()}',
        );

        // Collect all learned word IDs from all languages where CurrentLearningState >= 1
        final Set<int> learnedIds = {};

        for (final entry in progress.entries) {
          final langKey = entry.key;
          final wordsData = entry.value;

          debugPrint('🔍 [CourseLearnKnow] Processing language: $langKey');

          if (wordsData is List) {
            for (final word in wordsData) {
              if (word is Map) {
                // Check for WordId (case variations)
                final wordId =
                    word['WordId'] ?? word['wordId'] ?? word['WordID'];
                final state =
                    word['CurrentLearningState'] ??
                    word['currentLearningState'] ??
                    0;

                if (wordId != null) {
                  final id = wordId is int
                      ? wordId
                      : int.tryParse(wordId.toString());
                  final stateInt = state is int
                      ? state
                      : int.tryParse(state.toString()) ?? 0;

                  // Filter words with state >= 1 (learned)
                  if (id != null && stateInt >= 1) {
                    learnedIds.add(id);
                    debugPrint('   ✅ WordId: $id, State: $stateInt (learned)');
                  }
                }
              }
            }
          } else if (wordsData is Map && wordsData.containsKey('Rows')) {
            // Handle DataTable format (Rows array)
            final rows = wordsData['Rows'] as List?;
            if (rows != null) {
              for (final row in rows) {
                if (row is Map) {
                  final wordId =
                      row['WordId'] ?? row['wordId'] ?? row['WordID'];
                  final state =
                      row['CurrentLearningState'] ??
                      row['currentLearningState'] ??
                      0;

                  if (wordId != null) {
                    final id = wordId is int
                        ? wordId
                        : int.tryParse(wordId.toString());
                    final stateInt = state is int
                        ? state
                        : int.tryParse(state.toString()) ?? 0;

                    if (id != null && stateInt >= 1) {
                      learnedIds.add(id);
                    }
                  }
                }
              }
            }
          }
        }

        _learnedWordIds = learnedIds;
        debugPrint(
          '✅ [CourseLearnKnow] Total learned word IDs: ${_learnedWordIds.length}',
        );
        debugPrint(
          '📋 [CourseLearnKnow] Learned IDs: ${_learnedWordIds.take(10).join(", ")}${_learnedWordIds.length > 10 ? "..." : ""}',
        );

        // Separate new and learned words
        final beforeCount = _remainingWords.length;
        final newWords = _remainingWords
            .where((w) => !_learnedWordIds.contains(w.id))
            .toList();
        final learnedWords = _remainingWords
            .where((w) => _learnedWordIds.contains(w.id))
            .toList();

        debugPrint(
          '🔍 [CourseLearnKnow] Filtered: $beforeCount → ${newWords.length} new words (${learnedWords.length} learned)',
        );

        // Always ensure at least 4 words: if new words < 4, add back some learned words
        _remainingWords = List.from(newWords);
        if (_remainingWords.length < 4 && learnedWords.isNotEmpty) {
          learnedWords.shuffle(Random());
          final needed = 4 - _remainingWords.length;
          _remainingWords.addAll(learnedWords.take(needed));
          debugPrint(
            '➕ [CourseLearnKnow] Added $needed learned words to reach 4 total',
          );
        }
      } else {
        debugPrint(
          '⚠️ [CourseLearnKnow] No learned words data from server or empty response',
        );
      }
    } catch (e, st) {
      debugPrint('❌ [CourseLearnKnow] Error loading learned words: $e');
      debugPrint('❌ [CourseLearnKnow] Stack trace: $st');
    }

    // Shuffle remaining words for random order
    _remainingWords.shuffle(Random());
    debugPrint(
      '🎲 [CourseLearnKnow] Shuffled ${_remainingWords.length} remaining words',
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playWordAudio(CourseWord word) {
    final fileName = '${word.word.toLowerCase()}.mp3';
    AudioHelper.playWord(_audioPlayer, '', fileName);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = ref.watch(courseLearningCountProvider);
    final currentIndex = ref.watch(courseCurrentIndexProvider);

    return WillPopScope(
      onWillPop: () async {
        showExitConfirmationDialog(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close, color: Colors.black, size: 30),
          ),
          backgroundColor: const Color(0xFFF8FAFF),
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "selected".tr(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                " $selectedCount ",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "of ".tr(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "4",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 50),
            ],
          ),
        ),
        body: _buildBody(currentIndex),
      ),
    );
  }

  Widget _buildBody(int currentIndex) {
    // Show loading while fetching learned words
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('loading_words'.tr(), style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    if (_remainingWords.isEmpty) {
      return Center(child: Text('words_finished'.tr()));
    }

    if (currentIndex >= _remainingWords.length) {
      ref.read(courseCurrentIndexProvider.notifier).set(0);
      return const Center(child: CircularProgressIndicator());
    }

    final word = _remainingWords[currentIndex];

    // Auto-play audio when card changes
    if (_lastPlayedIndex != currentIndex) {
      _lastPlayedIndex = currentIndex;
      Future.microtask(() => _playWordAudio(word));
    }

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 30, top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lessonTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Expanded(child: Center(child: _buildWordCard(word))),
                  const SizedBox(height: 20),
                  _buildKnowButton(word, currentIndex),
                  const SizedBox(height: 20),
                  _buildLearnButton(word, currentIndex),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(CourseWord word) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(bottom: 120),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEEF2F6), width: 6),
          right: BorderSide(color: Color(0xFFEEF2F6), width: 2),
          top: BorderSide(color: Color(0xFFEEF2F6), width: 2),
          left: BorderSide(color: Color(0xFFEEF2F6), width: 2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _playWordAudio(word),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 35,
                    color: Color(0xFF2E90FA),
                  ),
                ),
              ],
            ),
          ),
          // Word placeholder image area
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: 64,
                color: Color(0xFFB0BEC5),
              ),
              // child: Image.asset('assets/images/image 234.png', width: 120, height: 120),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            word.word.replaceAll(RegExp(r'_\d+$'), ''),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          if (word.transcription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '[${word.transcription}]',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            getTranslationForLocale(
              word,
              ref.read(localeProvider).languageCode,
            ),
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),

          // const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildKnowButton(CourseWord word, int currentIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: MyButton(
        width: double.infinity,
        buttonColor: const Color(0xFFFDE047),
        backButtonColor: const Color(0xFFEAB308),
        child: Center(
          child: Text(
            'I_already_know'.tr(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          _nextWord(currentIndex);
        },
      ),
    );
  }

  Widget _buildLearnButton(CourseWord word, int currentIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: MyButton(
        width: double.infinity,
        buttonColor: const Color(0xFF2E90FA),
        backButtonColor: const Color(0xFF1570EF),
        child: Center(
          child: Text(
            'Learn'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();

          // Add word to learning list
          final currentList = ref.read(courseLearningWordsProvider);
          if (!currentList.any((w) => w.word == word.word)) {
            final updated = [...currentList, word];
            ref
                .read(courseLearningWordsProvider.notifier)
                .set(
                  updated.length > 4
                      ? updated.sublist(updated.length - 4)
                      : updated,
                );

            // Only increment counter if word was actually added
            final count = ref.read(courseLearningCountProvider.notifier);
            count.increment();

            // Navigate to training if enough words selected
            // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
            if (count.state >= 4) {
              count.set(0);

              // Convert CourseWord to Word for game compatibility
              final courseWords = ref.read(courseLearningWordsProvider);
              final localeCode = ref.read(localeProvider).languageCode;

              // Log selected words
              debugPrint(
                '🎯 [CourseLearnKnow] Selected 4 words for training (locale=$localeCode):',
              );
              for (int i = 0; i < courseWords.length; i++) {
                final cw = courseWords[i];
                final translation = getTranslationForLocale(cw, localeCode);
                debugPrint(
                  '   ${i + 1}. ID: ${cw.id}, Word: ${cw.word}, Translation: $translation',
                );
              }

              // Use real CourseWord.id, not array index!
              // Use correct translation based on locale
              // Extract categoryId from wordId (e.g., 470001 -> 47)
              final words = courseWords
                  .map(
                    (cw) => Word(
                      id: cw.id, // Real ID from course JSON
                      word: cw.word,
                      translation: getTranslationForLocale(cw, localeCode),
                      transcription: cw.transcription,
                      status: 'learning',
                      categoryId:
                          cw.id ~/
                          10000, // Extract category from ID: 470001 -> 47
                    ),
                  )
                  .toList();

              debugPrint(
                '📋 [CourseLearnKnow] Word IDs being passed to games: ${words.map((w) => "${w.id} (cat:${w.categoryId})").toList()}',
              );

              // Set the learningWordsProvider for game flow
              ref.read(learningWordsProvider.notifier).set(words);

              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TrenirovkaPage()),
                );
              }
            } else {
              _nextWord(currentIndex);
            }
          } else {
            // Word already in list, just move to next
            _nextWord(currentIndex);
          }
        },
      ),
    );
  }

  void _nextWord(int currentIndex) {
    if (currentIndex + 1 < _remainingWords.length) {
      ref.read(courseCurrentIndexProvider.notifier).set(currentIndex + 1);
    } else {
      ref.read(courseCurrentIndexProvider.notifier).set(0);
    }
  }
}
