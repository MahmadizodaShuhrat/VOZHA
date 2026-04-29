import 'package:flutter/material.dart';

Widget likeListTile(
  String word, {
  String? transcription,
  String? translation,
  Color? colorr,
  int isLasstt = 0,
  String? correctAnswer,
  BuildContext? context,
}) {
  return GestureDetector(
    child: Container(
      width: double.infinity,
      height: 85,
      decoration: BoxDecoration(
        color: colorr,

        borderRadius:
            isLasstt == 1
                ? BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                )
                : BorderRadius.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Text(
              word,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    colorr == Color(0xFF22C55E)
                        ? Colors.white
                        : colorr == Color(0xFFEF4444)
                        ? Colors.white
                        : Colors.black,
              ),
            ),
          ),
          if (transcription != null)
            Text(
              transcription,
              style: TextStyle(
                color: Color(0xFF697586),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          if (translation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                translation,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    ),
  );
}
