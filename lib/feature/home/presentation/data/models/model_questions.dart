class GameState {
  final int currentQuestionIndex;
  final String correctAnswer;

  GameState({required this.currentQuestionIndex, required this.correctAnswer});

  GameState copyWith({int? currentQuestionIndex, String? correctAnswer}) {
    return GameState(
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      correctAnswer: correctAnswer ?? this.correctAnswer,
    );
  }
}
