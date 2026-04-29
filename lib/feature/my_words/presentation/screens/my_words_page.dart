import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vozhaomuz/core/constants/app_colors.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/learned_categories_dialog.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/import_words_dialog.dart';
import 'package:vozhaomuz/feature/my_words/presentation/screens/add_word_page.dart';
import 'package:vozhaomuz/feature/my_words/presentation/screens/repeat_word_page.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/add_words_button.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/error_categories_dialog.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class MyWordsPage extends ConsumerStatefulWidget {
  final List<Map<String, String>> addWords;
  const MyWordsPage({super.key, this.addWords = const []});

  @override
  ConsumerState<MyWordsPage> createState() => _MyWordsPageState();
}

class _MyWordsPageState extends ConsumerState<MyWordsPage> {
  /// All words loaded from documents/lessons/ JSON files
  List<ImportedWord> _addedWords = [];
  bool _wordsLoading = true;
  bool _progressLoading = true;
  ProviderSubscription? _progressSub;
  int _knownWordCount = 0;

  @override
  void initState() {
    super.initState();

    // Fetch fresh progress data from the backend (fire-and-forget)
    Future.microtask(() {
      ref.read(progressProvider.notifier).fetchProgressFromBackend();
    });

    // Listen for when progress data actually arrives (dirs becomes non-empty)
    _progressSub = ref.listenManual(progressProvider, (prev, next) {
      if (_progressLoading && next.dirs.isNotEmpty) {
        setState(() => _progressLoading = false);
      }
    });

    // Load user-added words from lessons directory
    _loadAddedWords();

    // Load locally known word count
    _loadKnownWordCount();
  }

  Future<void> _loadKnownWordCount() async {
    final knownIds = await DatabaseHelper.getKnownWordIds();
    if (mounted) {
      setState(() => _knownWordCount = knownIds.length);
    }
  }

  @override
  void dispose() {
    _progressSub?.close();
    super.dispose();
  }

  /// Load all words from saved lessons in documents/lessons/
  /// Mirrors Unity's UIMyLessonsPage.ResetPakFiles() which reads .vozha files
  Future<void> _loadAddedWords() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final lessonsDir = Directory('${appDir.path}/lessons');

      if (!await lessonsDir.exists()) {
        if (mounted) {
          setState(() {
            _addedWords = [];
            _wordsLoading = false;
          });
        }
        return;
      }

