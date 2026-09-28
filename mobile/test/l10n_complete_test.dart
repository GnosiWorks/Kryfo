// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// words every language writes the same way: a message made only of these
// may read the same as the english
const _names = {
  'kryfo',
  'tor',
  'onion',
  'nostr',
  'obfs4',
  'snowflake',
  'webtunnel',
  'age',
  'bitcoin',
  'monero',
  'lightning',
  'solana',
  'ethereum',
  'btc',
  'xmr',
  'sol',
  'eth',
  'sms',
  'qr',
  'pin',
  'gps',
  'exif',
  'xmp',
  'iptc',
  'png',
  'jpeg',
  'heic',
  'mp4',
  'wi',
  'fi',
  'ip',
  'id',
  'b',
  'h',
  'm',
  's',
  'd',
  'min',
  'kb',
  'mb',
  'gb',
  'km',
  'ok',
  'wren',
  'github',
  'f',
  'droid',
  'unifiedpush',
  'ntfy',
  'pro',
  'natural',
  'earth',
  'geonames',
  // the developer's name, in Latin letters everywhere
  'marios',
};
// what only the developer's own phone shows stays in english there, in
// every language
const _devPhoneOnly = {
  'supportTitle',
  'supportWaiting',
  'supportSectionWaiting',
  'supportSectionAnswered',
  'supportSectionDone',
  'supportEmpty',
  'supportEmptyLine',
  'supportMarkDone',
  'supportReopen',
  'supportMarkAllDone',
  'supportMenu',
  'supportDeleteLine',
  'supportNotifNewChats',
  'supportNotifNewMessages',
  'supportChannelName',
  'supportChannelLine',
  'supportResetPinned',
};
// read and kept: the word is the same in that language
// (test/l10n_same_as_english.json, key lists per language)
final _same = {
  for (final e
      in (jsonDecode(File('test/l10n_same_as_english.json').readAsStringSync())
              as Map<String, dynamic>)
          .entries)
    e.key: {...(e.value as List).cast<String>()},
};

Map<String, dynamic> _arb(String f) =>
    jsonDecode(File('lib/l10n/$f').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final en = _arb('app_en.arb');
  final keys = en.keys
      .where((k) => !k.startsWith('@') && !_devPhoneOnly.contains(k))
      .toList();
  final files = Directory('lib/l10n')
      .listSync()
      .map((f) => f.uri.pathSegments.last)
      .where(
        (f) => f.startsWith('app_') && f.endsWith('.arb') && f != 'app_en.arb',
      );
  test('the developer phone keeps its english', () {
    for (final k in _devPhoneOnly) {
      expect(en[k], isA<String>(), reason: k);
    }
  });
  for (final f in files) {
    final lang = f.substring(4, f.length - 4);
    test('$lang has every key and nothing left in english', () {
      final tr = _arb(f);
      final missing = [
        for (final k in keys)
          if (!tr.containsKey(k)) k,
      ];
      final extra = [
        for (final k in tr.keys)
          if (!k.startsWith('@') && !en.containsKey(k)) k,
      ];
      final english = <String>[];
      for (final k in keys) {
        if (tr[k] != en[k] || (_same[lang]?.contains(k) ?? false)) continue;
        final words = RegExp(r'[a-z]+')
            .allMatches(
              (en[k] as String)
                  .replaceAll(RegExp(r'\{[^{}]*\}'), '')
                  .toLowerCase(),
            )
            .map((m) => m[0]!)
            .where((w) => !_names.contains(w));
        if (words.isNotEmpty) english.add('$k: ${en[k]}');
      }
      expect(missing, isEmpty, reason: 'missing');
      expect(extra, isEmpty, reason: 'not in english');
      expect(english, isEmpty, reason: 'still english');
    });
  }
}
