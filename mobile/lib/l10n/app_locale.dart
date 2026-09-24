// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

// the language kryfo speaks. one preference, app_locale: 'system' (the
// default) or one of the languages below. system is the phone's language
// when kryfo has it, english when it does not. read before the first frame
// and by a process the background job started, so a notification is in the
// language the app is in.

const kAppLocaleKey = 'app_locale';

/// every language kryfo can have, by its own name, in the order the sheet
/// lists them. a name is never translated: it is how a person who reads
/// that language finds it. only the ones with a file in lib/l10n are shown.
const kLanguageNames = <String, String>{
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'pt': 'Português (Brasil)',
  'it': 'Italiano',
  'ru': 'Русский',
  'uk': 'Українська',
  'tr': 'Türkçe',
  'zh': '简体中文',
  'zh_Hant': '繁體中文',
  'vi': 'Tiếng Việt',
  'id': 'Bahasa Indonesia',
  'fa': 'فارسی',
  'ar': 'العربية',
};

/// the languages there are files for, in the sheet's order
List<String> get availableLanguages => [
  for (final tag in kLanguageNames.keys)
    if (AppLocalizations.supportedLocales.contains(localeOf(tag))) tag,
];

Locale localeOf(String tag) => switch (tag) {
  'zh_Hant' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  _ => Locale(tag),
};

String _pref = 'system';

/// 'system' or a language tag
String get appLocalePref => _pref;

/// bumped when the language changes: the app redraws from its first screen
final localeRevision = ValueNotifier<int>(0);

/// the language kryfo has that is closest to [l], or null
String? _have(Locale l) {
  final have = availableLanguages;
  if (l.languageCode == 'zh') {
    // no script: taiwan, hong kong and macau write traditional
    final hant =
        l.scriptCode == 'Hant' ||
        (l.scriptCode == null &&
            const ['TW', 'HK', 'MO'].contains(l.countryCode));
    final tag = hant ? 'zh_Hant' : 'zh';
    return have.contains(tag) ? tag : null;
  }
  return have.contains(l.languageCode) ? l.languageCode : null;
}

/// the language "match phone" means right now: the first of the phone's
/// languages kryfo has, english when none
String get systemLanguage {
  for (final l in PlatformDispatcher.instance.locales) {
    final t = _have(l);
    if (t != null) return t;
  }
  return 'en';
}

/// the language kryfo is in: the chosen one, or the phone's
String get currentLanguage =>
    _pref != 'system' && availableLanguages.contains(_pref)
    ? _pref
    : systemLanguage;

void _apply() => setL10nLocale(localeOf(currentLanguage));

Future<void> loadAppLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 3),
    );
    _pref = prefs.getString(kAppLocaleKey) ?? 'system';
  } catch (_) {
    _pref = 'system';
  }
  _apply();
}

/// the person picked [pref]: saved, and the app redraws in it
Future<void> setAppLocale(String pref) async {
  _pref = pref;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAppLocaleKey, pref);
  } catch (_) {}
  _apply();
  localeRevision.value++;
}

/// the phone's languages changed while kryfo was open
void systemLocalesChanged() {
  if (_pref != 'system') return;
  final before = l10nLocale;
  _apply();
  if (l10nLocale != before) localeRevision.value++;
}
