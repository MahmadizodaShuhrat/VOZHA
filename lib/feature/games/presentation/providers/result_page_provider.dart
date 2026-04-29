// feature/home/presentation/screens/providers/result_page_provider.dart

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';

final gameResultProvider =
    NotifierProvider<GameResultNotifier, List<WordResult>>(
  GameResultNotifier.new,
);

class GameResultNotifier extends Notifier<List<WordResult>> {
  @override
  List<WordResult> build() => [];
  
  // Store ALL attempts to track which games had errors
  final List<WordResult> _allAttempts = [];

  void addResult({
    required String word,
    required String translation,
    required bool isCorrect,
    required int gameIndex,
    required int wordId,
    String gameName = '',  // game name for error_in_games
    bool overwrite = false, // if true, replace previous result instead of AND
    int? pronScore,  // Speech game pronunciation score (0-100)
  }) {
    debugPrint('📝 [GameResult] Adding: word=$word, wordId=$wordId, isCorrect=$isCorrect, gameName=$gameName, gameIndex=$gameIndex, pronScore=$pronScore');
    
    // Store this attempt in _allAttempts (preserve error history)
    _allAttempts.add(WordResult(
      word: word,
      translation: translation,
      isCorrect: isCorrect,
      gameIndex: gameIndex,
      wordId: wordId,
      gameName: gameName,
      pronScore: pronScore,
    ));
    
    // Update state with aggregated result per word
    final idx = state.indexWhere((r) => r.wordId == wordId);
    if (idx == -1) {
      // Word not seen yet - add new entry
      state = [
        ...state,
        WordResult(
          word: word,
          translation: translation,
          isCorrect: isCorrect,
          gameIndex: gameIndex,
          wordId: wordId,
          gameName: gameName,
          pronScore: pronScore,
        )
      ];
    } else {
      // Word exists - update with logical AND of all attempts
      final old = state[idx];
      final newResult = WordResult(
        word: old.word,
        translation: old.translation,
        isCorrect: overwrite ? isCorrect : (old.isCorrect && isCorrect), // overwrite for retry, AND for multi-game
        gameIndex: gameIndex,
        wordId: old.wordId,
        gameName: gameName.isNotEmpty ? gameName : old.gameName,
        pronScore: pronScore ?? old.pronScore,
      );
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) newResult else state[i]
      ];
    }
    
    debugPrint('📊 [GameResult] Total words: ${state.length}, Total attempts: ${_allAttempts.length}');
  }

  /// Get all game names where the given wordId had errors (from all attempts)
  Set<String> getErrorGamesForWord(int wordId) {
    return _allAttempts
        .where((r) => r.wordId == wordId && !r.isCorrect)
        .map((r) => r.gameName)
        .where((g) => g.isNotEmpty)
        .toSet();
  }
  
  /// Get ALL error attempts (for building errorInGames map)
  List<WordResult> getAllAttempts() => List.unmodifiable(_allAttempts);
  
  /// Get all wordIds that had at least one error
  Set<int> getWrongWordIds() {
    return _allAttempts
        .where((r) => !r.isCorrect)
        .map((r) => r.wordId)
        .toSet();
  }
  
  /// Get all wordIds that had NO errors (all attempts correct)
  Set<int> getCorrectWordIds() {
    final wrongIds = getWrongWordIds();
    return state
        .map((r) => r.wordId)
        .where((id) => !wrongIds.contains(id))
        .toSet();
  }
  
  /// Build errorInGames map from all attempts
  Map<int, List<String>> buildErrorInGames() {
    final Map<int, Set<String>> errors = {};
    for (var r in _allAttempts) {
      if (!r.isCorrect && r.gameName.isNotEmpty) {
        errors.putIfAbsent(r.wordId, () => {}).add(r.gameName);
      }
    }
    return errors.map((k, v) => MapEntry(k, v.toList()));
  }

  void reset() {
    state = [];
    _allAttempts.clear();
    debugPrint('🔄 [GameResult] Reset');
  }
}
