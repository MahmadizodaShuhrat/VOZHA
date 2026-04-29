// lib/core/services/word_text_cache.dart
//
// Local cache for word text data. Solves the problem where the server
// returns new word IDs (470xxx) without preserving the original word text.
// When a user learns a word, we cache the text so it's available later
// for repeat flow even if the server doesn't return it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WordTextCache {
  static WordTextCache? _instance;
  static WordTextCache get instance => _instance ??= WordTextCache._();
  WordTextCache._();

  Map<String, Map<String, String>>? _cache; // wordId -> {word, translate, transcription}
  String? _filePath;

  Future<String> _getFilePath() async {
    if (_filePath != null) return _filePath!;
    final dir = await getApplicationDocumentsDirectory();
    _filePath = p.join(dir.path, 'word_text_cache.json');
    return _filePath!;
  }

  Future<Map<String, Map<String, String>>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (file.existsSync()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _cache = decoded.map((k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, v2.toString())),
        ));
      } else {
        _cache = {};
      }
    } catch (e) {
      debugPrint('⚠️ [WordTextCache] load error: $e');
      _cache = {};
    }
    return _cache!;
  }

  Future<void> _save() async {
    try {
      final path = await _getFilePath();
      await File(path).writeAsString(jsonEncode(_cache));
    } catch (e) {
      debugPrint('⚠️ [WordTextCache] save error: $e');
    }
  }

  /// Очищает весь кэш (используется при logout).
  Future<void> clearAll() async {
    try {
      _cache = {};
      final path = await _getFilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('🗑️ [WordTextCache] cleared');
    } catch (e) {
      debugPrint('⚠️ [WordTextCache] clearAll error: $e');
    }
  }

  /// Cache word text when a word is learned or interacted with.
  /// Call this during learning sessions to save word text for later use.
  Future<void> cacheWord({
    required int wordId,
    required String word,
    required String translation,
    String transcription = '',
    int categoryId = 0,
  }) async {
    final cache = await _load();
    cache[wordId.toString()] = {
      'word': word,
      'translate': translation,
      'transcription': transcription,
      if (categoryId > 0) 'categoryId': categoryId.toString(),
    };
    await _save();
  }

  /// Batch cache multiple words at once (more efficient).
  Future<void> cacheWords(List<WordTextEntry> entries) async {
    if (entries.isEmpty) return;
    final cache = await _load();
    for (final entry in entries) {
      cache[entry.wordId.toString()] = {
        'word': entry.word,
        'translate': entry.translation,
        'transcription': entry.transcription,
        if (entry.categoryId > 0) 'categoryId': entry.categoryId.toString(),
      };
    }
    await _save();
    debugPrint('📦 [WordTextCache] Cached ${entries.length} words');
  }

  /// Look up cached text for a word by its ID.
  Future<WordTextEntry?> getWord(int wordId) async {
    final cache = await _load();
    final entry = cache[wordId.toString()];
    if (entry == null) return null;
    return WordTextEntry(
      wordId: wordId,
      word: entry['word'] ?? '',
      translation: entry['translate'] ?? '',
      transcription: entry['transcription'] ?? '',
      categoryId: int.tryParse(entry['categoryId'] ?? '') ?? 0,
    );
  }

  /// Look up cached text for multiple word IDs at once.
  Future<Map<int, WordTextEntry>> getWords(Iterable<int> wordIds) async {
    final cache = await _load();
    final result = <int, WordTextEntry>{};
    for (final id in wordIds) {
      final entry = cache[id.toString()];
      if (entry != null && (entry['word'] ?? '').isNotEmpty) {
        result[id] = WordTextEntry(
          wordId: id,
          word: entry['word'] ?? '',
          translation: entry['translate'] ?? '',
          transcription: entry['transcription'] ?? '',
          categoryId: int.tryParse(entry['categoryId'] ?? '') ?? 0,
        );
      }
    }
    return result;
  }
}

class WordTextEntry {
  final int wordId;
  final String word;
  final String translation;
  final String transcription;
  final int categoryId;

  WordTextEntry({
    required this.wordId,
    required this.word,
    required this.translation,
    this.transcription = '',
    this.categoryId = 0,
  });
}
