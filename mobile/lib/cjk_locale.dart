// SPDX-License-Identifier: GPL-3.0-or-later
// which chinese glyphs han characters are drawn with. in a ui that is not
// chinese the phone picks a cjk font for them by its own order, and on some
// that is a traditional chinese or japanese one, whose 。 sits in the
// middle of the line. text is told its locale instead: the app's chinese,
// else the phone's first chinese, else, for a message, what its own
// characters say (kana is japanese, other han simplified chinese).
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/widgets.dart' show TextStyle, WidgetsBinding;

import 'l10n/app_locale.dart' show currentLanguage;

const kHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
const kHantTw = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
  countryCode: 'TW',
);
const kHantHk = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
  countryCode: 'HK',
);
const kJapanese = Locale('ja');

// one of the phone's chinese languages, as the glyphs it wants
Locale _chineseOf(Locale l) {
  final script = l.scriptCode?.toLowerCase();
  final place = l.countryCode?.toUpperCase();
  if (script == 'hans') return kHans;
  if (place == 'HK' || place == 'MO') return kHantHk;
  if (script == 'hant' || place == 'TW') return kHantTw;
  return kHans;
}

/// the locale han text is drawn in: null leaves it to the ui's own locale.
/// a japanese or korean ui already says which glyphs it wants
Locale? cjkTextLocale({String? app, List<Locale>? system}) {
  final lang = app ?? currentLanguage;
  final phone = system ?? _phoneLocales;
  if (lang == 'zh') return kHans;
  if (lang == 'zh_Hant') {
    for (final l in phone) {
      if (l.languageCode == 'zh' && _chineseOf(l) == kHantHk) return kHantHk;
    }
    return kHantTw;
  }
  for (final l in phone) {
    if (l.languageCode == 'zh') return _chineseOf(l);
    // the phone reads japanese or korean first: its own han glyphs
    if (l.languageCode == 'ja' || l.languageCode == 'ko') return null;
  }
  return null;
}

// the binding's view of them, which a test can set; the engine's before
// there is one
List<Locale> get _phoneLocales {
  try {
    return WidgetsBinding.instance.platformDispatcher.locales;
  } catch (_) {
    return PlatformDispatcher.instance.locales;
  }
}

String? _seenLang;
List<Locale>? _seenPhone;
Locale? _seen;

/// [cjkTextLocale] as things are now, worked out again only when the
/// app's or the phone's languages change
Locale? get cjkTextLocaleNow {
  final lang = currentLanguage;
  final phone = _phoneLocales;
  if (lang != _seenLang || !identical(phone, _seenPhone)) {
    _seenLang = lang;
    _seenPhone = phone;
    _seen = cjkTextLocale(app: lang, system: phone);
  }
  return _seen;
}

bool _han(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0xF900 && c <= 0xFAFF) ||
    (c >= 0x20000 && c <= 0x2FA1F);
bool _kana(int c) =>
    (c >= 0x3040 && c <= 0x30FF) || (c >= 0x31F0 && c <= 0x31FF);

/// what a message's own characters say: japanese with kana in it, simplified
/// chinese for other han, null for none. [fallback] (the app's or the
/// phone's chinese) wins over a guess; [keepOwn] (a phone that reads
/// japanese or korean before any chinese) leaves han without kana to it
Locale? cjkLocaleFor(String text, {Locale? fallback, bool keepOwn = false}) {
  var han = false;
  for (final c in text.runes) {
    if (_kana(c)) return kJapanese;
    if (!han && _han(c)) han = true;
  }
  if (!han) return null;
  return fallback ?? (keepOwn ? null : kHans);
}

/// whether the phone reads japanese or korean before any chinese: its own
/// han glyphs stay
bool phoneHanOwn(List<Locale> phone) {
  for (final l in phone) {
    if (l.languageCode == 'zh') return false;
    if (l.languageCode == 'ja' || l.languageCode == 'ko') return true;
  }
  return false;
}

/// [style] for [text]: with the locale its han wants, the style itself for
/// text with none
TextStyle withHan(TextStyle style, String text) {
  final l = style.locale != null
      ? cjkLocaleFor(text, fallback: style.locale)
      : hanLocaleFor(text);
  return l == null || l == style.locale ? style : style.copyWith(locale: l);
}

/// the locale [text] is drawn in as things are now: null leaves it to the
/// screen's
Locale? hanLocaleFor(String text) {
  final pref = cjkTextLocaleNow;
  return cjkLocaleFor(
    text,
    fallback: pref,
    keepOwn: pref == null && phoneHanOwn(_phoneLocales),
  );
}
