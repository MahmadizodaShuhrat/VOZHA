import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/choose_learn_know_page.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/segmented_circle_painter.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import 'package:vozhaomuz/shared/widgets/energy_paywall_dialog.dart';

/// Page showing learned words for a specific category.
/// Mirrors Unity's UISelectionWordsPage with WithPage="Learn".
///
/// Unity flow:
///   UIButtonLearnWords → UIViewWordsBeforeGames(Words) → select 4 → UIGames
///   UIButtonViewCards  → UIViewWordsCard(Words) — view-only flashcards
///   Each word shows: WordOriginal, WordTranslate, status, timeRepeat/requireRepeat
class LearnedWordsPage extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;
  final List<WordProgress> learnedWords;

  const LearnedWordsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.learnedWords,
  });

  @override
  ConsumerState<LearnedWordsPage> createState() => _LearnedWordsPageState();
}

class _LearnedWordsPageState extends ConsumerState<LearnedWordsPage> {
  late final AudioPlayer _player;
  bool _enriching = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _enrichWords();
  }

  /// Fill in missing word text from category DB
  Future<void> _enrichWords() async {
    final needsEnrich = widget.learnedWords.any(
      (w) => w.original.isEmpty || w.translate.isEmpty,
    );
    if (!needsEnrich) {
      if (mounted) setState(() => _enriching = false);
      return;
    }

    final categoryWords = await CategoryDbHelper.getWordsForCategory(
      widget.categoryId,
    );
    final wordMap = <int, Word>{};
    for (final w in categoryWords) {
      wordMap[w.id] = w;
    }

    for (final wp in widget.learnedWords) {
      final fullWord = wordMap[wp.wordId];
      if (fullWord != null) {
        if (wp.original.isEmpty) wp.original = fullWord.word;
        if (wp.translate.isEmpty) wp.translate = fullWord.translation;
        if (wp.transcription.isEmpty) wp.transcription = fullWord.transcription;
      }
    }

    if (mounted) setState(() => _enriching = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Play word audio
  Future<void> _playWordAudio(WordProgress word) async {
    final wordName = word.original.isNotEmpty ? word.original : 'unknown';
    await AudioHelper.playWord(
      _player,
      '',
      '$wordName.mp3',
      categoryId: word.categoryId,
    );
  }

  /// Convert WordProgress → Word model
  Word _wordProgressToWord(WordProgress wp) {
    return Word(
      id: wp.wordId,
      word: wp.original,
      translation: wp.translate,
      transcription: wp.transcription,
      status: '',
      categoryId: wp.categoryId,
    );
  }

  /// "Learn" button — mirrors Unity's UIButtonLearnWords.
  /// Unity: UIViewWordsBeforeGames.SetWords(Words) → select 4 → UIGames
  Future<void> _onLearnTap() async {
    HapticFeedback.lightImpact();

    // Energy gate — same check as the main "Learn" button on home. Premium
    // users are exempt; non-premium users with balance < 1 see the paywall
    // dialog instead of silently opening a session they can't finish.
    final canPlay = ref.read(energyProvider.notifier).canPlay();
    if (!canPlay) {
      if (mounted) await showEnergyPaywallDialog(context);
      return;
    }

    // Load full Word objects from category DB (with photoPath & audioPath)
    final categoryWords = await CategoryDbHelper.getWordsForCategory(
      widget.categoryId,
    );
    final wordMap = <int, Word>{};
    for (final w in categoryWords) {
      wordMap[w.id] = w;
    }

    final learnedAsWords = widget.learnedWords.map((wp) {
      return wordMap[wp.wordId] ?? _wordProgressToWord(wp);
    }).toList();

    // Reset providers
    ref.read(learningWordsProvider.notifier).set([]);
    ref.read(learningPressCountProvider.notifier).set(0);
    ref.read(selectedCategoryProvider.notifier).set(widget.categoryId);
    ref.read(selectedSubcategoryProvider.notifier).set(null);
    ref.read(gameStageProvider.notifier).set(GameStage.flashcards);
    ref.read(currentWordIndexProvider.notifier).set(0);

    final coursePath = await CategoryResourceService.getCoursePath(
      widget.categoryId,
    );
    if (coursePath != null) {
      AudioContext.currentLessonDir = coursePath;
    }

    // Navigate to word selection page with learned words
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChoseLearnKnowPage(
            categoryId: widget.categoryId,
            preloadedWords: learnedAsWords,
          ),
        ),
      );
    }
  }

  /// "Words" button — mirrors Unity's UIButtonViewCards.
  /// Unity: UIViewWordsCard.SetWords(Words) — view-only flashcards
  Future<void> _onWordsTap() async {
    HapticFeedback.lightImpact();

    final categoryWords = await CategoryDbHelper.getWordsForCategory(
      widget.categoryId,
    );
    final wordMap = <int, Word>{};
    for (final w in categoryWords) {
      wordMap[w.id] = w;
    }

    final learnedAsWords = widget.learnedWords.map((wp) {
      return wordMap[wp.wordId] ?? _wordProgressToWord(wp);
    }).toList();

    final coursePath = await CategoryResourceService.getCoursePath(
      widget.categoryId,
    );
    if (coursePath != null) {
      AudioContext.currentLessonDir = coursePath;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChoseLearnKnowPage(
            categoryId: widget.categoryId,
            preloadedWords: learnedAsWords,
            viewOnly: true,
          ),
        ),
      );
    }
  }

  /// Format time remaining (Unity's dd/hh/mm logic from UISelectionWordsPage)
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back button ──
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, size: 24),
              ),
            ),

            // ── Category header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.categoryName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF314456),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 8,
                  backgroundColor: Color(0xFFE3E8EF),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Word count ── (Unity: "General words X / Y")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${'words_learned_count'.tr()} — ${widget.learnedWords.where((w) => w.original.isNotEmpty).length} ${'words'.tr().toLowerCase()}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF314456),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Action buttons ── (Learn + View Cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Learn button (Unity: UIButtonLearnWords)
                  Expanded(
                    child: GestureDetector(
                      onTap: _onLearnTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'learn'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${widget.learnedWords.where((w) => w.original.isNotEmpty).length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // View cards button (Unity: UIButtonViewCards)
                  Expanded(
                    child: GestureDetector(
                      onTap: _onWordsTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5B8DEF), Color(0xFF4A7FE0)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.style_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'words'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${widget.learnedWords.where((w) => w.original.isNotEmpty).length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Word list ── (Unity's word items with status + time)
            Expanded(
              child: _enriching
                  ? const Center(child: CircularProgressIndicator())
                  : widget.learnedWords.isEmpty
                  ? Center(
                      child: Text(
                        'no_words_yet'.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8A97AB),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: widget.learnedWords.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFEEF2F6)),
                      itemBuilder: (context, index) {
                        final word = widget.learnedWords[index];
                        return _buildWordItem(word);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build word item — matches Unity's UIWordItemState.
  /// Shows: audio icon, word + translation, time remaining, status circle.
  /// Unity (UISelectionWordsPage.cs lines 120-157):
  ///   if (WithPage == "Learn" && CurrentLearningState < 4):
  ///     if hours > 0: SetTimeRepeat("Xд" / "Xч" / "Xм")
  ///     else: SetRequireRepeat()
  Widget _buildWordItem(WordProgress word) {
    // Skip words without text (category not downloaded yet)
    if (word.original.isEmpty) return const SizedBox.shrink();

    // Unity logic: only show time for WithPage="Learn" && state < 4
    String timeLabel = '';
    bool requireRepeat = false;
    final isNegative = word.state < 0;
    if (word.state < 4) {
      final diff = word.timeout.difference(DateTime.now());
      if (diff.isNegative) {
        requireRepeat = true; // Unity: SetRequireRepeat() → UIMarker3
      } else {
        timeLabel = _formatTimeLeft(word.timeout);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Speaker icon (plays audio)
          GestureDetector(
            onTap: () => _playWordAudio(word),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.volume_up_outlined,
                color: Color(0xFF22C55E),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Word + translation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.original,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF314456),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  word.translate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A97AB),
                  ),
                ),
              ],
            ),
          ),

          // Unity: UIMarker2 — warning for negative states
          if (isNegative && !requireRepeat && timeLabel.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFE6394F),
                size: 18,
              ),
            ),

          // Time remaining or "Repeat!" indicator (Unity: UIMarker3)
          if (requireRepeat)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('🔄', style: const TextStyle(fontSize: 14)),
            )
          else if (timeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                timeLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),

          // Status circle (Unity: SetStatus with 3 colored circles)
          // For locally known words — show special "Медонам" badge
          if (word.isKnownLocally)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E90FA).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_library_outlined,
                    color: Color(0xFF2E90FA),
                    size: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'I_already_know'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF2E90FA),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            )
          else
          SizedBox(
            width: 32,
            height: 32,
            child: word.state >= 4
                // Unity: UIMarker (check) for state ≥ 4
                ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF20CD7F).withValues(alpha: 0.3),
                        width: 3,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Color(0xFF20CD7F), size: 16),
                    ),
                  )
                // Unity: 3 colored circle segments based on state
                : CustomPaint(
                    painter: SegmentedCirclePainter(
                      strokeWidth: 3.0,
                      state: word.state,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
