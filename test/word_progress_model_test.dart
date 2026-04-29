// Тесты для модели WordProgress — самый важный класс для прогресса.
//
// Проверяет:
// 1. fromJson — гибкий парсер (int/String/null)
// 2. toJson — обратная сериализация
// 3. Round-trip: fromJson(toJson(x)) должен равняться x

import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

void main() {
  group('WordProgress.fromJson', () {
    test('парсит корректные int поля', () {
      final json = {
        'CategoryId': 5,
        'WordId': 100,
        'CurrentLearningState': 2,
        'IsFirstSubmitIsLearning': false,
        'Timeout': '2026-04-13T10:00:00.000',
      };
      final wp = WordProgress.fromJson(json);
      expect(wp.categoryId, 5);
      expect(wp.wordId, 100);
      expect(wp.state, 2);
      expect(wp.firstDone, isFalse);
    });

    test('парсит числа, переданные как String', () {
      final json = {
        'CategoryId': '5',
        'WordId': '100',
        'CurrentLearningState': '-1',
        'IsFirstSubmitIsLearning': 'false',
        'Timeout': '2026-04-13T10:00:00.000',
      };
      final wp = WordProgress.fromJson(json);
      expect(wp.categoryId, 5);
      expect(wp.wordId, 100);
      expect(wp.state, -1);
    });

    test('возвращает 0 для невалидных int значений', () {
      final json = {
        'CategoryId': 'not_a_number',
        'WordId': null,
        'CurrentLearningState': 'abc',
        'IsFirstSubmitIsLearning': false,
        'Timeout': '2026-04-13T10:00:00.000',
      };
      final wp = WordProgress.fromJson(json);
      expect(wp.categoryId, 0);
      expect(wp.wordId, 0);
      expect(wp.state, 0);
    });

    test('парсит firstDone как bool', () {
      final j1 = {
        'CategoryId': 1,
        'WordId': 1,
        'CurrentLearningState': 1,
        'IsFirstSubmitIsLearning': true,
        'Timeout': '2026-04-13T10:00:00.000',
      };
      expect(WordProgress.fromJson(j1).firstDone, isTrue);

      final j2 = {...j1, 'IsFirstSubmitIsLearning': 'True'};
      expect(WordProgress.fromJson(j2).firstDone, isTrue);

      final j3 = {...j1, 'IsFirstSubmitIsLearning': 'false'};
      expect(WordProgress.fromJson(j3).firstDone, isFalse);
    });

    test('использует DateTime.now() для невалидного timeout', () {
      final json = {
        'CategoryId': 1,
        'WordId': 1,
        'CurrentLearningState': 1,
        'IsFirstSubmitIsLearning': false,
        'Timeout': 'invalid_date',
      };
      final before = DateTime.now();
      final wp = WordProgress.fromJson(json);
      final after = DateTime.now();
      expect(wp.timeout.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(wp.timeout.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('опциональные текстовые поля по умолчанию пустые', () {
      final json = {
        'CategoryId': 1,
        'WordId': 1,
        'CurrentLearningState': 1,
        'IsFirstSubmitIsLearning': false,
        'Timeout': '2026-04-13T10:00:00.000',
      };
      final wp = WordProgress.fromJson(json);
      expect(wp.original, '');
      expect(wp.translate, '');
      expect(wp.transcription, '');
      expect(wp.categoryName, '');
    });

    test('парсит текстовые поля, если они есть', () {
      final json = {
        'CategoryId': 1,
        'WordId': 100,
        'CurrentLearningState': 2,
        'IsFirstSubmitIsLearning': false,
        'Timeout': '2026-04-13T10:00:00.000',
        'WordOriginal': 'hello',
        'WordTranslate': 'привет',
        'WordTranscription': '/həˈloʊ/',
        'CategoryName': 'Greetings',
      };
      final wp = WordProgress.fromJson(json);
      expect(wp.original, 'hello');
      expect(wp.translate, 'привет');
      expect(wp.transcription, '/həˈloʊ/');
      expect(wp.categoryName, 'Greetings');
    });

    test('парсит errorInGames список', () {
      final json = {
        'CategoryId': 1,
        'WordId': 1,
        'CurrentLearningState': 1,
        'IsFirstSubmitIsLearning': false,
        'Timeout': '2026-04-13T10:00:00.000',
        'ErrorInGames': ['Memoria', 'Select translation'],
      };
      final wp = WordProgress.fromJson(json);
      expect(wp.errorInGames, ['Memoria', 'Select translation']);
    });

    test('возвращает пустой список если errorInGames отсутствует', () {
      final json = {
        'CategoryId': 1,
        'WordId': 1,
        'CurrentLearningState': 1,
        'IsFirstSubmitIsLearning': false,
        'Timeout': '2026-04-13T10:00:00.000',
      };
      final wp = WordProgress.fromJson(json);
      expect(wp.errorInGames, isEmpty);
    });
  });

  group('WordProgress.toJson', () {
    test('сериализует все поля', () {
      final wp = WordProgress(
        categoryId: 5,
        categoryName: 'Food',
        wordId: 100,
        original: 'apple',
        translate: 'яблоко',
        transcription: '/ˈæp.əl/',
        state: 2,
        timeout: DateTime(2026, 4, 13, 10, 0),
        firstDone: true,
        errorInGames: ['Memoria'],
      );
      final json = wp.toJson();
      expect(json['CategoryId'], '5');
      expect(json['WordId'], '100');
      expect(json['CurrentLearningState'], '2');
      expect(json['WordOriginal'], 'apple');
      expect(json['WordTranslate'], 'яблоко');
      expect(json['IsFirstSubmitIsLearning'], 'True');
      expect(json['ErrorInGames'], ['Memoria']);
    });

    test('firstDone=false сериализуется как "False"', () {
      final wp = WordProgress(
        categoryId: 1,
        wordId: 1,
        state: 1,
        timeout: DateTime(2026),
        firstDone: false,
      );
      final json = wp.toJson();
      expect(json['IsFirstSubmitIsLearning'], 'False');
    });
  });

  group('WordProgress round-trip (fromJson ↔ toJson)', () {
    test('сохраняет все данные после сериализации и десериализации', () {
      final original = WordProgress(
        categoryId: 13,
        categoryName: 'Animals',
        wordId: 12345,
        original: 'cat',
        translate: 'кошка',
        transcription: '/kæt/',
        state: 3,
        timeout: DateTime(2026, 4, 13, 14, 30, 45),
        firstDone: true,
        errorInGames: ['Memoria', 'Write a translation'],
      );

      final json = original.toJson();
      final restored = WordProgress.fromJson(json);

      expect(restored.categoryId, original.categoryId);
      expect(restored.categoryName, original.categoryName);
      expect(restored.wordId, original.wordId);
      expect(restored.original, original.original);
      expect(restored.translate, original.translate);
      expect(restored.transcription, original.transcription);
      expect(restored.state, original.state);
      expect(restored.firstDone, original.firstDone);
      expect(restored.errorInGames, original.errorInGames);
      // Timeout может потерять микросекунды, сравниваем до секунд
      expect(
        restored.timeout.difference(original.timeout).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });
  });

  group('Achievement', () {
    test('fromJson создаёт корректный объект', () {
      final json = {'Key': 'LearnWords', 'Value': 42};
      final a = Achievement.fromJson(json);
      expect(a.key, 'LearnWords');
      expect(a.value, 42);
    });

    test('toJson сериализует корректно', () {
      final a = Achievement('DailyActive', 7);
      final json = a.toJson();
      expect(json['Key'], 'DailyActive');
      expect(json['Value'], 7);
    });
  });

  group('ProgressFile', () {
    test('empty() создаёт пустой файл с дефолтными категориями', () {
      final pf = ProgressFile.empty();
      expect(pf.dirs.keys, containsAll(['TjToEn', 'TjToRu', 'RuToEn', 'RuToTj']));
      expect(pf.dirs['TjToEn'], isEmpty);
      expect(pf.selectedIds.length, 6);
      expect(pf.achievements, isEmpty);
    });

    test('copyWith сохраняет остальные поля', () {
      final pf = ProgressFile.empty();
      final newSelectedIds = [99, 100];
      final updated = pf.copyWith(selectedIds: newSelectedIds);
      expect(updated.selectedIds, newSelectedIds);
      expect(updated.dirs, pf.dirs); // Неизменённое поле осталось
      expect(updated.achievements, pf.achievements);
    });
  });
}
