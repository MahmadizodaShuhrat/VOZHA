import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/segmented_circle_painter.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

/// Page that groups repeat words into 4 sections (like Unity's UIRepeatWordsPage):
///   1. Today — words whose timeout has expired (ready for repeat now)
///   2. Level 1 — state=1, timeout not yet expired (1st repetition pending)
///   3. Level 2 — state=2, timeout not yet expired (2nd repetition pending)
///   4. Level 3 — state=3, timeout not yet expired (3rd repetition pending)
///
/// Each section shows max 4 word previews + "Show all" button.
/// "Show all" navigates to UIFilteredRepeatWordsPage-like full list page.
class RepeadWordPage extends ConsumerStatefulWidget {
  const RepeadWordPage({super.key});

  @override
  ConsumerState<RepeadWordPage> createState() => _RepeadWordPageState();
}

class _RepeadWordPageState extends ConsumerState<RepeadWordPage> {
  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);

    // Collect all words from all directions
    final List<WordProgress> allWords = [];
    for (final entry in progress.dirs.entries) {
      allWords.addAll(entry.value);
    }

    // ─── Group words like Unity's WordsManager.GroupByTodayRepeat ───
    final now = DateTime.now();

    // "Барои омӯзиш" — калимаҳое, ки корбар нодуруст ҷавоб додааст
    // (state ∈ [-3..0]) ё ҳанӯз амиқ омӯхта нашуда. Ин секция барои онҳо
    // алоҳида ҷудо карда мешавад: ба ҷои санҷидан тавассути бозиҳои
    // Repeat, чунин калимаҳо тавассути flashcards дар Learn-flow аз нав
    // нишон дода мешаванд (худкорона ба пеши сессия prepend мешаванд).
    final wordsToRelearn = allWords
        .where(
          (w) =>
              w.original.isNotEmpty &&
              w.state >= -3 &&
              w.state <= 0 &&
              !w.firstDone &&
              !w.timeout.isAfter(now),
        )
        .toList();

    // Today: timeout expired (ready to repeat), state 1..3, firstDone == false
    // Unity: (DateTime.Now - Timeout).TotalSeconds >= 0 && !IsFirstSubmitIsLearning && state != 4
    // Filter out words without text (category not downloaded)
    final wordsToday = allWords
        .where(
          (w) =>
              w.original.isNotEmpty &&
              w.state > 0 &&
              w.state < 4 &&
              !w.firstDone &&
              !w.timeout.isAfter(now),
        )
        .toList();

    // Level 1: state == 1 && timeout > now (waiting)
    final wordsLevel1 = allWords
        .where(
          (w) =>
              w.original.isNotEmpty &&
              w.state == 1 &&
              !w.firstDone &&
              w.timeout.isAfter(now),
        )
        .toList();

    // Level 2: state == 2 && timeout > now (waiting)
    final wordsLevel2 = allWords
        .where(
          (w) =>
              w.original.isNotEmpty &&
              w.state == 2 &&
              !w.firstDone &&
              w.timeout.isAfter(now),
        )
        .toList();

    // Level 3: state == 3 && timeout > now (waiting)
    final wordsLevel3 = allWords
        .where(
          (w) =>
              w.original.isNotEmpty &&
              w.state == 3 &&
              !w.firstDone &&
              w.timeout.isAfter(now),
        )
        .toList();

    final bool isEmpty =
        wordsToRelearn.isEmpty &&
        wordsToday.isEmpty &&
        wordsLevel1.isEmpty &&
        wordsLevel2.isEmpty &&
        wordsLevel3.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5FAFF),
        elevation: 0,
        title: Text(
          'words_to_repeat'.tr(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 28),
        ),
      ),
      body: isEmpty
          ? Center(child: Text('no_words_yet'.tr()))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              children: [
                // ─── Section: Барои омӯзиш (state ≤ 0, нодуруст ҷавоб) ───
                // Ҷои аввал — ин калимаҳо аввалин таваҷҷӯҳи корбарро
                // мехоҳанд: онҳо ба ҷараёни Learn (flashcards) бар мегарданд.
                if (wordsToRelearn.isNotEmpty)
                  _buildSection(
                    title: 'words_to_relearn'.tr(
                      args: ['${wordsToRelearn.length}'],
                    ),
                    words: wordsToRelearn,
                    showTimeout: false,
                    headerColor: const Color(0xFFEF4444),
                  ),

                // ─── Section: Today (ready to repeat) ───
                if (wordsToday.isNotEmpty)
                  _buildSection(
                    title: 'repetitions_today'.tr(
                      args: ['${wordsToday.length}'],
                    ),
                    words: wordsToday,
                    showTimeout: false,
                    headerColor: const Color(0xFF12B76A),
                  ),

                // ─── Section: Level 1 ───
                if (wordsLevel1.isNotEmpty)
                  _buildSection(
                    title: 'repetitions_first'.tr(
                      args: ['${wordsLevel1.length}'],
                    ),
                    words: wordsLevel1,
                    showTimeout: true,
                    headerColor: const Color(0xFFF9A628),
                  ),

                // ─── Section: Level 2 ───
                if (wordsLevel2.isNotEmpty)
                  _buildSection(
                    title: 'repetitions_second'.tr(
                      args: ['${wordsLevel2.length}'],
                    ),
                    words: wordsLevel2,
                    showTimeout: true,
                    headerColor: const Color(0xFF5B8DEF),
                  ),

                // ─── Section: Level 3 ───
                if (wordsLevel3.isNotEmpty)
                  _buildSection(
                    title: 'repetitions_third'.tr(
                      args: ['${wordsLevel3.length}'],
                    ),
                    words: wordsLevel3,
                    showTimeout: true,
                    headerColor: const Color(0xFF9B4FD0),
                  ),
              ],
            ),
    );
  }

  /// Builds a grouped section (like Unity's ContentToday / ContentLevel1 etc.)
  /// Shows header, max 4 words preview, and "Show all" button.
  Widget _buildSection({
    required String title,
    required List<WordProgress> words,
    required bool showTimeout,
    required Color headerColor,
  }) {
    final previewWords = words.sublist(0, min(words.length, 4));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: headerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: headerColor,
                  ),
                ),
              ),
              // "Show all" button (like Unity's UIButtonAllToday etc.)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FilteredRepeatWordsPage(
                        header: title,
                        words: words,
                        showTimeout: showTimeout,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'show_all'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: headerColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Preview cards (max 4, like Unity)
        ...previewWords.map(
          (word) => _buildRepeatCard(word, showTimeout: showTimeout),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds a word card matching Unity's UIWordItemState display.
  Widget _buildRepeatCard(WordProgress word, {required bool showTimeout}) {
    // Skip words without text (category not downloaded)
    if (word.original.isEmpty) return const SizedBox.shrink();

    final timeLeft = showTimeout ? _formatTimeLeft(word.timeout) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEEF2F6), width: 3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            // Word + translation
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.original,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    word.translate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            // Time left + state circle
            Row(
              children: [
                if (timeLeft.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      timeLeft,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
                _buildSegmentedCircle(
                  state: word.state,
                  size: 25.0,
                  strokeWidth: 3.0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Formats remaining time (matches Unity's dd/hh/mm logic).
  String _formatTimeLeft(DateTime timeout) {
    final diff = timeout.difference(DateTime.now());
    if (diff.isNegative) return '';

    final totalHours = diff.inHours;
    if (totalHours >= 24) {
      final days = totalHours ~/ 24;
      return 'time_days'.tr(args: ['$days']);
    } else if (totalHours > 0) {
      return 'time_hours'.tr(args: ['$totalHours']);
    } else {
      final minutes = diff.inMinutes;
      return 'time_minutes'.tr(args: ['$minutes']);
    }
  }



  Widget _buildSegmentedCircle({
    required int state,
    required double size,
    double strokeWidth = 5.0,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SegmentedCirclePainter(
          strokeWidth: strokeWidth,
          state: state,
        ),
      ),
    );
  }
}

// ─── Filtered Repeat Words Page (Unity's UIFilteredRepeatWordsPage) ───
// Full list of words in a single section.
class _FilteredRepeatWordsPage extends StatelessWidget {
  final String header;
  final List<WordProgress> words;
  final bool showTimeout;

  const _FilteredRepeatWordsPage({
    required this.header,
    required this.words,
    required this.showTimeout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5FAFF),
        elevation: 0,
        title: Text(
          header,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 28),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return _buildWordItem(word);
        },
      ),
    );
  }

  Widget _buildWordItem(WordProgress word) {
    if (word.original.isEmpty) return const SizedBox.shrink();

    final timeLeft = showTimeout ? _formatTimeLeft(word.timeout) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEEF2F6), width: 3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.original,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    word.translate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (timeLeft.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      timeLeft,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
                SizedBox(
                  width: 25,
                  height: 25,
                  child: CustomPaint(
                    painter: SegmentedCirclePainter(
                      strokeWidth: 3.0,
                      state: word.state,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeLeft(DateTime timeout) {
    final diff = timeout.difference(DateTime.now());
    if (diff.isNegative) return '';

    final totalHours = diff.inHours;
    if (totalHours >= 24) {
      final days = totalHours ~/ 24;
      return 'time_days'.tr(args: ['$days']);
    } else if (totalHours > 0) {
      return 'time_hours'.tr(args: ['$totalHours']);
    } else {
      final minutes = diff.inMinutes;
      return 'time_minutes'.tr(args: ['$minutes']);
    }
  }


}
