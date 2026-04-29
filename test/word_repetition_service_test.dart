import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/core/services/word_repetition_service.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

WordProgress _wordProgress(int wordId, {List<String> errorInGames = const []}) {
  return WordProgress(
    categoryId: 1,
    wordId: wordId,
    state: -1,
    timeout: DateTime(2026, 1, 1),
    firstDone: false,
    errorInGames: errorInGames,
  );
}

void main() {
  group('WordRepetitionService.mapWordsToGames', () {
    test('normalizes legacy and unsupported repeat game names', () {
      final map = WordRepetitionService.mapWordsToGames([
        _wordProgress(1, errorInGames: ['Write a translation']),
        _wordProgress(2, errorInGames: ['Select translation - voice']),
        _wordProgress(3, errorInGames: ['Unknown custom game']),
      ]);

      expect(
        map[WordRepetitionService.writeTranslationGame]
            ?.map((w) => w.wordId)
            .toList(),
        contains(1),
      );
      expect(
        map[WordRepetitionService.selectTranslationGame]
            ?.map((w) => w.wordId)
            .toList(),
        containsAll([2, 3]),
      );
      expect(
        map.keys.every(WordRepetitionService.allGameNames.contains),
        isTrue,
      );
    });

    test(
      'routes memoria-style games to memoriaGame when word count >= 2',
      () {
        final map = WordRepetitionService.mapWordsToGames([
          _wordProgress(1, errorInGames: ['Memoria']),
          _wordProgress(2, errorInGames: ['True-False']),
          _wordProgress(3),
        ]);

        // With 3 words (>= 2), memoria-style errors go to memoriaGame
        expect(
          map[WordRepetitionService.memoriaGame]
              ?.map((w) => w.wordId)
              .toList(),
          containsAll([1, 2]),
        );
        // Word 3 (no errors) goes to the first free game slot
        expect(
          map.values.any((words) => words.any((w) => w.wordId == 3)),
          isTrue,
        );
      },
    );
  });
}
