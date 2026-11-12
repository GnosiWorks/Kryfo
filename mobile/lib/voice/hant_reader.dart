// SPDX-License-Identifier: GPL-3.0-or-later
// who reads traditional characters: the model writes mandarin in
// simplified ones (voice_text.dart), and a reader of traditional sees them
// turned back, taiwan's or hong kong's forms, as the translations do
// (translate/hant.dart). the kept words stay as the model wrote them.
import 'dart:ui' show Locale, PlatformDispatcher;

import '../l10n/app_locale.dart' show currentLanguage;
import '../translate/hant.dart' show HantForm;

// the forms one of the phone's chinese languages asks for
HantForm _formOf(Locale l) {
  final script = l.scriptCode?.toLowerCase();
  final place = l.countryCode?.toUpperCase();
  if (script == 'hans') return HantForm.none;
  if (place == 'HK' || place == 'MO') return HantForm.hk;
  if (script == 'hant' || place == 'TW') return HantForm.tw;
  return HantForm.none;
}

/// the traditional forms a reader wants: kryfo in traditional chinese, or
/// a phone whose first chinese is traditional. kryfo in simplified chinese
/// reads simplified, whatever the phone says
HantForm readerHant({String? app, List<Locale>? system}) {
  final lang = app ?? currentLanguage;
  if (lang == 'zh') return HantForm.none;
  final locales = system ?? PlatformDispatcher.instance.locales;
  var phone = HantForm.none;
  for (final l in locales) {
    if (l.languageCode != 'zh') continue;
    phone = _formOf(l);
    break;
  }
  if (lang == 'zh_Hant') return phone == HantForm.hk ? phone : HantForm.tw;
  return phone;
}
