// db_lang_column.dart
import 'dart:ui';
import '../../core/utils/app_logger.dart';

String? _lastLoggedLocale;

String dbLangColumn(Locale l) {
  final col = switch (l.languageCode) {
    'tg' => 'Tajik',
    'ru' => 'Russian',
    'en' => 'English',
    _ => 'Tajik', // fallback to Tajik
  };
  if (_lastLoggedLocale != l.languageCode) {
    _lastLoggedLocale = l.languageCode;
    log.i('Locale ${l.languageCode} ⇒ column $col');
  }
  return col;
}
