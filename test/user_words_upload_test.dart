// Тесты для UserWordsWithUpload — модель для отправки прогресса на сервер.
//
// Важно: поля serialize с правильными ключами (snake_case),
// потому что сервер ожидает именно этот формат.

import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/feature/games/data/models/user_words_with_upload.dart';

void main() {
  group('UserWordsWithUpload.toJson', () {
    test('сериализует все обязательные поля', () {
      final now = DateTime(2026, 4, 13, 14, 30);
      final u = UserWordsWithUpload(
        categoryId: 1,
        wordId: 100,
        currentLearningState: 2,
        isFirstSubmitIsLearning: false,
        learningLanguage: 'TjToEn',
        timeout: now.toIso8601String(),
        errorInGames: ['Memoria'],
        writeTime: now.toIso8601String(),
        wordOriginal: 'apple',
        wordTranslate: 'себ',
      );
      final json = u.toJson();
      expect(json['category_id'], 1);
      expect(json['word_id'], 100);
      expect(json['current_learning_state'], 2);
      expect(json['is_first_submit_is_learning'], false);
      expect(json['learning_language'], 'TjToEn');
      expect(json['error_in_games'], ['Memoria']);
      expect(json['word_original'], 'apple');
      expect(json['word_translate'], 'себ');
    });

    test('пустые текстовые поля не включаются в JSON', () {
      final u = UserWordsWithUpload(
        categoryId: 1,
        wordId: 100,
        currentLearningState: 1,
        isFirstSubmitIsLearning: false,
        learningLanguage: 'RuToEn',
        timeout: '2026-04-13T14:30:00.000',
        errorInGames: [],
        writeTime: '2026-04-13T14:30:00.000',
        // wordOriginal и wordTranslate по умолчанию пустые
      );
      final json = u.toJson();
      expect(json.containsKey('word_original'), isFalse);
      expect(json.containsKey('word_translate'), isFalse);
    });
  });

  group('UserWordsWithUpload.fromJson', () {
    test('парсит JSON с сервера', () {
      final json = {
        'category_id': 5,
        'word_id': 100,
        'current_learning_state': 2,
        'is_first_submit_is_learning': false,
        'learning_language': 'TjToEn',
        'timeout': '2026-04-20T10:00:00.000',
        'error_in_games': ['Memoria', 'Write a translation'],
        'write_time': '2026-04-13T14:30:00.000',
        'word_original': 'hello',
        'word_translate': 'салом',
      };
      final u = UserWordsWithUpload.fromJson(json);
      expect(u.categoryId, 5);
      expect(u.wordId, 100);
      expect(u.currentLearningState, 2);
      expect(u.learningLanguage, 'TjToEn');
      expect(u.errorInGames, ['Memoria', 'Write a translation']);
      expect(u.wordOriginal, 'hello');
      expect(u.wordTranslate, 'салом');
    });

    test('использует дефолты для отсутствующих полей', () {
      final json = {
        'category_id': 1,
        'word_id': 1,
      };
      final u = UserWordsWithUpload.fromJson(json);
      expect(u.currentLearningState, 1); // default
      expect(u.isFirstSubmitIsLearning, isTrue); // default
      expect(u.learningLanguage, 'EnToRu'); // default
      expect(u.errorInGames, isEmpty);
    });
  });

  group('UserWordsWithUpload.forNewWord', () {
    test('создаёт запись для нового выученного слова', () {
      final u = UserWordsWithUpload.forNewWord(
        categoryId: 13,
        wordId: 42,
        learningLanguage: 'TjToEn',
      );
      expect(u.categoryId, 13);
      expect(u.wordId, 42);
      expect(u.currentLearningState, 1);
      expect(u.isFirstSubmitIsLearning, isFalse); // LEARN, not KNOW
      expect(u.learningLanguage, 'TjToEn');
      expect(u.errorInGames, isEmpty);
    });
  });

  group('UserWordsWithUpload.forWrongWord', () {
    test('создаёт запись для неправильного ответа (state=-1)', () {
      final u = UserWordsWithUpload.forWrongWord(
        categoryId: 13,
        wordId: 42,
      );
      expect(u.currentLearningState, -1);
      expect(u.isFirstSubmitIsLearning, isFalse);
    });
  });

  group('UserWordsWithUpload round-trip', () {
    test('сохраняет данные при сериализации туда-обратно', () {
      final original = UserWordsWithUpload(
        categoryId: 13,
        wordId: 42,
        currentLearningState: 2,
        isFirstSubmitIsLearning: false,
        learningLanguage: 'TjToEn',
        timeout: '2026-04-20T10:00:00.000',
        errorInGames: ['Memoria'],
        writeTime: '2026-04-13T14:30:00.000',
        wordOriginal: 'dog',
        wordTranslate: 'саг',
      );
      final json = original.toJson();
      final restored = UserWordsWithUpload.fromJson(json);
      expect(restored.categoryId, original.categoryId);
      expect(restored.wordId, original.wordId);
      expect(restored.currentLearningState, original.currentLearningState);
      expect(restored.learningLanguage, original.learningLanguage);
      expect(restored.errorInGames, original.errorInGames);
      expect(restored.wordOriginal, original.wordOriginal);
      expect(restored.wordTranslate, original.wordTranslate);
    });
  });
}
