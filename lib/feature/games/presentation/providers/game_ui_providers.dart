import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart'; // Model Word

// Enums
enum GameStage {
  flashcards,
  trueFalse,
  matching,
  sound,
  keyboard,
  audioWaveSound,
  wordPuzzle,
  speech,
  result,
}

enum GameMode { sound, flashcard, speech }

// Notifiers

// 1. CurrentWordIndex
final currentWordIndexProvider =
    NotifierProvider<CurrentWordIndexNotifier, int>(
      CurrentWordIndexNotifier.new,
    );

class CurrentWordIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
  void increment() => state++;
}

// 2. GameStage
final gameStageProvider = NotifierProvider<GameStageNotifier, GameStage>(
  GameStageNotifier.new,
);

class GameStageNotifier extends Notifier<GameStage> {
  @override
  GameStage build() => GameStage.flashcards;

  void set(GameStage value) => state = value;
}

// 3. GameMode
final gameModeProvider = NotifierProvider<GameModeNotifier, GameMode>(
  GameModeNotifier.new,
);

class GameModeNotifier extends Notifier<GameMode> {
  @override
  GameMode build() => GameMode.sound;

  void set(GameMode value) => state = value;
}

// 4. IsPremium
final isPremiumProvider = NotifierProvider<IsPremiumNotifier, bool>(
  IsPremiumNotifier.new,
);

class IsPremiumNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final allowGameFlowPopProvider =
    NotifierProvider<AllowGameFlowPopNotifier, bool>(
      AllowGameFlowPopNotifier.new,
    );

class AllowGameFlowPopNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

// 5. SelectedCategory (int?)
final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, int?>(
      SelectedCategoryNotifier.new,
    );

class SelectedCategoryNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? value) => state = value;
}

// 6. SelectedSubcategory (int?)
final selectedSubcategoryProvider =
    NotifierProvider<SelectedSubcategoryNotifier, int?>(
      SelectedSubcategoryNotifier.new,
    );

class SelectedSubcategoryNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? value) => state = value;
}

// 7. LearningWords (List<Word>)
final learningWordsProvider =
    NotifierProvider<LearningWordsNotifier, List<Word>>(
      LearningWordsNotifier.new,
    );

class LearningWordsNotifier extends Notifier<List<Word>> {
  @override
  List<Word> build() => [];
  void set(List<Word> value) => state = value;
}

// 8. LearningPressCount (int)
final learningPressCountProvider =
    NotifierProvider<LearningPressCountNotifier, int>(
      LearningPressCountNotifier.new,
    );

class LearningPressCountNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
  void increment() => state++;
}

// 9. ShowCorrectnessLabel (bool?)
final showCorrectnessLabelProvider =
    NotifierProvider<ShowCorrectnessLabelNotifier, bool?>(
      ShowCorrectnessLabelNotifier.new,
    );

class ShowCorrectnessLabelNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  void set(bool? value) => state = value;
}

// 10. LocalChoiceIndex (int)
final localChoiceIndexProvider =
    NotifierProvider<LocalChoiceIndexNotifier, int>(
      LocalChoiceIndexNotifier.new,
    );

class LocalChoiceIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}

// 11. RepeatGameMap — maps game names to their assigned words (Unity-style)
final repeatGameMapProvider =
    NotifierProvider<RepeatGameMapNotifier, Map<String, List<Word>>>(
      RepeatGameMapNotifier.new,
    );

class RepeatGameMapNotifier extends Notifier<Map<String, List<Word>>> {
  @override
  Map<String, List<Word>> build() => {};
  void set(Map<String, List<Word>> value) => state = value;
}

// 12. AllRepeatWords — stores all repeat words (before splitting per game)
final allRepeatWordsProvider =
    NotifierProvider<AllRepeatWordsNotifier, List<Word>>(
      AllRepeatWordsNotifier.new,
    );

class AllRepeatWordsNotifier extends Notifier<List<Word>> {
  @override
  List<Word> build() => [];
  void set(List<Word> value) => state = value;
}

// 13. RepeatGameOrder — ordered list of game names to play
final repeatGameOrderProvider =
    NotifierProvider<RepeatGameOrderNotifier, List<String>>(
      RepeatGameOrderNotifier.new,
    );

class RepeatGameOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];
  void set(List<String> value) => state = value;
}

// 14. RepeatGameIndex — current index in the repeatGameOrder
final repeatGameIndexProvider = NotifierProvider<RepeatGameIndexNotifier, int>(
  RepeatGameIndexNotifier.new,
);

class RepeatGameIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
  void increment() => state++;
}

// 15. RepeatOriginalStates — caches wordId → state at repeat session start
// Prevents _sendRepeatResults from reading stale/updated progress during session
final repeatOriginalStatesProvider =
    NotifierProvider<RepeatOriginalStatesNotifier, Map<int, int>>(
      RepeatOriginalStatesNotifier.new,
    );

class RepeatOriginalStatesNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => {};
  void set(Map<int, int> value) => state = value;
}
