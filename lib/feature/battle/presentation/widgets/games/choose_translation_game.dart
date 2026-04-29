import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/battle/data/question_data.dart';

/// Game 1: Выбери правильный перевод (4 текстовых варианта).
class ChooseTranslationGame extends StatefulWidget {
  final QuestionData question;
  final void Function(bool isCorrect) onAnswer;
  final void Function(bool isCorrect) playAnswerSound;

  const ChooseTranslationGame({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.playAnswerSound,
  });

  @override
  State<ChooseTranslationGame> createState() => _ChooseTranslationGameState();
}

class _ChooseTranslationGameState extends State<ChooseTranslationGame> {
  int? _selectedAnswerIndex;
  bool _answering = false;

  @override
  void didUpdateWidget(covariant ChooseTranslationGame old) {
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
      padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 20.h),
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
            // Верхняя зона
            Container(
              height: 100.h,
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
                    'battle_game_choose_translation'.tr(),
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
            const Divider(color: Colors.white, height: 0),
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
        height: 65.h,
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
