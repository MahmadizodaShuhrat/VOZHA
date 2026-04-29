import 'package:flutter/material.dart';

class ProgressModel {
  final Image image;
   Color? iconColor;
  final String count;
  final String titleKey;
  final Color backgroundColor;

  ProgressModel({
    required this.image,
     this.iconColor,
    required this.count,
    required this.titleKey,
    required this.backgroundColor,
  });
}
