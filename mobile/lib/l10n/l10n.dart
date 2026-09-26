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

final _rtlLetter = RegExp(
  r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF\u{10800}-\u{10FFF}\u{1E800}-\u{1EFFF}]',
  unicode: true,
);
final _letter = RegExp(r'\p{L}', unicode: true);

/// the direction of words a person wrote, from their first letter, the way
/// a chat app reads a message: english in the arabic app still ends in its
/// own question mark, and persian in the english one starts on the right.
/// null when there is no letter to go by (digits, emoji, a link's symbols
/// alone), which leaves the app's own direction.
TextDirection? writtenDir(String s) {
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (_rtlLetter.hasMatch(c)) return TextDirection.rtl;
    if (_letter.hasMatch(c)) return TextDirection.ltr;
  }
  return null;
}

/// where the app's own lines start: a person's words keep their direction
/// but line up with the rest of the screen (a list, a row with a mark)
TextAlign startOf(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? TextAlign.right
    : TextAlign.left;

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
