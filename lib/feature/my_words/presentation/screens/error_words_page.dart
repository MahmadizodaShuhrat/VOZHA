import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import 'package:vozhaomuz/shared/widgets/energy_paywall_dialog.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Page showing error words for a specific category.
/// Mirrors Unity's UISelectionWordsPage (WithPage="Errors") → UIViewWordsBeforeGames → UIGames.
class ErrorWordsPage extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;
  final String? categoryIconUrl;
  final List<WordProgress> errorWords;

  const ErrorWordsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.categoryIconUrl,
    required this.errorWords,
  });

  @override
  ConsumerState<ErrorWordsPage> createState() => _ErrorWordsPageState();
}

class _ErrorWordsPageState extends ConsumerState<ErrorWordsPage> {
  late final AudioPlayer _player;
  bool _enriching = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _setupAudioContext();
    _enrichWords();
  }

  /// Fill in missing word text from category DB
  /// Backend may send WordOriginal/WordTranslate as empty strings
  Future<void> _enrichWords() async {
    // Check if any word has empty text
    final needsEnrich = widget.errorWords.any(
      (w) => w.original.isEmpty || w.translate.isEmpty,
    );
    if (!needsEnrich) {
      if (mounted) setState(() => _enriching = false);
      return;
    }

    // Load full Word objects from category DB
    final categoryWords = await CategoryDbHelper.getWordsForCategory(
      widget.categoryId,
    );
    final wordMap = <int, Word>{};
    for (final w in categoryWords) {
      wordMap[w.id] = w;
    }

    // Enrich WordProgress objects
    for (final wp in widget.errorWords) {
      final fullWord = wordMap[wp.wordId];
      if (fullWord != null) {
        if (wp.original.isEmpty) wp.original = fullWord.word;
        if (wp.translate.isEmpty) wp.translate = fullWord.translation;
        if (wp.transcription.isEmpty) wp.transcription = fullWord.transcription;
      }
    }

    if (mounted) setState(() => _enriching = false);
  }

  /// Set AudioContext so AudioHelper can find audio files from the course bundle
  Future<void> _setupAudioContext() async {
    final coursePath = await CategoryResourceService.getCoursePath(
      widget.categoryId,
    );
    if (coursePath != null) {
      AudioContext.currentLessonDir = coursePath;
      debugPrint('🔊 [ErrorWords] AudioContext.currentLessonDir = $coursePath');
    } else {
      debugPrint(
        '⚠️ [ErrorWords] Course not found for category ${widget.categoryId}',
      );
    }
  }

  /// Play word audio — mirrors Unity's AudioManager.Instance.PlayClip(Word.Voice)
  Future<void> _playWordAudio(WordProgress word) async {
    final wordName = word.original.isNotEmpty ? word.original : 'unknown';
    debugPrint('🔊 [ErrorWords] Playing audio for: $wordName');
    await AudioHelper.playWord(
      _player,
      '',
      '$wordName.mp3',
      categoryId: word.categoryId,
    );
  }

  /// Convert WordProgress to Word model for the training flow
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

  /// "Учить" button — mirrors Unity's UIViewWordsBeforeGames flow:
  /// Gets error words → user selects 4 via swipe cards → UIGames.
  ///
  /// Unity (UISelectionWordsPage.cs line 57):
  ///   Words = WordsManager.GetWordsErrorsByCategory(SelectedIdCategory);
  /// Then UIViewWordsBeforeGames shows these words as swipe cards.
  /// User swipes right on 4 words, then UIGames starts.
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

    // Build a lookup map: wordId → Word (with photoPath/audioPath)
    final wordMap = <int, Word>{};
    for (final w in categoryWords) {
      wordMap[w.id] = w;
    }

    // Convert error words to Word models, using the full data from category DB
    // This ensures photoPath and audioPath are set correctly
    final errorWordsAsWords = widget.errorWords.map((wp) {
      // Try to find the full word in the category DB
      final fullWord = wordMap[wp.wordId];
      if (fullWord != null) {
        return fullWord;
      }
      // Fallback: create Word without photoPath (shouldn't happen normally)
      return _wordProgressToWord(wp);
    }).toList();

    // Reset providers before navigating to word selection
    ref.read(learningWordsProvider.notifier).set([]);
    ref.read(learningPressCountProvider.notifier).set(0);
    ref.read(selectedCategoryProvider.notifier).set(widget.categoryId);
    ref.read(selectedSubcategoryProvider.notifier).set(null);
    ref.read(gameStageProvider.notifier).set(GameStage.flashcards);
    ref.read(currentWordIndexProvider.notifier).set(0);

    // Ensure AudioContext is set for audio playback
    final coursePath = await CategoryResourceService.getCoursePath(
      widget.categoryId,
    );
    if (coursePath != null) {
      AudioContext.currentLessonDir = coursePath;
    }

    // Navigate to word selection page with ONLY error words (with images!)
    // (like Unity's UIViewWordsBeforeGames.SetWords(errorWords))
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChoseLearnKnowPage(
            categoryId: widget.categoryId,
            preloadedWords: errorWordsAsWords,
          ),
        ),
      );
    }
  }

  /// Build category icon from network URL or fallback
  Widget _buildCategoryIcon(String? iconUrl) {
    const size = 48.0;
    if (iconUrl != null &&
        iconUrl.isNotEmpty &&
        (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: iconUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFD1E9FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFD1E9FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.menu_book,
            color: Color(0xFF5B8DEF),
            size: 26,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFD1E9FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.menu_book, color: Color(0xFF5B8DEF), size: 26),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
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
                  // Category icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildCategoryIcon(widget.categoryIconUrl),
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
                child: LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE3E8EF),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF5B8DEF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Word count ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${'my_errors'.tr()} — ${widget.errorWords.length} ${'words'.tr().toLowerCase()}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF314456),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Action cards ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Learn button — mirrors Unity UIButtonLearnWords
                  Expanded(
                    child: MyButton(
                      onPressed: _onLearnTap,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B8DEF), Color(0xFF4A7FE0)],
                      ),
                      backButtonColor: const Color(0xFF3A6BC9),
                      borderRadius: 14,
                      depth: 4,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_fix_high,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Learn'.tr(),
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
                              '${widget.errorWords.length}',
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
                  const SizedBox(width: 10),
                  // All words button — mirrors Unity's UIButtonViewCards
                  Expanded(
                    child: MyButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();

                        // Load full Word objects with photoPath/audioPath
                        final categoryWords =
                            await CategoryDbHelper.getWordsForCategory(
                              widget.categoryId,
                            );
                        final wordMap = <int, Word>{};
                        for (final w in categoryWords) {
                          wordMap[w.id] = w;
                        }
                        final errorWordsAsWords = widget.errorWords.map((wp) {
                          return wordMap[wp.wordId] ?? _wordProgressToWord(wp);
                        }).toList();

                        // Ensure AudioContext is set
                        final coursePath =
                            await CategoryResourceService.getCoursePath(
                              widget.categoryId,
                            );
                        if (coursePath != null) {
                          AudioContext.currentLessonDir = coursePath;
                        }

                        // Navigate to view-only card view (Unity's UIViewWordsCard)
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChoseLearnKnowPage(
                                categoryId: widget.categoryId,
                                preloadedWords: errorWordsAsWords,
                                viewOnly: true,
                              ),
                            ),
                          );
                        }
                      },
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB45FE5), Color(0xFF9B4FD0)],
                      ),
                      backButtonColor: const Color(0xFF7E3FB5),
                      borderRadius: 14,
                      depth: 4,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
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
                              '${widget.errorWords.length}',
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Word list ──
            Expanded(
              child: _enriching
                  ? const Center(child: CircularProgressIndicator())
                  : widget.errorWords.isEmpty
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
                      itemCount: widget.errorWords.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFEEF2F6)),
                      itemBuilder: (context, index) {
                        final word = widget.errorWords[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              // Speaker icon — plays word audio on tap
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
                                    color: Color(0xFF5B8DEF),
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

                              // Error indicator (red circle)
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    width: 3,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
