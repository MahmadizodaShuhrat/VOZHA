import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_questions.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';

final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(
  GameStateNotifier.new,
);

// Простой Notifier вместо StateProvider
final selectedMatchIndexProvider =
    NotifierProvider<SelectedMatchIndexNotifier, int?>(
      SelectedMatchIndexNotifier.new,
    );

class SelectedMatchIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  // Метод для обновления состояния (замена сеттеру state)
  void set(int? value) => state = value;
}

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    final words = ref.read(learningWordsProvider);
    return GameState(
      currentQuestionIndex: 0,
      correctAnswer: words.isNotEmpty ? words[0].translation : '',
    );
  }

  void nextQuestion() {
    final words = ref.read(learningWordsProvider);
    final newIndex = state.currentQuestionIndex + 1;

    if (newIndex < words.length) {
      state = GameState(
        currentQuestionIndex: newIndex,
        correctAnswer: words[newIndex].translation,
      );
    } else {
      // Logic for end of game
    }
  }

  void reset() {
    final words = ref.read(learningWordsProvider);
    state = GameState(
      currentQuestionIndex: 0,
      correctAnswer: words.isNotEmpty ? words[0].translation : '',
    );
  }
}
