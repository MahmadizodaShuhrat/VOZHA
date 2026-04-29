/// Типы мини-игр Battle.
enum BattleGameType {
  chooseTranslation,
  chooseByAudio,
  assembleWord,
  listenAndChoose,
  pronounceWord,
}

/// Данные одного вопроса для Battle.
class QuestionData {
  final String word;
  final String correctAnswer;
  final List<String> options; // для chooseTranslation / listenAndChoose
  final int correctIndex; // для chooseTranslation / listenAndChoose
  final BattleGameType type;
  final String? audioPath; // путь к аудио слова (listenAndChoose)
  final List<String> optionAudioPaths; // пути к аудио вариантов (chooseByAudio)
  final String? categoryName; // имя категории для AudioHelper

  const QuestionData({
    required this.word,
    required this.correctAnswer,
    this.options = const [],
    this.correctIndex = 0,
    required this.type,
    this.audioPath,
    this.optionAudioPaths = const [],
    this.categoryName,
  });
}
