// Тесты для модели PendingProgressSync — хранит локальные
// оптимистичные обновления, которые ждут подтверждения от сервера.
//
// Важно для оффлайн-режима и защиты от потери данных,
// когда сервер медленно обрабатывает запросы.

import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/feature/progress/progress_merge_helper.dart';

void main() {
  group('PendingProgressSync.fromJson', () {
    test('парсит корректный JSON', () {
      final json = {
        'langKey': 'TjToEn',
        'wordId': 100,
        'state': 2,
        'timeout': '2026-04-20T10:00:00.000',
        'writeTime': '2026-04-13T14:00:00.000',
        'errorInGames': ['Memoria'],
      };
      final p = PendingProgressSync.fromJson(json);
      expect(p.langKey, 'TjToEn');
      expect(p.wordId, 100);
      expect(p.state, 2);
      expect(p.timeout, DateTime(2026, 4, 20, 10, 0, 0));
      expect(p.errorInGames, ['Memoria']);
    });

    test('обрабатывает wordId как String', () {
      final json = {
        'langKey': 'RuToEn',
        'wordId': '42',
        'state': 1,
        'timeout': '2026-04-20T10:00:00.000',
        'writeTime': '2026-04-13T14:00:00.000',
      };
      final p = PendingProgressSync.fromJson(json);
      expect(p.wordId, 42);
    });

    test('обрабатывает state как String', () {
      final json = {
        'langKey': 'TjToEn',
        'wordId': 1,
        'state': '-1',
        'timeout': '2026-04-20T10:00:00.000',
        'writeTime': '2026-04-13T14:00:00.000',
      };
      final p = PendingProgressSync.fromJson(json);
      expect(p.state, -1);
    });

    test('возвращает epoch для невалидного timeout', () {
      final json = {
        'langKey': 'TjToEn',
        'wordId': 1,
        'state': 1,
        'timeout': 'not_a_date',
        'writeTime': 'also_invalid',
      };
      final p = PendingProgressSync.fromJson(json);
      expect(p.timeout.millisecondsSinceEpoch, 0);
      expect(p.writeTime.millisecondsSinceEpoch, 0);
    });

    test('по умолчанию errorInGames — пустой список', () {
      final json = {
        'langKey': 'TjToEn',
        'wordId': 1,
        'state': 1,
        'timeout': '2026-04-20T10:00:00.000',
        'writeTime': '2026-04-13T14:00:00.000',
      };
      final p = PendingProgressSync.fromJson(json);
      expect(p.errorInGames, isEmpty);
    });
  });

  group('PendingProgressSync.toJson', () {
    test('сериализует все поля', () {
      final p = PendingProgressSync(
        langKey: 'TjToEn',
        wordId: 100,
        state: 3,
        timeout: DateTime(2026, 4, 20, 10, 0),
        writeTime: DateTime(2026, 4, 13, 14, 0),
        errorInGames: ['Memoria'],
      );
      final json = p.toJson();
      expect(json['langKey'], 'TjToEn');
      expect(json['wordId'], 100);
      expect(json['state'], 3);
      expect(json['timeout'], '2026-04-20T10:00:00.000');
      expect(json['writeTime'], '2026-04-13T14:00:00.000');
      expect(json['errorInGames'], ['Memoria']);
    });
  });

  group('ProgressMergeHelper.pendingKey', () {
    test('строит ключ из langKey и wordId', () {
      expect(ProgressMergeHelper.pendingKey('TjToEn', 100), 'TjToEn:100');
      expect(ProgressMergeHelper.pendingKey('RuToEn', 42), 'RuToEn:42');
    });

    test('ключи разных направлений для одного слова различны', () {
      final k1 = ProgressMergeHelper.pendingKey('TjToEn', 100);
      final k2 = ProgressMergeHelper.pendingKey('RuToEn', 100);
      expect(k1, isNot(k2));
    });
  });

  group('ProgressMergeHelper.sameTimeout', () {
    test('одинаковые timestamp считаются равными', () {
      final a = DateTime(2026, 4, 13, 10, 0, 0);
      final b = DateTime(2026, 4, 13, 10, 0, 0);
      expect(ProgressMergeHelper.sameTimeout(a, b), isTrue);
    });

    test('разница в миллисекундах считается равной (в пределах tolerance)', () {
      final a = DateTime(2026, 4, 13, 10, 0, 0);
      final b = DateTime(2026, 4, 13, 10, 0, 0, 500);
      expect(ProgressMergeHelper.sameTimeout(a, b), isTrue);
    });

    test('разница в часах не считается равной', () {
      final a = DateTime(2026, 4, 13, 10);
      final b = DateTime(2026, 4, 13, 11);
      expect(ProgressMergeHelper.sameTimeout(a, b), isFalse);
    });
  });
}
