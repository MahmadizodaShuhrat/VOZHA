import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Widget vernoNeverno(bool isTrue) {
  return Container(
    width: 148,
    height: 38,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      border: Border(bottom: BorderSide(color: Color(0xFFEEF2F6), width: 3)),
      color: Colors.white,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          isTrue ? Icons.check_circle : Icons.cancel,
          size: 24,
          color: isTrue ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        ),
        Text(
          isTrue == true ? 'correct'.tr() : 'incorrect'.tr(),
          style: TextStyle(
            color: isTrue == true ? Color(0xFF22C55E) : Color(0xFFEF4444),
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}
