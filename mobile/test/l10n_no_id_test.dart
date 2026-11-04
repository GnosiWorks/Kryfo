// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo has no user ids: the three words are a name, in every language
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/app_localizations.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

// the keys that talk about the three words or the person
const _aboutYou = [
  'inviteShareText',
  'myKryfoTheLinkCarriesYour',
  'onboardingYourKryfoId',
  'profileKryfoId',
  'kryfoLinkTextYouJoinUnderA',
];

// words for "id" that are not latin letters, per language
const _localId = {
  'fa': ['شناسه'],
  'ar': ['معرّف'],
  'tr': ['kimli', 'KİMLİ'],
  'hi': ['आईडी', 'आइडी'],
  'pl': ['identyfikator'],
};

String _words(String s) => s.replaceAll(RegExp(r'\{\w+\}'), '');

void main() {
  final locales = [
    for (final l in AppLocalizations.supportedLocales)
      l.countryCode == null && l.scriptCode == null
          ? l.languageCode
          : l.toLanguageTag().replaceAll('-', '_'),
  ];

  test('no string in any language says id', () {
    // letters on either side make it another word, as in idées
    final latin = RegExp(
      r'(?<!\p{L})(id|ids|ID|IDs|Id)(?!\p{L})',
      unicode: true,
    );
    final bad = <String>[];
    for (final locale in locales) {
      for (final kv in _arb(locale).entries) {
        if (kv.key.startsWith('@') || kv.value is! String) continue;
        if (latin.hasMatch(_words(kv.value as String))) {
          bad.add('$locale ${kv.key}');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('the three words are never an id in their own language', () {
    final bad = <String>[];
    for (final locale in locales) {
      final arb = _arb(locale);
      for (final key in _aboutYou) {
        final s = arb[key] as String;
        for (final w in _localId[locale] ?? const <String>[]) {
          if (s.contains(w)) bad.add('$locale $key');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('the shared invite calls the words a name', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      en.inviteShareText('a-b-c', 'https://x', 'https://d'),
      'Add me on Kryfo. My name there is a-b-c\n\nTap to add me:\n'
      'https://x\n\nNo Kryfo yet? Get it here:\nhttps://d\n\n'
      'Kryfo is a private messenger. No phone number, no email.',
    );
    for (final l in AppLocalizations.supportedLocales) {
      final s = lookupAppLocalizations(l).inviteShareText('a-b-c', 'u', 'd');
      expect('\n'.allMatches(s).length, 8, reason: '$l');
      // the page link and the download page each on a line of their own
      expect(
        s.split('\n').map((x) => x.replaceAll(RegExp('[\u2068\u2069]'), '')),
        containsAll(['u', 'd']),
        reason: '$l',
      );
    }
  });
}
