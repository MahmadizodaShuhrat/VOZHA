import 'package:flutter/widgets.dart';

class TrophiesModel {
  final String gradeOfTrophy;
  final Image image;
  final int countOfWords;
  final int countOfLearnedWords;
  final double widthOfPadding;
  final double sizeForMediquery;
  final int giftInCoins;

  TrophiesModel({
    required this.gradeOfTrophy,
    required this.image,
    required this.countOfWords,
    required this.countOfLearnedWords,
    required this.widthOfPadding,
    required this.sizeForMediquery,
    required this.giftInCoins,
  });
}
