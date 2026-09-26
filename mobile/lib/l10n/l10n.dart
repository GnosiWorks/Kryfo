// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'dates.dart';

export 'app_localizations.dart';

// a getter rather than AppLocalizations.of(context) because much of what
// kryfo says is said away from any widget: background notifications, toasts
// raised after an await.
AppLocalizations _current = lookupAppLocalizations(const Locale('en'));
Locale _locale = const Locale('en');

AppLocalizations get l10n => _current;

/// a handle, id or link, kept left to right in a right-to-left language
/// where "@wren" would otherwise read "wren@"
String ltr(String s) => '\u2066$s\u2069';

/// MaterialApp is given it too, so material's own words and the text
/// direction follow
Locale get l10nLocale => _locale;

void setL10nLocale(Locale locale) {
  _locale = locale;
  _current = lookupAppLocalizations(locale);
  setDateLocale(
    intlLocaleFor(locale.languageCode, scriptCode: locale.scriptCode),
  );
}
