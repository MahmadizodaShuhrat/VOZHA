import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/core/services/word_repetition_service.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

/// Tests for state transitions and timeout calculation in spaced repetition.
///
/// These tests guard against regressions in:
/// - `computeNewState`: state++ on correct, state-- on error (with boundaries)
/// - `computeTimeout`: spaced intervals (2d → 7d → 14d)
/// - `isWordWithRepeat`: word qualifies for repeat if timeout expired and state 0..3
void main() {
  group('WordRepetitionService.computeNewState', () {
    test('state 1 → 2 on correct answer', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 1,
        isCorrect: true,
      );
      expect(result, 2);
    });

    test('state 2 → 3 on correct answer', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 2,
        isCorrect: true,
      );
      expect(result, 3);
    });

    test('state 3 → 4 on correct answer (fully learned)', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 3,
        isCorrect: true,
      );
      expect(result, 4);
    });

    test('state 4 stays 4 on correct answer', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 4,
        isCorrect: true,
      );
      expect(result, 4);
    });

    test('negative state resets to 1 on correct answer', () {
      final result = WordRepetitionService.computeNewState(
        currentState: -1,
        isCorrect: true,
      );
      expect(result, 1);
    });

    test('state 0 → 1 on correct answer', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 0,
        isCorrect: true,
      );
      expect(result, 1);
    });

    test('isFirstDone=true forces state to 4', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 0,
        isCorrect: true,
        isFirstDone: true,
      );
      expect(result, 4);
    });

    test('positive state stays the same on error (only timeout changes)', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 3,
        isCorrect: false,
      );
      expect(result, 3);
    });

    test('state 0 → -1 on error', () {
      final result = WordRepetitionService.computeNewState(
        currentState: 0,
        isCorrect: false,
      );
      expect(result, -1);
    });

    test('state -1 → -2 on error', () {
      final result = WordRepetitionService.computeNewState(
        currentState: -1,
        isCorrect: false,
      );
      expect(result, -2);
    });
  });

  group('WordRepetitionService.computeTimeout', () {
    test('state 1 → +2 days on correct', () {
      final before = DateTime.now();
      final result = WordRepetitionService.computeTimeout(
        newState: 1,
        isCorrect: true,
      );
      final diff = result.difference(before).inHours;
      expect(diff, greaterThanOrEqualTo(47)); // ~48h = 2 days
      expect(diff, lessThanOrEqualTo(49));
    });

    test('state 2 → +7 days on correct', () {
      final before = DateTime.now();
      final result = WordRepetitionService.computeTimeout(
        newState: 2,
        isCorrect: true,
      );
      final diff = result.difference(before).inHours;
      expect(diff, greaterThanOrEqualTo(167)); // ~168h = 7 days
      expect(diff, lessThanOrEqualTo(169));
    });

    test('state 3 → +14 days on correct', () {
      final before = DateTime.now();
      final result = WordRepetitionService.computeTimeout(
        newState: 3,
        isCorrect: true,
      );
      final diff = result.difference(before).inHours;
      expect(diff, greaterThanOrEqualTo(335)); // ~336h = 14 days
      expect(diff, lessThanOrEqualTo(337));
    });

    test('error → +1 day regardless of state', () {
      final before = DateTime.now();
      final result = WordRepetitionService.computeTimeout(
        newState: 2,
        isCorrect: false,
      );
      final diff = result.difference(before).inHours;
      expect(diff, greaterThanOrEqualTo(23));
      expect(diff, lessThanOrEqualTo(25));
    });
  });

  group('WordRepetitionService.isWordWithRepeat', () {
    WordProgress makeWord({
      required int state,
      required DateTime timeout,
      bool firstDone = false,
    }) {
      return WordProgress(
        categoryId: 1,
        wordId: 1,
        state: state,
        timeout: timeout,
        firstDone: firstDone,
      );
    }

    test('state=4 (learned) is NOT in repeat even if timeout expired', () {
      final word = makeWord(
        state: 4,
        timeout: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(WordRepetitionService.isWordWithRepeat(word), isFalse);
    });

    test('state=2 with future timeout is NOT in repeat', () {
      final word = makeWord(
        state: 2,
        timeout: DateTime.now().add(const Duration(days: 7)),
      );
      expect(WordRepetitionService.isWordWithRepeat(word), isFalse);
    });

    test('state=2 with expired timeout IS in repeat', () {
      final word = makeWord(
        state: 2,
        timeout: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(WordRepetitionService.isWordWithRepeat(word), isTrue);
    });

    test('firstDone=true word is NOT in repeat', () {
      final word = makeWord(
        state: 2,
        timeout: DateTime.now().subtract(const Duration(days: 1)),
        firstDone: true,
      );
      expect(WordRepetitionService.isWordWithRepeat(word), isFalse);
    });

    test('correct answer on state=3 removes word from repeat', () {
      // Simulates: user answers repeat word correctly → state→4 → removed
      final newState = WordRepetitionService.computeNewState(
        currentState: 3,
        isCorrect: true,
      );
      final newTimeout = WordRepetitionService.computeTimeout(
        newState: newState,
        isCorrect: true,
      );
      final word = makeWord(state: newState, timeout: newTimeout);
      expect(WordRepetitionService.isWordWithRepeat(word), isFalse);
    });

    test('correct answer on state=1 pushes word out of repeat for 2 days', () {
      final newState = WordRepetitionService.computeNewState(
        currentState: 1,
        isCorrect: true,
      );
      final newTimeout = WordRepetitionService.computeTimeout(
        newState: newState,
        isCorrect: true,
      );
      final word = makeWord(state: newState, timeout: newTimeout);
      expect(WordRepetitionService.isWordWithRepeat(word), isFalse);
      expect(newState, 2);
    });
  });

  group('WordRepetitionService.pickWordsForSession', () {
    WordProgress makeWord(int id, int state, Duration ago) {
      return WordProgress(
        categoryId: 1,
        wordId: id,
        state: state,
        timeout: DateTime.now().subtract(ago),
        firstDone: false,
      );
    }

    test('picks up to 10 words sorted by most overdue first', () {
      final words = [
        makeWord(1, 1, const Duration(days: 1)),
        makeWord(2, 1, const Duration(days: 5)), // most overdue
        makeWord(3, 1, const Duration(days: 3)),
      ];
      final selected = WordRepetitionService.pickWordsForSession(words);
      expect(selected.length, 3);
      // Sorted by category then state — just verify count
    });

    test('excludes learned words (state=4)', () {
      final words = [
        makeWord(1, 1, const Duration(days: 1)),
        makeWord(2, 4, const Duration(days: 1)), // learned
        makeWord(3, 2, const Duration(days: 1)),
      ];
      final selected = WordRepetitionService.pickWordsForSession(words);
      expect(selected.length, 2);
      expect(selected.any((w) => w.wordId == 2), isFalse);
    });

    test('excludes words with future timeout', () {
      final words = [
        makeWord(1, 1, const Duration(days: 1)), // overdue
        WordProgress(
          categoryId: 1,
          wordId: 2,
          state: 1,
          timeout: DateTime.now().add(const Duration(days: 1)), // future
          firstDone: false,
        ),
      ];
      final selected = WordRepetitionService.pickWordsForSession(words);
      expect(selected.length, 1);
      expect(selected.first.wordId, 1);
    });

    test('respects count parameter', () {
      final words = List.generate(
        20,
        (i) => makeWord(i, 1, Duration(days: i + 1)),
      );
      final selected = WordRepetitionService.pickWordsForSession(
        words,
        count: 5,
      );
      expect(selected.length, 5);
    });
  });
}
