// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'dates.dart';

export 'app_localizations.dart';

// the app's words, for the current language. a getter rather than
// AppLocalizations.of(context) because a good share of what kryfo says is
// said away from any widget: notifications from the background job, the
// app state's own lines, toasts raised after an await. one way in for all
// of it keeps them in the same language.
//
// english only for now. the language picker will call setL10nLocale and
// rebuild the app from the root, so nothing holds on to the old words.
AppLocalizations _current = lookupAppLocalizations(const Locale('en'));
Locale _locale = const Locale('en');

AppLocalizations get l10n => _current;

/// the language the app is in now. MaterialApp is given it too, so
/// material's own words (copy, paste, select all) and the text direction
/// follow.
Locale get l10nLocale => _locale;

void setL10nLocale(Locale locale) {
  _locale = locale;
  _current = lookupAppLocalizations(locale);
  setDateLocale(
    intlLocaleFor(locale.languageCode, scriptCode: locale.scriptCode),
  );
}
