// Тесты для normalizeGameForRepeat — маппинг названий игр.
//
// Нормализует legacy/unsupported названия игр в стандартные.
// Memoria и True-False зависят от wordCount.

import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/core/services/word_repetition_service.dart';

void main() {
  group('WordRepetitionService.normalizeGameForRepeat', () {
    test('Select translation остаётся как есть', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'Select translation',
          wordCount: 4,
        ),
        'Select translation',
      );
    });

    test('Select translation - audio остаётся как есть', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'Select translation - audio',
          wordCount: 4,
        ),
        'Select translation - audio',
      );
    });

    test('Memoria остаётся Memoria при wordCount >= 2', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat('Memoria', wordCount: 4),
        'Memoria',
      );
      expect(
        WordRepetitionService.normalizeGameForRepeat('Memoria', wordCount: 2),
        'Memoria',
      );
    });

    test('Memoria → Select translation при wordCount < 2', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat('Memoria', wordCount: 1),
        'Select translation',
      );
    });

    test('Write a word → Write a translation', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'Write a word',
          wordCount: 4,
        ),
        'Write a translation',
      );
    });

    test('Legacy voice-games маппятся в Select translation', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'Select translation - voice',
          wordCount: 4,
        ),
        'Select translation',
      );
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'Say the word',
          wordCount: 4,
        ),
        'Select translation',
      );
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'Find the word',
          wordCount: 4,
        ),
        'Select translation',
      );
    });

    test('True-False → Memoria при wordCount >= 2', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'True-False',
          wordCount: 4,
        ),
        'Memoria',
      );
    });

    test('True-False → Select translation при wordCount < 2', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'True-False',
          wordCount: 1,
        ),
        'Select translation',
      );
    });

    test('Неизвестная игра → Select translation (fallback)', () {
      expect(
        WordRepetitionService.normalizeGameForRepeat(
          'Some Custom Game',
          wordCount: 4,
        ),
        'Select translation',
      );
    });
  });

  group('WordRepetitionService constants', () {
    test('minRepeatCount равен 10', () {
      expect(WordRepetitionService.minRepeatCount, 10);
    });

    test('allGameNames содержит 4 названия', () {
      expect(WordRepetitionService.allGameNames.length, 4);
      expect(
        WordRepetitionService.allGameNames,
        containsAll([
          'Select translation',
          'Memoria',
          'Select translation - audio',
          'Write a translation',
        ]),
      );
    });
  });
}
