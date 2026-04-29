/// Game name constants for error_in_games tracking
/// Names must match Unity project exactly for cross-platform compatibility
class GameNames {
  // Select translation variant games (UIGame1/UIGame4)
  static const String selectTranslation = 'Select translation';
  static const String selectTranslationAudio = 'Select translation - audio';
  static const String selectTranslationVoice = 'Select translation - voice';
  
  // Other games
  static const String writeTranslation = 'Write a translation';
  static const String memoria = 'Memoria';
  static const String trueFalse = 'True-False';
  static const String sayTheWord = 'Say the word';
  static const String findTheWord = 'Find the word';
}

class WordResult {
  final String word;
  final String translation;
  final bool isCorrect;
  final int gameIndex;
  final int wordId;
  final String gameName;  // Game name for error_in_games tracking
  final int? pronScore;   // Speech game pronunciation score (0-100), null if not speech game

  WordResult({
    required this.word,
    required this.translation,
    required this.isCorrect,
    required this.gameIndex,
    this.wordId = 0,
    this.gameName = '',
    this.pronScore,
  });

  /// Word name for display — strips trailing _N suffixes (e.g. "knife_2" → "knife").
  String get displayWord => word.replaceAll(RegExp(r'_\d+$'), '');
}