      final List<ImportedWord> allWords = [];
      final files = await lessonsDir.list().toList();

      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final jsonData = json.decode(content) as Map<String, dynamic>;
            final lesson = ImportedLesson.fromJson(jsonData);
            allWords.addAll(lesson.words);
          } catch (e) {
            debugPrint('⚠️ [MyWordsPage] Failed to parse lesson file ${entity.path}: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _addedWords = allWords;
          _wordsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _addedWords = [];
          _wordsLoading = false;
        });
      }
    }
  }

  /// Shimmer placeholders for the 4 dashboard cards while progress loads
  Widget _buildShimmerCards() {
    Widget shimmerCard() {
      return Expanded(
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade50,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Container(
                      width: 45,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Row(children: [shimmerCard(), const SizedBox(width: 10), shimmerCard()]),
          const SizedBox(height: 10),
          Row(children: [shimmerCard(), const SizedBox(width: 10), shimmerCard()]),
        ],
      ),
    );
  }

  /// Pull-to-refresh: reload progress from backend + reload saved words
  Future<void> _refreshData() async {
    await Future.wait([
      ref.read(progressProvider.notifier).fetchProgressFromBackend(),
      _loadAddedWords(),
      _loadKnownWordCount(),
    ]);
  }

  /// Compute word counts from progress state
  /// Unity: IsWordLearned = State > 0 && !IsFirstSubmitIsLearning
  Map<String, int> _computeWordCounts() {
    final progress = ref.watch(progressProvider);
    int learned = 0;
    int errors = 0;
    int toRepeat = 0;

    for (final entry in progress.dirs.values) {
      for (final word in entry) {
        // Unity: IsWordLearned = State > 0 && !IsFirstSubmitIsLearning
        if (word.state > 0 && !word.firstDone) learned++;
        if (word.state < 0) errors++;
        if (!word.firstDone &&
            word.state >= -3 &&
            word.state <= 3 &&
            DateTime.now().isAfter(word.timeout)) {
          toRepeat++;
        }
      }
    }
    // Include locally known words ("Медонам")
    learned += _knownWordCount;
    return {'learned': learned, 'errors': errors, 'toRepeat': toRepeat};
  }

  @override
  Widget build(BuildContext context) {
    final counts = _computeWordCounts();

    return Scaffold(
      backgroundColor: AppColors.screenColors,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 40),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'my_words'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        importWordsDialog(context);
                      },
                      child: Text(
                        'import_words'.tr(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // ── Dashboard Cards ──
                _progressLoading
                    ? _buildShimmerCards()
                    : SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Card 1: My Errors
                                Expanded(
                                  child: _buildCard(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE8F4FF),
                                        Color(0xFFE7EFF8),
                                        Color(0xFFF8D2D9),
                                      ],
                                    ),
                                    icon: Icons.book_outlined,
                                    iconColor: Colors.red,
                                    text1: 'n_words'.tr(
                                      args: ['${counts['errors']}'],
                                    ),
                                    text2: 'my_errors'.tr(),
                                    backButtonColor: const Color(0xFFF8D2D2),
                                    textSize: 14,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      alertDialogWidget(context);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Card 2: Words Learned
                                Expanded(
                                  child: _buildCard(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE8F4FF),
                                        Color(0xFFE7EFF8),
                                        Color(0xFFCCFFD7),
                                      ],
                                    ),
                                    icon: Icons.check_circle_outline,
                                    iconColor: Colors.green,
                                    text1: 'n_words'.tr(
                                      args: ['${counts['learned']}'],
                                    ),
                                    text2: 'words_learned_count'.tr(),
                                    backButtonColor: const Color(0xFFCCFFD7),
                                    textSize: 12,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      learnedWordsDialogWidget(context);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Card 3: Words to Repeat
                                Expanded(
                                  child: _buildCard(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFDE047), Color(0xFFF9A628)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    icon: Icons.replay_circle_filled,
                                    iconColor: Colors.white,
                                    text1: 'n_words'.tr(
                                      args: ['${counts['toRepeat']}'],
                                    ),
                                    text2: 'words_to_repeat'.tr(),
                                    textColor: Colors.white,
                                    backButtonColor: const Color(0xFFCA8A04),
                                    textSize: 12,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RepeadWordPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Card 4: Add Words
                                Expanded(
                                  child: AddWordsButtonWidget(
                                    backButtonColor: Colors.blue,
                                    color: const Color.fromARGB(255, 97, 184, 255),
                                    text: 'add_words'.tr(),
                                    textColor: Colors.white,
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AddWordPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                const SizedBox(height: 30),

                // ── Section Label ──
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'my_words'.tr(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        height: 3,
                        width: 83,
                        decoration: const BoxDecoration(color: Colors.blue),
                      ),
                    ],
                  ),
                ),

                // ── Word List: only user-added words from lessons ──
                Builder(
                  builder: (context) {
                    if (_wordsLoading) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_addedWords.isEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 100),
                          Image.asset(
                            'assets/images/bookremove.png',
                            width: 80,
                            height: 80,
                          ),
                          Text(
                            'no_words_yet'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _addedWords.length,
                      itemBuilder: (context, index) {
                        final word = _addedWords[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                              bottom: BorderSide(
                                color: Color(0xFFCDD5DF),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            child: Row(
                              children: [
                                // Blue indicator for user-added words
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        word.wordOriginal,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              word.wordTranslate,
                                              style: const TextStyle(
                                                color: Color(0xFF8A97AB),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (word
                                              .wordTranscription
                                              .isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '[${word.wordTranscription}]',
                                              style: const TextStyle(
                                                color: Color(0xFFB0B8C4),
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // "Хатогиҳои ман" badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'my_words'.tr(),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildCard({
  required Gradient gradient,
  required IconData icon,
  required Color iconColor,
  required String text1,
  required String text2,
  Color textColor = Colors.black,
  required Color backButtonColor,
  required double textSize,
  final void Function()? onPressed,
}) {
  return MyButton(
    height: 90,
    depth: 4,
    borderRadius: 12,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    gradient: gradient,
    backButtonColor: backButtonColor,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: iconColor, size: 23),
            if (text1.isNotEmpty)
              Text(
                text1,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        Text(
          text2,
          style: TextStyle(
            fontSize: textSize,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
    onPressed: onPressed,
  );
}
