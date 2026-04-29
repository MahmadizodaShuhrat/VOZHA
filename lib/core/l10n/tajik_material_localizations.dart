// lib/core/l10n/tajik_material_localizations.dart
//
// Custom MaterialLocalizations for Tajik (tg).
// Flutter does not natively support the 'tg' locale for Material widgets.
// Without this delegate, any Scaffold / TextField / BackButton etc. will crash
// with "No MaterialLocalizations found".
//
// Strategy: extend Russian (MaterialLocalizationRu) since Tajik uses Cyrillic
// and shares similar date/number formats. Override user-visible strings.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/date_symbols.dart' as intl;
import 'package:intl/date_symbol_data_custom.dart' as date_symbol_data_custom;

class _TajikMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _TajikMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final String localeName = intl.Intl.canonicalizedLocale(locale.toString());

    // Use Russian date patterns as a base since Tajik shares Cyrillic
    // and similar date formatting conventions.
    date_symbol_data_custom.initializeDateFormattingCustom(
      locale: localeName,
      symbols: intl.DateSymbols(
        NAME: localeName,
        ERAS: const <String>['п.м.', 'м.'],
        ERANAMES: const <String>['пеш аз мелод', 'мелодӣ'],
        NARROWMONTHS: const <String>[
          'Я',
          'Ф',
          'М',
          'А',
          'М',
          'И',
          'И',
          'А',
          'С',
          'О',
          'Н',
          'Д',
        ],
        STANDALONENARROWMONTHS: const <String>[
          'Я',
          'Ф',
          'М',
          'А',
          'М',
          'И',
          'И',
          'А',
          'С',
          'О',
          'Н',
          'Д',
        ],
        MONTHS: const <String>[
          'Январ',
          'Феврал',
          'Март',
          'Апрел',
          'Май',
          'Июн',
          'Июл',
          'Август',
          'Сентябр',
          'Октябр',
          'Ноябр',
          'Декабр',
        ],
        STANDALONEMONTHS: const <String>[
          'Январ',
          'Феврал',
          'Март',
          'Апрел',
          'Май',
          'Июн',
          'Июл',
          'Август',
          'Сентябр',
          'Октябр',
          'Ноябр',
          'Декабр',
        ],
        SHORTMONTHS: const <String>[
          'Янв',
          'Фев',
          'Мар',
          'Апр',
          'Май',
          'Июн',
          'Июл',
          'Авг',
          'Сен',
          'Окт',
          'Ноя',
          'Дек',
        ],
        STANDALONESHORTMONTHS: const <String>[
          'Янв',
          'Фев',
          'Мар',
          'Апр',
          'Май',
          'Июн',
          'Июл',
          'Авг',
          'Сен',
          'Окт',
          'Ноя',
          'Дек',
        ],
        WEEKDAYS: const <String>[
          'Якшанбе',
          'Душанбе',
          'Сешанбе',
          'Чоршанбе',
          'Панҷшанбе',
          'Ҷумъа',
          'Шанбе',
        ],
        STANDALONEWEEKDAYS: const <String>[
          'Якшанбе',
          'Душанбе',
          'Сешанбе',
          'Чоршанбе',
          'Панҷшанбе',
          'Ҷумъа',
          'Шанбе',
        ],
        SHORTWEEKDAYS: const <String>['Яш', 'Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб'],
        STANDALONESHORTWEEKDAYS: const <String>[
          'Яш',
          'Дш',
          'Сш',
          'Чш',
          'Пш',
          'Ҷм',
          'Шб',
        ],
        NARROWWEEKDAYS: const <String>['Я', 'Д', 'С', 'Ч', 'П', 'Ҷ', 'Ш'],
        STANDALONENARROWWEEKDAYS: const <String>[
          'Я',
          'Д',
          'С',
          'Ч',
          'П',
          'Ҷ',
          'Ш',
        ],
        SHORTQUARTERS: const <String>[
          '1-чоряк',
          '2-чоряк',
          '3-чоряк',
          '4-чоряк',
        ],
        QUARTERS: const <String>['1-чоряк', '2-чоряк', '3-чоряк', '4-чоряк'],
        AMPMS: const <String>['пе. аз н.', 'па. аз н.'],
        DATEFORMATS: const <String>[
          'EEEE, d MMMM y',
          'd MMMM y',
          'd MMM y',
          'dd.MM.y',
        ],
        TIMEFORMATS: const <String>[
          'HH:mm:ss zzzz',
          'HH:mm:ss z',
          'HH:mm:ss',
          'HH:mm',
        ],
        FIRSTDAYOFWEEK: 0,
        WEEKENDRANGE: const <int>[5, 6],
        FIRSTWEEKCUTOFFDAY: 3,
        DATETIMEFORMATS: const <String>[
          '{1} {0}',
          '{1} {0}',
          '{1} {0}',
          '{1} {0}',
        ],
      ),
      patterns: const <String, String>{
        'd': 'd',
        'E': 'ccc',
        'EEEE': 'cccc',
        'LLL': 'LLL',
        'LLLL': 'LLLL',
        'M': 'L',
        'Md': 'dd.MM',
        'MEd': 'EEE, dd.MM',
        'MMM': 'LLL',
        'MMMd': 'd MMM',
        'MMMEd': 'ccc, d MMM',
        'MMMM': 'LLLL',
        'MMMMd': 'd MMMM',
        'MMMMEEEEd': 'cccc, d MMMM',
        'QQQ': 'QQQ',
        'QQQQ': 'QQQQ',
        'y': 'y',
        'yM': 'MM.y',
        'yMd': 'dd.MM.y',
        'yMEd': 'ccc, dd.MM.y',
        'yMMM': 'LLL y',
        'yMMMd': 'd MMM y',
        'yMMMEd': 'EEE, d MMM y',
        'yMMMM': 'LLLL y',
        'yMMMMd': 'd MMMM y',
        'yMMMMEEEEd': 'EEEE, d MMMM y',
        'yQQQ': 'QQQ y',
        'yQQQQ': 'QQQQ y',
        'H': 'HH',
        'Hm': 'HH:mm',
        'Hms': 'HH:mm:ss',
        'j': 'HH',
        'jm': 'HH:mm',
        'jms': 'HH:mm:ss',
        'jmv': 'HH:mm v',
        'jmz': 'HH:mm z',
        'jz': 'HH z',
        'm': 'm',
        'ms': 'mm:ss',
        's': 's',
        'v': 'v',
        'z': 'z',
        'zzzz': 'zzzz',
        'ZZZZ': 'ZZZZ',
      },
    );

    return SynchronousFuture<MaterialLocalizations>(
      TajikMaterialLocalizations(localeName: localeName),
    );
  }

  @override
  bool shouldReload(_TajikMaterialLocalizationsDelegate old) => false;
}

