// SPDX-License-Identifier: GPL-3.0-or-later
// the transport screen's last stop: every code the platform sends has its
// own words, in the person's language
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/transport_screen.dart' show lastStopWord;

// the codes ExitWord.kt can send, read from its source
Set<String> _sent() {
  final src = File(
    'android/app/src/main/kotlin/app/kryfo/ExitWord.kt',
  ).readAsStringSync();
  return {
    for (final m in RegExp(r'(?:->|return) "([a-z_]+)"').allMatches(src))
      m.group(1)!,
  };
}

void main() {
  tearDown(() => setL10nLocale(const Locale('en')));

  test('every code has words of its own, and only stopped is the rest', () {
    setL10nLocale(const Locale('en'));
    final codes = _sent();
    expect(codes, containsAll(['by_you', 'by_phone', 'by_security_app']));
    final words = {for (final c in codes) c: lastStopWord(c)};
    expect(words.values.toSet(), hasLength(codes.length));
    for (final c in codes.difference({'stopped'})) {
      expect(words[c], isNot(lastStopWord('stopped')), reason: c);
    }
    expect(lastStopWord('by_security_app'), 'Stopped by the security app');
    expect(lastStopWord('by_phone'), 'Stopped by the phone');
    expect(lastStopWord(null), 'Stopped');
    expect(lastStopWord('something new'), 'Stopped');
  });

  test('in the person\'s language, never the platform\'s english', () {
    setL10nLocale(const Locale('de'));
    expect(lastStopWord('by_you'), 'Von dir beendet');
    for (final c in _sent()) {
      setL10nLocale(const Locale('en'));
      final en = lastStopWord(c);
      for (final l in ['de', 'fr', 'ru', 'zh', 'ar']) {
        setL10nLocale(Locale(l));
        expect(lastStopWord(c), isNot(en), reason: '$l $c');
      }
    }
  });
}
