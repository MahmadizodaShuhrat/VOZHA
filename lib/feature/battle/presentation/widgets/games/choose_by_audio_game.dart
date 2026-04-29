import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/battle/data/question_data.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/games_page.dart';

/// Game 2: Выбери перевод по аудио (4 аудио варианта + кнопка «Выбрать»).
class ChooseByAudioGame extends StatefulWidget {
  final QuestionData question;
  final AudioPlayer audioPlayer;
  final void Function(bool isCorrect) onAnswer;
  final void Function(bool isCorrect) playAnswerSound;

  const ChooseByAudioGame({
    super.key,
    required this.question,
    required this.audioPlayer,
    required this.onAnswer,
    required this.playAnswerSound,
  });

  @override
  State<ChooseByAudioGame> createState() => _ChooseByAudioGameState();
}

class _ChooseByAudioGameState extends State<ChooseByAudioGame> {
  int? _selectedAudioIndex;
  bool _answering = false;

  @override
  void didUpdateWidget(covariant ChooseByAudioGame old) {
    super.didUpdateWidget(old);
    if (old.question != widget.question) {
      _selectedAudioIndex = null;
      _answering = false;
    }
  }

  void _handleAudioChooseAnswer(int index, int correctIndex) {
    HapticFeedback.lightImpact();
    final isCorrect = index == correctIndex;
    widget.playAnswerSound(isCorrect);
    setState(() => _answering = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _selectedAudioIndex = null;
        _answering = false;
      });
      widget.onAnswer(isCorrect);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Column(
        children: [
          Container(
            height: 310.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFEEF2F6), width: 2),
              boxShadow: [
                BoxShadow(color: Color(0xFFEEF2F6), offset: Offset(0, 4.h)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Верхняя зона: перевод слова
                Container(
                  height: 85.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color(0xffEEF2F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10.r),
                      topRight: Radius.circular(10.r),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'battle_game_choose_by_audio'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF697586),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        q.word,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // 4 аудио варианта
                for (int i = 0; i < q.optionAudioPaths.length; i++) ...[
                  if (i > 0) const Divider(color: Color(0xFFEEF2F6), height: 0),
                  AudioOption(
                    audioPath: q.optionAudioPaths[i],
                    categoryName: q.categoryName,
                    sharedPlayer: widget.audioPlayer,
                    isActive: _selectedAudioIndex == i,
                    isCorrect: _answering && _selectedAudioIndex == i
                        ? i == q.correctIndex
                        : null,
                    isLast: i == q.optionAudioPaths.length - 1,
                    onPressed: () {
                      if (!_answering) {
                        setState(() => _selectedAudioIndex = i);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 45.h),
          // Кнопка «Выбрать»
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _selectedAudioIndex != null && !_answering
                  ? () => _handleAudioChooseAnswer(
                      _selectedAudioIndex!,
                      q.correctIndex,
                    )
                  : null,
              child: Container(
                height: 50.h,
                decoration: BoxDecoration(
                  color: _selectedAudioIndex != null && !_answering
                      ? const Color(0xFF2E90FA)
                      : const Color(0xFFCDD5DF),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedAudioIndex != null && !_answering
                          ? const Color(0xFF1570EF)
                          : const Color(0xFFB1BCCA),
                      width: 3,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'battle_game_select'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17.sp,
                    color: _selectedAudioIndex != null && !_answering
                        ? Colors.white
                        : const Color(0xFF697586),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