/// Tajik Material Localizations — extends Russian base with Tajik strings.
class TajikMaterialLocalizations extends MaterialLocalizationRu {
  TajikMaterialLocalizations({required super.localeName})
    : super(
        fullYearFormat: intl.DateFormat.y(localeName),
        compactDateFormat: intl.DateFormat.yMd(localeName),
        shortDateFormat: intl.DateFormat.yMMMd(localeName),
        mediumDateFormat: intl.DateFormat('EEE, MMM d', localeName),
        longDateFormat: intl.DateFormat.yMMMMEEEEd(localeName),
        yearMonthFormat: intl.DateFormat.yMMMM(localeName),
        shortMonthDayFormat: intl.DateFormat.MMMd(localeName),
        // NumberFormat: explicitly use 'ru' locale since 'tg'/'tg_Cyrl_TJ' is not
        // supported by intl package and the default (system locale) on phones
        // with Tajik language set causes "Invalid locale tg_Cyrl_TJ" crash.
        decimalFormat: intl.NumberFormat.decimalPattern('ru'),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', 'ru'),
      );

  /// The delegate singleton
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _TajikMaterialLocalizationsDelegate();

  // ── User-visible string overrides ──────────────────────────

  @override
  String get okButtonLabel => 'Хуб';

  @override
  String get cancelButtonLabel => 'Бекор';

  @override
  String get closeButtonLabel => 'Пӯшидан';

  @override
  String get copyButtonLabel => 'Нусхабардорӣ';

  @override
  String get cutButtonLabel => 'Буридан';

  @override
  String get pasteButtonLabel => 'Часпондан';

  @override
  String get selectAllButtonLabel => 'Ҳамаро интихоб';

  @override
  String get searchFieldLabel => 'Ҷустуҷӯ';

  @override
  String get backButtonTooltip => 'Бозгашт';

  @override
  String get deleteButtonTooltip => 'Нест кардан';

  @override
  String get nextPageTooltip => 'Саҳифаи навбатӣ';

  @override
  String get previousPageTooltip => 'Саҳифаи пешина';

  @override
  String get firstPageTooltip => 'Саҳифаи аввал';

  @override
  String get lastPageTooltip => 'Саҳифаи охирин';

  @override
  String get openAppDrawerTooltip => 'Менюи навигатсия';

  @override
  String get closeButtonTooltip => 'Пӯшидан';

  @override
  String get continueButtonLabel => 'Идома';

  @override
  String get moreButtonTooltip => 'Бештар';

  @override
  String get alertDialogLabel => 'Огоҳӣ';

  @override
  String get modalBarrierDismissLabel => 'Бастан';

  @override
  String get saveButtonLabel => 'Нигоҳ доштан';
}
