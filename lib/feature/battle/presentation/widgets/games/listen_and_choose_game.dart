import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/feature/battle/data/question_data.dart';

/// Game 4: Прослушай аудио → выбери текстовый перевод.
class ListenAndChooseGame extends StatefulWidget {
  final QuestionData question;
  final AudioPlayer audioPlayer;
  final void Function(bool isCorrect) onAnswer;
  final void Function(bool isCorrect) playAnswerSound;

  const ListenAndChooseGame({
    super.key,
    required this.question,
    required this.audioPlayer,
    required this.onAnswer,
    required this.playAnswerSound,
  });

  @override
  State<ListenAndChooseGame> createState() => _ListenAndChooseGameState();
}

class _ListenAndChooseGameState extends State<ListenAndChooseGame> {
  int? _selectedAnswerIndex;
  bool _answering = false;

  @override
  void didUpdateWidget(covariant ListenAndChooseGame old) {
    super.didUpdateWidget(old);
    if (old.question != widget.question) {
      _selectedAnswerIndex = null;
      _answering = false;
    }
  }

  void _handleChooseAnswer(int index, int correctIndex) {
    HapticFeedback.lightImpact();
    final isCorrect = index == correctIndex;
    widget.playAnswerSound(isCorrect);
    setState(() {
      _selectedAnswerIndex = index;
      _answering = true;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _selectedAnswerIndex = null;
        _answering = false;
      });
      widget.onAnswer(isCorrect);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Container(
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
            // Верхняя зона: кнопка 🔊
            Container(
              height: 110.h,
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
                    'battle_game_listen_choose'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF697586),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  GestureDetector(
                    onTap: () {
                      if (q.audioPath != null) {
                        AudioHelper.playWord(
                          widget.audioPlayer,
                          q.categoryName ?? '',
                          q.audioPath!,
                        );
                      }
                    },
                    child: Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E90FA),
                        borderRadius: BorderRadius.circular(26.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2E90FA,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white, height: 0),
            // 4 текстовых варианта перевода
            for (int i = 0; i < q.options.length; i++) ...[
              _buildOptionTile(q, i, isLast: i == q.options.length - 1),
              if (i < q.options.length - 1)
                const Divider(color: Color(0xFFEEF2F6), height: 0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(QuestionData q, int i, {bool isLast = false}) {
    final isSelected = _selectedAnswerIndex == i;
    final isCorrect = i == q.correctIndex;

    Color bgColor = Colors.white;
    Color textColor = Colors.black;
    if (_answering && isSelected) {
      bgColor = isCorrect ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: _answering ? null : () => _handleChooseAnswer(i, q.correctIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 70.h,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: isLast
              ? BorderRadius.only(
                  bottomLeft: Radius.circular(10.r),
                  bottomRight: Radius.circular(10.r),
                )
              : BorderRadius.zero,
        ),
        child: Center(
          child: Text(
            q.options[i],
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
