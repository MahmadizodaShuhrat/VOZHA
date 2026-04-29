// Тесты для CategoryFlutterDto — категорий, получаемых с бэкенда.
//
// Важные случаи:
// - Локализация названий (tj ↔ tg fallback)
// - Парсинг info JSON (может быть строка с trailing comma или double-encoded)
// - Уровни слов (lvl1, lvl2, lvl3)

import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';

void main() {
  group('CategoryFlutterDto.fromJson', () {
    test('парсит базовые поля', () {
      final json = {
        'id': 1,
        'version': '1.0',
        'icon': 'https://example.com/icon.png',
        'is_premium': false,
        'is_special': false,
        'name': {'en': 'Food', 'ru': 'Еда', 'tj': 'Хӯрок'},
        'resources': [],
        'language_type': 'ru_to_en',
        'subcategories': '',
        'info': '',
        'is_course_category': false,
      };
      final c = CategoryFlutterDto.fromJson(json);
      expect(c.id, 1);
      expect(c.version, '1.0');
      expect(c.isPremium, isFalse);
      expect(c.name['en'], 'Food');
      expect(c.name['ru'], 'Еда');
      expect(c.name['tj'], 'Хӯрок');
    });

    test('возвращает дефолтную версию если отсутствует', () {
      final json = <String, dynamic>{
        'id': 1,
        'icon': '',
        'name': <String, dynamic>{},
        'resources': <dynamic>[],
      };
      final c = CategoryFlutterDto.fromJson(json);
      expect(c.version, '1.0');
    });

    test('парсит resources список', () {
      final json = <String, dynamic>{
        'id': 1,
        'icon': '',
        'name': <String, dynamic>{},
        'resources': <Map<String, dynamic>>[
          {'name': 'food.zip', 'size': 1024},
          {'name': 'animals.zip', 'size': 2048},
        ],
      };
      final c = CategoryFlutterDto.fromJson(json);
      expect(c.resources.length, 2);
      expect(c.resources[0].name, 'food.zip');
      expect(c.resources[0].size, 1024);
      expect(c.resources[1].size, 2048);
    });

    test('парсит createdAt, если передан', () {
      final json = <String, dynamic>{
        'id': 1,
        'icon': '',
        'name': <String, dynamic>{},
        'resources': <dynamic>[],
        'created_at': '2026-01-15T10:00:00.000',
      };
      final c = CategoryFlutterDto.fromJson(json);
      expect(c.createdAt, DateTime(2026, 1, 15, 10));
    });

    test('createdAt равен null если не передан', () {
      final json = <String, dynamic>{
        'id': 1,
        'icon': '',
        'name': <String, dynamic>{},
        'resources': <dynamic>[],
      };
      final c = CategoryFlutterDto.fromJson(json);
      expect(c.createdAt, isNull);
    });
  });

  group('CategoryFlutterDto.getLocalizedName', () {
    CategoryFlutterDto buildWith(Map<String, String> name) {
      return CategoryFlutterDto(
        id: 1,
        version: '1.0',
        icon: '',
        isPremium: false,
        isSpecial: false,
        name: name,
        resources: [],
        languageType: '',
        subcategories: '',
        info: '',
        isCourseCategory: false,
      );
    }

    test('возвращает название на русском', () {
      final c = buildWith({'en': 'Food', 'ru': 'Еда', 'tj': 'Хӯрок'});
      expect(c.getLocalizedName('ru'), 'Еда');
    });

    test('возвращает на английском', () {
      final c = buildWith({'en': 'Food', 'ru': 'Еда'});
      expect(c.getLocalizedName('en'), 'Food');
    });

    test('tg использует tj как fallback (API ключ)', () {
      final c = buildWith({'tj': 'Хӯрок', 'en': 'Food'});
      expect(c.getLocalizedName('tg'), 'Хӯрок');
    });

    test('tj использует tg как fallback', () {
      final c = buildWith({'tg': 'Хӯрок', 'en': 'Food'});
      expect(c.getLocalizedName('tj'), 'Хӯрок');
    });

    test('fallback на en если запрошенный язык отсутствует', () {
      final c = buildWith({'en': 'Food', 'ru': 'Еда'});
      expect(c.getLocalizedName('fr'), 'Food');
    });

    test('fallback на ru если en отсутствует', () {
      final c = buildWith({'ru': 'Еда', 'tj': 'Хӯрок'});
      expect(c.getLocalizedName('fr'), 'Еда');
    });

    test('возвращает "Category {id}" если все названия пустые', () {
      final c = buildWith({});
      expect(c.getLocalizedName('ru'), 'Category 1');
    });
  });

  group('CategoryFlutterDto.parsedInfo', () {
    CategoryFlutterDto buildWithInfo(String info) {
      return CategoryFlutterDto(
        id: 1,
        version: '1.0',
        icon: '',
        isPremium: false,
        isSpecial: false,
        name: {},
        resources: [],
        languageType: '',
        subcategories: '',
        info: info,
        isCourseCategory: false,
      );
    }

    test('возвращает null для пустой info строки', () {
      final c = buildWithInfo('');
      expect(c.parsedInfo, isNull);
    });

    test('парсит валидный JSON', () {
      final c = buildWithInfo(
        '{"count_words": 100, "count_words_levels": {"1": 30, "2": 40, "3": 30}}',
      );
      final info = c.parsedInfo;
      expect(info, isNotNull);
      expect(info!.countWords, 100);
      expect(info.countWordsLevels[1], 30);
      expect(info.countWordsLevels[2], 40);
      expect(info.countWordsLevels[3], 30);
    });

    test('убирает trailing comma из JSON (бага бэкенда)', () {
      final c = buildWithInfo(
        '{"count_words": 100, "count_words_levels": {"1": 30,}}',
      );
      final info = c.parsedInfo;
      expect(info, isNotNull);
      expect(info!.countWords, 100);
      expect(info.countWordsLevels[1], 30);
    });

    test('парсит double-encoded JSON (строка с JSON внутри)', () {
      final c = buildWithInfo('"{\\"count_words\\": 50}"');
      final info = c.parsedInfo;
      expect(info, isNotNull);
      expect(info!.countWords, 50);
    });

    test('возвращает null для невалидного JSON', () {
      final c = buildWithInfo('not a json');
      expect(c.parsedInfo, isNull);
    });
  });

  group('CategoryInfoDto', () {
    test('wordsForLevel возвращает значение для уровня', () {
      final info = CategoryInfoDto(
        countWords: 100,
        countWordsLevels: {1: 30, 2: 40, 3: 30},
        organizations: [],
        iconSponsors: '',
        sponsorsText: '',
      );
      expect(info.wordsForLevel(1), 30);
      expect(info.wordsForLevel(2), 40);
      expect(info.wordsForLevel(3), 30);
    });

    test('wordsForLevel fallback на countWords если уровень отсутствует', () {
      final info = CategoryInfoDto(
        countWords: 100,
        countWordsLevels: {1: 100},
        organizations: [],
        iconSponsors: '',
        sponsorsText: '',
      );
      expect(info.wordsForLevel(5), 100);
    });

    test('fromJson парсит count_words_levels с string ключами', () {
      final json = {
        'count_words': 100,
        'count_words_levels': {'1': 30, '2': 40, '3': 30},
      };
      final info = CategoryInfoDto.fromJson(json);
      expect(info.countWordsLevels[1], 30);
      expect(info.countWordsLevels[2], 40);
    });

    test('fromJson парсит organization_id список', () {
      final json = {
        'count_words': 100,
        'organization_id': [1, 2, 3],
      };
      final info = CategoryInfoDto.fromJson(json);
      expect(info.organizations, [1, 2, 3]);
    });

    test('fromJson обрабатывает пустые/отсутствующие поля', () {
      final json = {'count_words': 50};
      final info = CategoryInfoDto.fromJson(json);
      expect(info.countWords, 50);
      expect(info.countWordsLevels, isEmpty);
      expect(info.organizations, isEmpty);
    });
  });

  group('ResourceItemDto', () {
    test('fromJson парсит поля', () {
      final json = {'name': 'food_course.zip', 'size': 58500207};
      final r = ResourceItemDto.fromJson(json);
      expect(r.name, 'food_course.zip');
      expect(r.size, 58500207);
    });

    test('дефолтные значения для отсутствующих полей', () {
      final r = ResourceItemDto.fromJson({});
      expect(r.name, '');
      expect(r.size, 0);
    });
  });
}
