import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Сервис для управления прогрессом обучения, который хранит данные в локальном JSON-файле.
class LearningProgressJsonService {
  static const _fileName = 'learning_progress.json';

  /// Получает путь к файлу для хранения прогресса.
  Future<String> get _filePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  /// Читает данные из JSON-файла.
  /// В случае отсутствия файла или ошибки возвращает пустую карту.
  Future<Map<String, dynamic>> _readProgress() async {
    try {
      final file = File(await _filePath);
      if (!await file.exists()) {
        return {}; // Файла еще нет, возвращаем пустые данные
      }
      final contents = await file.readAsString();
      return json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Ошибка чтения файла прогресса: $e');
      return {};
    }
  }

  /// Записывает данные в JSON-файл.
  Future<void> _writeProgress(Map<String, dynamic> data) async {
    try {
      final file = File(await _filePath);
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('Ошибка записи файла прогресса: $e');
    }
  }

  /// Сохраняет ID последнего слова для указанной категории.
  /// Этот ID используется для возобновления обучения с места остановки.
  Future<void> saveLastWordId(int categoryId, int wordId) async {
    final progress = await _readProgress();
    progress[categoryId.toString()] = wordId; // Сохраняем ID слова вместо индекса
    await _writeProgress(progress);
  }

  /// Получает сохраненный ID слова для категории.
  /// Если ID не найден, возвращает null.
  Future<int?> getLastWordId(int categoryId) async {
    final progress = await _readProgress();
    final wordId = progress[categoryId.toString()];
    if (wordId is int) {
      return wordId;
    }
    return null;
  }
}

/// Провайдер Riverpod для доступа к сервису.
final learningProgressJsonServiceProvider = Provider((ref) => LearningProgressJsonService());
