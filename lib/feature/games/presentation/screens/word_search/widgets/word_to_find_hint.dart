import 'package:flutter/material.dart';

class WordToFindHint extends StatelessWidget {
  final String word;
  final bool show;

  const WordToFindHint({super.key, required this.word, required this.show});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < word.length; i++)
            LetterBox(
              letter: show ? word[i] : '',
              filled: true,
              isFirstLetter: i == 0,
              isLastLetter: i == word.length - 1,
            ),
        ],
      ),
    );
  }
}

class LetterBox extends StatelessWidget {
  final String letter;
  final bool filled;
  final bool isFirstLetter;
  final bool isLastLetter;

  const LetterBox({
    super.key,
    required this.letter,
    required this.filled,
    required this.isFirstLetter,
    required this.isLastLetter,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      width: 30,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: isFirstLetter ? Radius.circular(10) : Radius.zero,
          bottomLeft: isFirstLetter ? Radius.circular(10) : Radius.zero,
          topRight: isLastLetter ? Radius.circular(10) : Radius.zero,
          bottomRight: isLastLetter ? Radius.circular(10) : Radius.zero,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCDD5DF), width: 3),
          top: BorderSide(color: Color(0xFFCDD5DF), width: 1),
          left: BorderSide(color: Color(0xFFCDD5DF), width: 1),
          right: isLastLetter
              ? BorderSide(color: Color(0xFFCDD5DF), width: 1)
              : BorderSide.none,
        ),
      ),
      duration: Duration(milliseconds: 500),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: Color(0xFF202939),
        ),
      ),
    );
  }
}
