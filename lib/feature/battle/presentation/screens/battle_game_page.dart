import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/battle/data/member_dto.dart';
import 'package:vozhaomuz/feature/battle/data/question_data.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/core/services/dummy_words_service.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/battle_download_dialog.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/games/choose_translation_game.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/games/choose_by_audio_game.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/games/listen_and_choose_game.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/games/assemble_word_game.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/games/pronounce_word_game.dart';

/// Р­РєСЂР°РЅ РёРіСЂС‹ вЂ” РґРёР·Р°Р№РЅ Unity 3D:
/// РіРѕСЂРѕРґ + РѕР±Р»Р°РєР°, РјР°С€РёРЅРєРё РЅР° РґРѕСЂРѕР¶РєР°С…, С‚Р°Р№РјРµСЂ.
/// РќРµСЃРєРѕР»СЊРєРѕ С‚РёРїРѕРІ РёРіСЂ: В«Р’С‹Р±РµСЂРё РїРµСЂРµРІРѕРґВ» Рё В«РЎРѕР±РµСЂРё СЃР»РѕРІРѕВ».
class BattleGamePage extends ConsumerStatefulWidget {
  const BattleGamePage({super.key});

  @override
  ConsumerState<BattleGamePage> createState() => _BattleGamePageState();
}

// в”Ђв”Ђв”Ђ РўРёРїС‹ Рё РґР°РЅРЅС‹Рµ РІРѕРїСЂРѕСЃРѕРІ РІС‹РЅРµСЃРµРЅС‹ РІ question_data.dart в”Ђв”Ђв”Ђ

// в”Ђв”Ђв”Ђ Р’РѕРїСЂРѕСЃС‹ Р·Р°РіСЂСѓР¶Р°СЋС‚СЃСЏ РёР· Р‘Р” РїРѕ questionsId / questionsCategoryId в”Ђв”Ђв”Ђ

