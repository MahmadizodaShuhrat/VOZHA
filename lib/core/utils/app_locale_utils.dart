String normalizeCategoryLanguageCode(String languageCode) {
  switch (languageCode.toLowerCase()) {
    case 'tg':
      return 'tj';
    default:
      return languageCode.toLowerCase();
  }
}

String lessonTitlesKeyForLanguage(String languageCode) {
  switch (normalizeCategoryLanguageCode(languageCode)) {
    case 'tj':
      return 'Таджикский';
    case 'ru':
      return 'Русский';
    case 'en':
      return 'English';
    default:
      return 'Таджикский';
  }
}
