// SPDX-License-Identifier: GPL-3.0-or-later
// the screenshot blocking lines say what android's secure flag cannot stop,
// in every language, and never promise more
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

const _explains = [
  'chatShotsBothPhones',
  'chatShotsBlocksBoth',
  'roomShotsBlocked',
];

// the photo toast and the three explaining lines
const _shotLines = ['chatTheNextPhotoYou', ..._explains];

// camera words per language, lowercase
const _cameraWords = {
  'ar': ['كاميرا', 'الكاميرا'],
  'de': ['kamera', 'fotograf'],
  'en': ['camera', 'photograph'],
  'es': ['cámara', 'camara', 'fotograf'],
  'fa': ['دوربین', 'کامیرا'],
  'fr': ['appareil photo', 'caméra', 'camera', 'photographi'],
  'id': ['kamera', 'memotret'],
  'it': ['fotocamera', 'videocamera', 'camera', 'fotograf'],
  'pt': ['câmera', 'câmara', 'camera', 'fotograf'],
  'ru': ['камер', 'фотоаппарат', 'сфотограф'],
  'tr': ['kamera', 'fotoğraf makine', 'fotoğrafını çek'],
  'uk': ['камер', 'фотоапарат', 'сфотограф'],
  'vi': ['máy ảnh', 'camera'],
  'zh': ['相机', '摄像头', '拍照'],
  'zh_Hant': ['相機', '攝影機', '拍照'],
};

const _langs = [
  'ar', 'de', 'en', 'es', 'fa', 'fr', 'id', 'it', //
  'pt', 'ru', 'tr', 'uk', 'vi', 'zh', 'zh_Hant',
];

void main() {
  test('the english lines name what blocking cannot stop', () {
    const limit =
        'It can’t stop apps allowed to read the screen, or a phone or app '
        'changed to get around it.';
    expect(l10n.chatShotsBothPhones, endsWith(limit));
    expect(l10n.chatShotsBlocksBoth, endsWith(limit));
    expect(l10n.roomShotsBlocked, endsWith(limit));
    expect(
      l10n.chatTheNextPhotoYou,
      'The next photo you send opens protected · Kryfo blocks screenshots of '
      'it',
    );
  });

  test('every language carries the same limit on each explaining line', () {
    for (final lang in _langs) {
      final m = _arb(lang);
      // the limit is the line's last sentence and the same in all three
      String tail(String k) {
        final v = (m[k] as String).trim();
        final cut = v.lastIndexOf(RegExp(r'[.。] ?'), v.length - 2);
        return v.substring(cut + 1).trim();
      }

      final tails = {for (final k in _explains) tail(k)};
      expect(tails, hasLength(1), reason: lang);
      expect(tails.single.length, greaterThan(20), reason: lang);
    }
  });

  test('no screenshot blocking line mentions a camera, in any language', () {
    expect(_cameraWords.keys.toSet(), _langs.toSet());
    for (final lang in _langs) {
      final m = _arb(lang);
      for (final k in _shotLines) {
        final v = (m[k] as String).toLowerCase();
        for (final w in _cameraWords[lang]!) {
          expect(v, isNot(contains(w)), reason: '$lang $k');
        }
      }
    }
  });

  test('no english line promises capture is impossible', () {
    final en = _arb('en');
    final absolute = RegExp(
      r"(cannot|can't|can’t|unable to) (screenshot|capture|record)|"
      r'screenshots? (is|are) impossible|no one can (screenshot|capture)',
      caseSensitive: false,
    );
    final bad = [
      for (final e in en.entries)
        if (!e.key.startsWith('@') &&
            e.value is String &&
            absolute.hasMatch(e.value as String))
          e.key,
    ];
    expect(bad, isEmpty);
  });
}
