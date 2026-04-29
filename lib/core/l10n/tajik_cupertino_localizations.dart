// lib/core/l10n/tajik_cupertino_localizations.dart
//
// Custom CupertinoLocalizations for Tajik (tg).
// Flutter does not natively support the 'tg' locale for Cupertino widgets.
// Without this delegate, a warning "CupertinoLocalizations delegate not found" is thrown.
//
// Strategy: extend DefaultCupertinoLocalizations (English base, minimal UI impact)
// and override user-visible strings.

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class _TajikCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _TajikCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
      const TajikCupertinoLocalizations(),
    );
  }

  @override
  bool shouldReload(_TajikCupertinoLocalizationsDelegate old) => false;
}

/// Tajik Cupertino Localizations — extends English defaults with Tajik strings.
class TajikCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const TajikCupertinoLocalizations();

  static const LocalizationsDelegate<CupertinoLocalizations> delegate =
      _TajikCupertinoLocalizationsDelegate();

  @override
  String get alertDialogLabel => 'Огоҳӣ';

  @override
  String get copyButtonLabel => 'Нусхабардорӣ';

  @override
  String get cutButtonLabel => 'Буридан';

  @override
  String get pasteButtonLabel => 'Часпондан';

  @override
  String get selectAllButtonLabel => 'Ҳамаро интихоб';

  @override
  String get searchTextFieldPlaceholderLabel => 'Ҷустуҷӯ';

  @override
  String get modalBarrierDismissLabel => 'Бастан';
}
