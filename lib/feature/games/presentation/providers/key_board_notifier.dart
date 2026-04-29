// file: key_board_notifier.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple Notifier-based letter counter
/// Using NotifierProvider without family for Riverpod 3.x compatibility
final letterCountProvider = NotifierProvider<LetterCountNotifier, Map<int, Map<String, LetterCount>>>(
  LetterCountNotifier.new,
);

class LetterCountNotifier extends Notifier<Map<int, Map<String, LetterCount>>> {
  @override
  Map<int, Map<String, LetterCount>> build() => {};

  /// Initialize or reset letter counts for a specific word index
  void initForWord(int index, String word) {
    final map = <String, LetterCount>{};
    for (var ch in word.toLowerCase().characters) {
      map[ch] = LetterCount(
        letter: ch,
        count: (map[ch]?.count ?? 0) + 1,
      );
    }
    state = {...state, index: map};
  }

  /// Get letter counts for a specific index
  Map<String, LetterCount> getForIndex(int index) {
    return state[index] ?? {};
  }

  /// Use a letter (decrement count)
  void useLetter(int index, String letter) {
    final current = state[index];
    if (current == null) return;
    
    final lc = current[letter];
    if (lc == null || lc.count <= 0) return;
    
    state = {
      ...state,
      index: {
        ...current,
        letter: lc.copyWith(count: lc.count - 1),
      }
    };
  }

  /// Add a letter back (increment count)
  void addLetter(int index, String letter) {
    final current = state[index];
    if (current == null || !current.containsKey(letter)) return;
    
    state = {
      ...state,
      index: {
        ...current,
        letter: LetterCount(
          letter: letter,
          count: current[letter]!.count + 1,
        ),
      }
    };
  }

  /// Reset with new word
  void resetWithWord(int index, String word) {
    debugPrint("resetWithWord: index=$index, word=$word");
    initForWord(index, word);
  }
}

/// Provider that returns letter counts for a specific index
final letterCountForIndexProvider = Provider.family<Map<String, LetterCount>, int>((ref, index) {
  final allCounts = ref.watch(letterCountProvider);
  return allCounts[index] ?? {};
});

class LetterCount {
  final String letter;
  final int count;

  LetterCount({required this.letter, required this.count});

  LetterCount copyWith({int? count}) =>
      LetterCount(letter: letter, count: count ?? this.count);
}



