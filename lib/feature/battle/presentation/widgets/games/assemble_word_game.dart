import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

import 'package:vozhaomuz/core/utils/audio_helper.dart';
import 'package:vozhaomuz/feature/battle/data/question_data.dart';

/// Game 3: Собери слово — QWERTY клавиатура.
class AssembleWordGame extends StatefulWidget {
  final QuestionData question;
  final void Function(bool isCorrect) onAnswer;
  final void Function(bool isCorrect) playAnswerSound;

  const AssembleWordGame({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.playAnswerSound,
  });

  @override
  State<AssembleWordGame> createState() => _AssembleWordGameState();
}

class _AssembleWordGameState extends State<AssembleWordGame> {
  // QWERTY раскладка
  static const _row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', "'"];
  static const _row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '-'];
  static const _row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm', '?'];

  String _assembledWord = '';
  Map<String, int> _letterCounts = {};
  bool _isCapsLock = false;
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _initLetterCounts();
  }

  @override
  void didUpdateWidget(covariant AssembleWordGame old) {
    super.didUpdateWidget(old);
    if (old.question != widget.question) {
      _assembledWord = '';
      _answering = false;
      _initLetterCounts();
    }
  }

  void _initLetterCounts() {
    _letterCounts = {};
    for (final char in widget.question.correctAnswer.toLowerCase().split('')) {
      if (char == ' ') continue;
      _letterCounts[char] = (_letterCounts[char] ?? 0) + 1;
    }
  }

  void _onKeyTap(String letter) {
    HapticFeedback.lightImpact();
    AudioHelper.playClick();
    final lowerChar = letter.toLowerCase();
    if ((_letterCounts[lowerChar] ?? 0) <= 0) return;
    setState(() {
      _assembledWord += letter;
      _letterCounts[lowerChar] = _letterCounts[lowerChar]! - 1;
    });
  }

  void _removeLastLetter() {
    if (_assembledWord.isEmpty || _answering) return;
    HapticFeedback.lightImpact();
    AudioHelper.playClick();
    setState(() {
      final lastChar = _assembledWord[_assembledWord.length - 1].toLowerCase();
      _assembledWord = _assembledWord.substring(0, _assembledWord.length - 1);
      _letterCounts[lastChar] = (_letterCounts[lastChar] ?? 0) + 1;
    });
  }

  void _checkAssembledWord() {
    final q = widget.question;
    final isCorrect =
        _assembledWord.toLowerCase() == q.correctAnswer.toLowerCase();
    HapticFeedback.lightImpact();
    widget.playAnswerSound(isCorrect);

    setState(() => _answering = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _answering = false);
      widget.onAnswer(isCorrect);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final isCorrectAnswer =
        _assembledWord.toLowerCase() == q.correctAnswer.toLowerCase();
    final isWrong = _answering && !isCorrectAnswer;
    final isRight = _answering && isCorrectAnswer;

    return Column(
      children: [
        // ── Карточка: перевод + набранное слово ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Column(
            children: [
              // Верх: перевод (серая зона)
              Container(
                width: double.infinity,
                height: 85.h,
                decoration: BoxDecoration(
                  color: Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.r),
                    topRight: Radius.circular(10.r),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'battle_game_assemble_word'.tr(),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF697586),
                      ),
                    ),
                    Center(
                      child: Text(
                        q.word,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 25.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF202939),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Низ: набранное слово (белая зона)
              Container(
                width: double.infinity,
                height: 85.h,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFEEF2F6), width: 4),
                  ),
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10.r),
                    bottomRight: Radius.circular(10.r),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Если неправильно — показываем ответ
                    if (isWrong)
                      Text(
                        q.correctAnswer,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFACC15),
                        ),
                      ),
                    Text(
                      _assembledWord.isEmpty ? '…' : _assembledWord,
                      style: TextStyle(
                        fontSize: 23.sp,
                        fontWeight: FontWeight.bold,
                        color: isRight
                            ? Colors.green
                            : isWrong
                            ? Colors.red
                            : _assembledWord.isEmpty
                            ? const Color(0xFF98A2B3)
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12.h),

        // ── Кнопка: Проверить ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionBtn(
                label: 'battle_game_check'.tr(),
                enabled:
                    _assembledWord.length >= q.correctAnswer.length &&
                    !_answering,
                color: const Color(0xFF2E90FA),
                disabledColor: const Color(0xFFCDD5DF),
                onTap: _checkAssembledWord,
              ),
            ],
          ),
        ),
        SizedBox(height: 5.h),

        // ── Клавиатура ──
        _buildKeyboard(),
      ],
    );
  }

  Widget _buildActionBtn({
    required String label,
    required bool enabled,
    required Color color,
    required Color disabledColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 280.w,
        height: 46.h,
        decoration: BoxDecoration(
          color: enabled ? color : disabledColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border(
            bottom: BorderSide(
              color: enabled
                  ? const Color(0xFF1570EF)
                  : const Color(0xFFB1BCCA),
              width: 3,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 17.sp,
            color: enabled ? Colors.white : const Color(0xFF202939),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Container(
      width: double.infinity,
      // color: const Color(0xFFF5FAFF),
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Column(
        children: [
          _buildKeyRow(_row1),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 9.w),
            child: _buildKeyRow(_row2),
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: [
                _buildSpecialKey(
                  icon: Icons.arrow_upward,
                  isActive: _isCapsLock,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isCapsLock = !_isCapsLock);
                  },
                ),
                SizedBox(width: 4.w),
                Expanded(child: _buildKeyRow(_row3)),
                SizedBox(width: 4.w),
                _buildSpecialKey(
                  icon: Icons.backspace_outlined,
                  isActive: false,
                  onTap: _removeLastLetter,
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          _buildSpaceBar(),
          // SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((char) {
        final count = _letterCounts[char.toLowerCase()] ?? 0;
        final displayChar = _isCapsLock ? char.toUpperCase() : char;
        return _buildKey(displayChar, count);
      }).toList(),
    );
  }

  Widget _buildKey(String letter, int count) {
    final active = count > 0 && !_answering;
    return GestureDetector(
      onTap: active ? () => _onKeyTap(letter) : null,
      child: Stack(
        children: [
          Container(
            width: 30.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: active ? Colors.white : const Color(0xFFCDD5DF),
              borderRadius: BorderRadius.circular(5.r),
              border: Border(
                bottom: BorderSide(
                  color: active
                      ? const Color(0xFFCDD5DF)
                      : const Color(0xFFB1BCCA),
                  width: 2,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 22.sp,
                color: active ? Colors.black : Colors.white,
              ),
            ),
          ),
          // Бейдж с количеством
          if (count > 1)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: Color(0xFF2E90FA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(6.r),
                    topRight: Radius.circular(6.r),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecialKey({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 42.w,
        height: 48.h,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2E90FA) : Colors.white,
          borderRadius: BorderRadius.circular(5.r),
          border: Border(
            bottom: BorderSide(
              color: isActive
                  ? const Color(0xFF1570EF)
                  : const Color(0xFFCDD5DF),
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: isActive ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildSpaceBar() {
    final q = widget.question;
    final hasSpace = q.correctAnswer.contains(' ');
    final canTap = hasSpace && !_assembledWord.contains(' ') && !_answering;

    return GestureDetector(
      onTap: canTap
          ? () {
              HapticFeedback.lightImpact();
              setState(() => _assembledWord += ' ');
            }
          : null,
      child: Container(
        width: 200.w,
        height: 44.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5.r),
          color: canTap ? Colors.white : const Color(0xFFCDD5DF),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFB1BCCA), width: 2.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'battle_game_space'.tr(),
          style: TextStyle(
            fontSize: 18.sp,
            color: canTap ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
