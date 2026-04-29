// lib/feature/words/domain/remember_words_params.dart
import 'package:flutter/foundation.dart';

@immutable
class RememberWordsParams {
  final int categoryId;
  final List<int> wordIds;              // Correct words (state = 1)
  final List<int> wrongWordIds;         // Wrong words (state = -1)
  final Map<int, List<String>> errorInGames;  // wordId -> list of game names with errors

  const RememberWordsParams({
    required this.categoryId,
    required this.wordIds,
    this.wrongWordIds = const [],
    this.errorInGames = const {},
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RememberWordsParams &&
            other.categoryId == categoryId &&
            listEquals(other.wordIds, wordIds) &&
            listEquals(other.wrongWordIds, wrongWordIds) &&
            mapEquals(other.errorInGames, errorInGames);
  }

  @override
  int get hashCode => Object.hash(
        categoryId,
        Object.hashAll(wordIds),
        Object.hashAll(wrongWordIds),
        errorInGames.hashCode,
      );
}