class _BattleGamePageState extends ConsumerState<BattleGamePage> {
  Timer? _timer;
  int _remainSeconds = 0;
  double _progress = 1.0;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Р’РѕРїСЂРѕСЃС‹
  List<QuestionData> _questions = [];
  bool _questionsLoading = true;
  int _localQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    AudioHelper.preloadSfx(); // Preload SFX for instant feedback
    _startTimer();
    _loadQuestionsFromDB();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Р—Р°РіСЂСѓР·РєР° СЂРµР°Р»СЊРЅС‹С… РІРѕРїСЂРѕСЃРѕРІ РёР· Р‘Р” РїРѕ questionsId Рё questionsCategoryId.
  Future<void> _loadQuestionsFromDB() async {
    final st = ref.read(battleProvider);
    int categoryId = st.questionsCategoryId;
    final questionsId = st.questionsId;
    final direction = st.gameDirectionMode; // 'English' РёР»Рё РґСЂСѓРіРѕРµ
    final rng = Random();

    debugPrint(
      'рџЋ® _loadQuestionsFromDB: categoryId=$categoryId, '
      'questionsId=$questionsId, direction=$direction',
    );

    try {
      // Fallback: еСЃР»Рё categoryId=0, РёС‰РµРј РїРµСЂРІСѓСЋ СЃРєР°С‡Р°РЅРЅСѓСЋ РєР°С‚РµРіРѕСЂРёСЋ
      if (categoryId == 0) {
        debugPrint(
          'categoryId=0 вЂ” РёС‰РµРј РїРµСЂРІСѓСЋ СЃРєР°С‡Р°РЅРЅСѓСЋ РєР°С‚РµРіРѕСЂРёСЋ',
        );
        for (int id = 1; id <= 5; id++) {
          final has = await CategoryResourceService.hasResources(id);
          if (has) {
            categoryId = id;
            debugPrint('Fallback на категорию $id');
            break;
          }
        }
        if (categoryId == 0) {
          // Ни одна категория не скачана вЂ” ставим 1 и покажем диалог скачивания
          categoryId = 1;
          debugPrint('Нет скачанных категорий, fallback на 1');
        }
      }

      // 0) Проверить, скачан ли курс категории
      final hasRes = await CategoryResourceService.hasResources(categoryId);
      debugPrint('hasResources($categoryId) = $hasRes');
      if (!hasRes) {
        debugPrint(
          'Категория $categoryId не скачана - показываем DownloadDialog',
        );
        if (!mounted) return;

        // Ищем CategoryFlutterDto по ID
        final catState = ref.read(categoriesFlutterProvider);
        CategoryFlutterDto? catDto;
        if (catState.hasValue) {
          catDto = catState.value!.cast<CategoryFlutterDto?>().firstWhere(
            (c) => c!.id == categoryId,
            orElse: () => null,
          );
        }

        if (catDto == null) {
          debugPrint('CategoryFlutterDto для $categoryId не найден');
          if (mounted) setState(() => _questionsLoading = false);
          return;
        }

        // РџРѕРєР°Р·С‹РІР°РµРј РґРёР°Р»РѕРі СЃРєР°С‡РёРІР°РЅРёСЏ (РєР°Рє РІ home_page)
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BattleDownloadDialog(category: catDto!),
        );

        // РџРѕСЃР»Рµ СЃРєР°С‡РёРІР°РЅРёСЏ вЂ” РїСЂРѕРІРµСЂРёС‚СЊ РµС‰С‘ СЂР°Р·
        final hasResAfter = await CategoryResourceService.hasResources(
          categoryId,
        );
        if (!hasResAfter) {
          debugPrint('Скачивание отменено или не удалось');
          if (mounted) setState(() => _questionsLoading = false);
          return;
        }
      }

      final coursePath = await CategoryResourceService.getCoursePath(
        categoryId,
      );
      if (coursePath != null) {
        AudioContext.currentLessonDir = coursePath;
        debugPrint('AudioContext.currentLessonDir = $coursePath');
      }

      final allWords = await CategoryDbHelper.getWordsForCategory(categoryId);
      if (allWords.isEmpty) {
        debugPrint('Нет слов для категории $categoryId');
        if (mounted) setState(() => _questionsLoading = false);
        return;
      }

      List<Word> targetWords;
      if (questionsId.isNotEmpty) {
        final idSet = questionsId.toSet();
        targetWords = allWords.where((w) => idSet.contains(w.id)).toList();
        if (targetWords.isEmpty) {
          targetWords = List.from(allWords)..shuffle(rng);
          targetWords = targetWords
              .take(questionsId.length.clamp(1, 20))
              .toList();
        }
      } else {
        targetWords = List.from(allWords)..shuffle(rng);
        targetWords = targetWords.take(20).toList();
      }

      final dummyPool = await DummyWordsService.loadDummyPool(
        categoryId: categoryId,
        lessonIndex: targetWords.first.lessonIndex >= 0
            ? targetWords.first.lessonIndex
            : 0,
        excludeWords: targetWords,
      );

      final isEnglishDirection = direction == 'English';
      final questions = <QuestionData>[];
      final gameTypes = [
        BattleGameType.chooseTranslation,
        BattleGameType.chooseByAudio,
        BattleGameType.assembleWord,
        BattleGameType.listenAndChoose,
        BattleGameType.pronounceWord,
      ];

      String catName = 'Food';
      final catState = ref.read(categoriesFlutterProvider);
      if (catState.hasValue) {
        final cat = catState.value!.cast<CategoryFlutterDto?>().firstWhere(
          (c) => c!.id == categoryId,
          orElse: () => null,
        );
        if (cat != null) {
          final langCode = context.locale.languageCode == 'tg' ? 'tj' : context.locale.languageCode;
          catName = cat.getLocalizedName(langCode);
        }
      }

      for (int typeIdx = 0; typeIdx < gameTypes.length; typeIdx++) {
        final type = gameTypes[typeIdx];
        final shuffledWords = List<Word>.from(targetWords)..shuffle(rng);

        for (int wordIdx = 0; wordIdx < shuffledWords.length; wordIdx++) {
          final w = shuffledWords[wordIdx];

          final dummies = DummyWordsService.pickFromPool(
            pool: dummyPool,
            targetWord: w,
            count: 3,
          );

          switch (type) {
            case BattleGameType.chooseTranslation:
              final correctText = isEnglishDirection ? w.translation : w.word;
              final wrongTexts = dummies
                  .map((d) => isEnglishDirection ? d.translation : d.word)
                  .toList();
              final opts = [correctText, ...wrongTexts]..shuffle(rng);
              questions.add(
                QuestionData(
                  word: isEnglishDirection ? w.word : w.translation,
                  correctAnswer: correctText,
                  options: opts,
                  correctIndex: opts.indexOf(correctText),
                  type: type,
                  categoryName: catName,
                ),
              );
              break;

            case BattleGameType.chooseByAudio:
              final correctWord = isEnglishDirection ? w.word : w.translation;
              final allWords = [w, ...dummies]..shuffle(rng);
              final audioPaths = allWords
                  .map(
                    (d) => '${isEnglishDirection ? d.word : d.translation}.mp3',
                  )
                  .toList();
              questions.add(
                QuestionData(
                  word: isEnglishDirection ? w.translation : w.word,
                  correctAnswer: correctWord,
                  options: allWords
                      .map((d) => isEnglishDirection ? d.word : d.translation)
                      .toList(),
                  correctIndex: allWords.indexOf(w),
                  type: type,
                  optionAudioPaths: audioPaths,
                  categoryName: catName,
                ),
              );
              break;

            case BattleGameType.assembleWord:
              questions.add(
                QuestionData(
                  word: isEnglishDirection ? w.translation : w.word,
                  correctAnswer: isEnglishDirection ? w.word : w.translation,
                  type: type,
                  categoryName: catName,
                ),
              );
              break;

            case BattleGameType.listenAndChoose:
              final correctText4 = isEnglishDirection ? w.translation : w.word;
              final wrongTexts4 = dummies
                  .map((d) => isEnglishDirection ? d.translation : d.word)
                  .toList();
              final opts4 = [correctText4, ...wrongTexts4]..shuffle(rng);
              final audioFileName4 =
                  '${isEnglishDirection ? w.word : w.translation}.mp3';
              questions.add(
                QuestionData(
                  word: isEnglishDirection ? w.word : w.translation,
                  correctAnswer: correctText4,
                  options: opts4,
                  correctIndex: opts4.indexOf(correctText4),
                  type: type,
                  audioPath: audioFileName4,
                  categoryName: catName,
                ),
              );
              break;

            case BattleGameType.pronounceWord:
              // Game5: РїСЂРѕРёР·РЅРµСЃРё СЃР»РѕРІРѕ
              final audioFileName5 =
                  '${isEnglishDirection ? w.word : w.translation}.mp3';
              questions.add(
                QuestionData(
                  word: isEnglishDirection ? w.word : w.translation,
                  correctAnswer: isEnglishDirection ? w.word : w.translation,
                  type: type,
                  audioPath: audioFileName5,
                  categoryName: catName,
                ),
              );
              break;
          }
        }
      }

      debugPrint(
        'рџ“‹ Generated ${questions.length} questions '
        '(${targetWords.length} words Г— ${gameTypes.length} types)',
      );

      if (mounted) {
        setState(() {
          _questions = questions;
          _questionsLoading = false;
          _prepareCurrentQuestion();
        });
      }
    } catch (e) {
      debugPrint('вќЊ РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё РІРѕРїСЂРѕСЃРѕРІ: $e');
      if (mounted) setState(() => _questionsLoading = false);
    }
  }

  void _prepareCurrentQuestion() {
    if (_questions.isEmpty) return;
    final q = _currentQuestion;
    if ((q.type == BattleGameType.listenAndChoose ||
            q.type == BattleGameType.pronounceWord) &&
        q.audioPath != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          AudioHelper.playWord(
            _audioPlayer,
            q.categoryName ?? '',
            q.audioPath!,
          );
        }
      });
    }
  }

  void _startTimer() {
    final st = ref.read(battleProvider);
    if (st.startTime == null || st.endTime == null) {
      debugPrint(
        'вљ пёЏ _startTimer: startTime or endTime is null, retrying in 1s',
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _startTimer();
      });
      return;
    }

    final totalDuration = st.endTime!.difference(st.startTime!);
    if (totalDuration.isNegative || totalDuration.inMilliseconds == 0) {
      debugPrint('⚠️ Timer: invalid duration, skipping');
      return;
    }
    debugPrint(
      '⏱️ Timer: start=${st.startTime}, end=${st.endTime}, '
      'total=${totalDuration.inSeconds}s',
    );
    _timer?.cancel();
    // endTime-ро дар тағйирёбанда нигоҳ медорем, то ки stale нашавад
    final endTime = st.endTime!;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now().toUtc();
      final remaining = endTime.difference(now);
      if (remaining.isNegative) {
        _timer?.cancel();
        setState(() {
          _progress = 0;
          _remainSeconds = 0;
        });
        ref.read(battleProvider.notifier).finishTest();
        return;
      }
      setState(() {
        _progress = (remaining.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0);
        _remainSeconds = remaining.inSeconds.clamp(0, 9999);
      });
    });
  }

  QuestionData get _currentQuestion {
    if (_questions.isEmpty) {
      return const QuestionData(
        word: '',
        correctAnswer: '',
        type: BattleGameType.chooseTranslation,
      );
    }
    return _questions[_localQuestionIndex % _questions.length];
  }

  void _showExitDialog() {
    final st = ref.read(battleProvider);
    final vm = ref.read(battleProvider.notifier);
    final penalty = st.moneyCount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coin icon in circle
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/battle/coinfull.png',
                    width: 44,
                    height: 44,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on_rounded,
                      size: 44,
                      color: Color(0xFFF79009),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'battle_coins_penalty'.tr(args: ['$penalty']),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF79009),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'battle_exit_title'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'battle_exit_description'.tr(args: ['$penalty']),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),
              MyButton(
                onPressed: () => Navigator.of(context).pop(),
                width: double.infinity,
                buttonColor: Colors.white,
                backButtonColor: const Color(0xFFD0D5DD),
                border: 1.5,
                borderColor: const Color(0xFFD0D5DD),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'battle_continue_playing'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              MyButton(
                onPressed: () {
                  final profileNotifier = ref.read(
                    getProfileInfoProvider.notifier,
                  );
                  final penalty = ref.read(battleProvider).moneyCount;
                  Navigator.of(context).pop();
                  vm.disconnectAll();
                  // Deduct coins locally like Unity's RemoveCoinsLocal
                  profileNotifier.deductCoins(penalty);
                },
                width: double.infinity,
                buttonColor: const Color(0xFFEF4444),
                backButtonColor: const Color(0xFFB91C1C),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'battle_exit_game'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(battleProvider);

    final sorted = List<MemberDto>.from(st.members)
      ..sort((a, b) => b.score.compareTo(a.score));

    final totalQ = st.questionsCount > 0 ? st.questionsCount : 20;
    final finished = st.currentQuestionIndex >= totalQ;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A4B8C),
        body: Column(
          children: [
            _buildCityHeader(st.currentQuestionIndex.clamp(0, totalQ), totalQ),
            SizedBox(height: 8.h),
            _buildPlayersRoads(sorted),
            SizedBox(height: 16.h),
            _questionsLoading || _questions.isEmpty
                ? _buildLoadingQuestions()
                : finished
                ? _buildWaitingForOthers()
                : _buildCurrentGame(),
          ],
        ),
      ),
    );
  }

  Widget _buildCityHeader(int questionNum, int totalQ) {
    final minutes = _remainSeconds ~/ 60;
    final secs = _remainSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 170.h,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4DA6FF), Color(0xFF1A4B8C)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20.h,
                bottom: 0,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/images/cityofbattle.png',
                  fit: BoxFit.fitWidth,
                  height: 190.h,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 6.h,
          left: 6.w,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
            onPressed: () => _showExitDialog(),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10.h,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                '${(questionNum + 1).clamp(1, totalQ)} / $totalQ',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8.h,
          right: 12.w,
          child: Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8.r,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Фон прогресса
                SizedBox(
                  width: 45.w,
                  height: 45.w,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 3.5.w,
                    backgroundColor: const Color(0xFFE0E0E0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progress < 0.2
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF2E90FA),
                    ),
                  ),
                ),
                // Текст времени
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _progress < 0.2
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF1A4B8C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cloud(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(h / 2),
      ),
    );
  }

  Widget _buildPlayersRoads(List<MemberDto> sorted) {
    final myName = StorageService.instance.getUserName() ?? '';
    final totalPlayers = sorted.length;

    // Find current user's rank (1-based)
    int myRank = 0;
    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].name == myName) {
        myRank = i + 1;
        break;
      }
    }

    // Show top 4 roads
    final displayMembers = sorted.length > 4 ? sorted.sublist(0, 4) : sorted;
    final bool showMyRank = myRank > 4 && totalPlayers > 4;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Column(
        children: [
          ...displayMembers.map((m) => _buildPlayerRoad(m)),
          if (showMyRank)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF79009).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '$myName: $myRank/$totalPlayers',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerRoad(MemberDto member) {
    final roadProgress = (member.score / 400.0).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: SizedBox(
        height: 28.h,
        child: Row(
          children: [
            // Имя
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth;
                  final carW = 28.w;
                  final carOffset = (trackWidth - carW) * roadProgress;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DashedLinePainter(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        left: carOffset,
                        top: -21,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Name label above car
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                member.name,
                                style: GoogleFonts.inter(
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Image.asset(
                              member.hasLeft
                                  ? 'assets/images/carexitbattle.png'
                                  : 'assets/images/carforbattle.png',
                              height: 18.h,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFF12B76A),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '${member.score}',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGameAnswer(bool isCorrect) {
    ref.read(battleProvider.notifier).sendAnswer(isCorrect: isCorrect);
    final st = ref.read(battleProvider);
    final totalQ = st.questionsCount > 0 ? st.questionsCount : 20;
    setState(() {
      _localQuestionIndex++;
      // If all questions answered, finish immediately — don't wait for timer
      if (st.currentQuestionIndex >= totalQ) {
        _timer?.cancel();
        ref.read(battleProvider.notifier).finishTest();
        return;
      }
      _prepareCurrentQuestion();
    });
  }

  void _playAnswerSound(bool isCorrect) {
    if (isCorrect) {
      AudioHelper.playCorrect();
    } else {
      AudioHelper.playWrong();
    }
  }

  Widget _buildCurrentGame() {
    final q = _currentQuestion;
    switch (q.type) {
      case BattleGameType.chooseTranslation:
        return ChooseTranslationGame(
          key: ValueKey('ct_$_localQuestionIndex'),
          question: q,
          onAnswer: _handleGameAnswer,
          playAnswerSound: _playAnswerSound,
        );
      case BattleGameType.chooseByAudio:
        return ChooseByAudioGame(
          key: ValueKey('ca_$_localQuestionIndex'),
          question: q,
          audioPlayer: _audioPlayer,
          onAnswer: _handleGameAnswer,
          playAnswerSound: _playAnswerSound,
        );
      case BattleGameType.assembleWord:
        return AssembleWordGame(
          key: ValueKey('aw_$_localQuestionIndex'),
          question: q,
          onAnswer: _handleGameAnswer,
          playAnswerSound: _playAnswerSound,
        );
      case BattleGameType.listenAndChoose:
        return ListenAndChooseGame(
          key: ValueKey('lc_$_localQuestionIndex'),
          question: q,
          audioPlayer: _audioPlayer,
          onAnswer: _handleGameAnswer,
          playAnswerSound: _playAnswerSound,
        );
      case BattleGameType.pronounceWord:
        return PronounceWordGame(
          key: ValueKey('pw_$_localQuestionIndex'),
          question: q,
          audioPlayer: _audioPlayer,
          onAnswer: _handleGameAnswer,
          playAnswerSound: _playAnswerSound,
        );
    }
  }

  Widget _buildLoadingQuestions() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        padding: EdgeInsets.all(28.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36.w,
              height: 36.w,
              child: CircularProgressIndicator(
                color: const Color(0xFF2E90FA),
                strokeWidth: 3.w,
                backgroundColor: const Color(
                  0xFF2E90FA,
                ).withValues(alpha: 0.15),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'battle_loading_questions'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForOthers() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        padding: EdgeInsets.all(28.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: const Color(0xFF2E90FA),
                strokeWidth: 3,
                backgroundColor: const Color(
                  0xFF2E90FA,
                ).withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _remainSeconds > 0
                  ? 'battle_waiting_others'.tr()
                  : 'battle_loading_results'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF667085),
              ),
            ),
            if (_remainSeconds > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(_remainSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainSeconds % 60).toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2E90FA),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashWidth = 6.0;
    const dashGap = 4.0;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
