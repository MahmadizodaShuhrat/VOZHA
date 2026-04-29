// Тесты для утилит: avatar_url_helper, app_locale_utils
//
// Эти утилиты — чистые функции без побочных эффектов,
// поэтому их легко тестировать.

import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/utils/app_locale_utils.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';

void main() {
  // ─────────────────────────────────────────────────────
  //  buildAvatarUrl — построение URL аватара из разных форматов
  // ─────────────────────────────────────────────────────
  group('buildAvatarUrl', () {
    test('возвращает полный URL как есть, если он уже http', () {
      const fullUrl = 'https://cdn.example.com/avatars/user1.png';
      expect(buildAvatarUrl(fullUrl), fullUrl);
    });

    test('возвращает https URL как есть', () {
      const fullUrl = 'https://api.vozhaomuz.com/files/avatars/abc.jpg';
      expect(buildAvatarUrl(fullUrl), fullUrl);
    });

    test('добавляет baseUrl, если путь начинается с /files/avatars/', () {
      const path = '/files/avatars/uuid-123.png';
      expect(buildAvatarUrl(path), '${ApiConstants.baseUrl}$path');
    });

    test('строит полный URL для чистого имени файла', () {
      const filename = 'abc123.jpg';
      final result = buildAvatarUrl(filename);
      expect(
        result,
        '${ApiConstants.baseUrl}${ApiConstants.filesAvatars}$filename',
      );
    });

    test('обрабатывает имя файла с расширением .png', () {
      const filename = 'my_avatar.png';
      final result = buildAvatarUrl(filename);
      expect(result, contains(filename));
      expect(result, startsWith('https://'));
    });
  });

  // ─────────────────────────────────────────────────────
  //  normalizeCategoryLanguageCode — нормализация языковых кодов
  // ─────────────────────────────────────────────────────
  group('normalizeCategoryLanguageCode', () {
    test('конвертирует tg в tj', () {
      expect(normalizeCategoryLanguageCode('tg'), 'tj');
    });

    test('конвертирует TG (заглавные) в tj', () {
      expect(normalizeCategoryLanguageCode('TG'), 'tj');
    });

    test('оставляет ru без изменений', () {
      expect(normalizeCategoryLanguageCode('ru'), 'ru');
    });

    test('оставляет en без изменений', () {
      expect(normalizeCategoryLanguageCode('en'), 'en');
    });

    test('конвертирует RU в нижний регистр', () {
      expect(normalizeCategoryLanguageCode('RU'), 'ru');
    });

    test('обрабатывает неизвестный код (оставляет как есть в нижнем регистре)', () {
      expect(normalizeCategoryLanguageCode('FR'), 'fr');
    });
  });

  // ─────────────────────────────────────────────────────
  //  lessonTitlesKeyForLanguage — ключ для названий уроков в JSON
  // ─────────────────────────────────────────────────────
  group('lessonTitlesKeyForLanguage', () {
    test('для tg возвращает Таджикский', () {
      expect(lessonTitlesKeyForLanguage('tg'), 'Таджикский');
    });

    test('для tj возвращает Таджикский', () {
      expect(lessonTitlesKeyForLanguage('tj'), 'Таджикский');
    });

    test('для ru возвращает Русский', () {
      expect(lessonTitlesKeyForLanguage('ru'), 'Русский');
    });

    test('для en возвращает English', () {
      expect(lessonTitlesKeyForLanguage('en'), 'English');
    });

    test('для неизвестного кода возвращает Таджикский (fallback)', () {
      expect(lessonTitlesKeyForLanguage('fr'), 'Таджикский');
    });

    test('работает с заглавными буквами', () {
      expect(lessonTitlesKeyForLanguage('RU'), 'Русский');
      expect(lessonTitlesKeyForLanguage('EN'), 'English');
    });
  });
}
