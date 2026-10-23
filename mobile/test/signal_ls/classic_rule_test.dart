// SPDX-License-Identifier: GPL-3.0-or-later
// libsignal_protocol_dart builds no new session outside the one legacy file
// that still does it, so new code cannot add a classic first contact. the
// shim layer does not touch the old library at all, and refuses a card
// without the kyber prekey before the shim sees it
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_session_ls.dart';

import 'shim_lib.dart';

// the one file allowed to build a session with the old library, until the
// app runs on the shim and it goes
const _legacy = 'lib/signal_session.dart';

// the shim layer's own files: no import of the old library at all
const _shimLayer = [
  'lib/signal_session_ls.dart',
  'lib/signal_stores_ls.dart',
  'lib/signal_ffi/kryfo_signal.dart',
];

final _builds = RegExp(r'\bSessionBuilder\b|\bprocessPreKeyBundle\b');

// the code of a dart file without its comments and string contents, so a
// mention in either does not count
String _code(String src) => src
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '')
    .replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), "''")
    .replaceAll(RegExp(r'"(?:[^"\\\n]|\\.)*"'), '""');

void main() {
  test('only the legacy file builds a session with the old library', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path == _legacy) continue;
      final code = _code(f.readAsStringSync());
      for (final m in _builds.allMatches(code)) {
        found.add('$path: ${m[0]}');
      }
    }
    expect(found, isEmpty, reason: 'only $_legacy may build a session');
    // and the legacy file still exists, so this test is changed when it goes
    expect(_builds.hasMatch(_code(File(_legacy).readAsStringSync())), isTrue);
  });

  test('the old library builds sessions only where it already does', () {
    // every way libsignal_protocol_dart starts a session: as the initiator
    // from a card, and as the responder on an opener, which a SessionCipher
    // does inside decrypt and decryptWithCallback. lib/app is a part of
    // main.dart and sees the library without importing it, so all of lib
    // is read
    final found = <String, Map<String, int>>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      final code = _code(f.readAsStringSync());
      for (final m in _starts.allMatches(code)) {
        (found[path] ??= {}).update(m[1]!, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    expect(found, _startsAllowed);
  });

  test('the session scan sees the responder path', () {
    int count(String src) => _starts.allMatches(_code(src)).length;
    expect(count('final c = SessionCipher(a, b, c, d, addr);'), 1);
    expect(count('await sig.SessionCipher(a, b, c, d, e).decrypt(m);'), 1);
    expect(count('cipher.decryptWithCallback(pkm, check);'), 1);
    expect(count('final m = PreKeySignalMessage(body);'), 1);
    expect(count('cipher.decryptFromSignalWithCallback(m, check);'), 0);
    expect(count('// SessionCipher(a).decrypt(m)'), 0);
  });

  test('the scan sees through a prefix and past comments', () {
    expect(
      _builds.hasMatch(_code('await sig.SessionBuilder(a, b).x();')),
      isTrue,
    );
    expect(_builds.hasMatch(_code('b.processPreKeyBundle(card);')), isTrue);
    expect(
      _builds.hasMatch(_code('// a SessionBuilder in a comment')),
      isFalse,
    );
    expect(_builds.hasMatch(_code("dlog('no SessionBuilder here');")), isFalse);
  });

  test('the shim layer never imports the old library itself', () {
    for (final path in _shimLayer) {
      final src = File(path).readAsStringSync();
      expect(
        src.contains('package:libsignal_protocol_dart'),
        isFalse,
        reason: path,
      );
    }
  });

  test('nothing in the app calls the shim layer yet', () {
    expect(kUseLibsignalShim, isFalse);
    final users = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (_shimLayer.contains(path)) continue;
      if (_code(f.readAsStringSync()).contains('SignalSessionLs')) {
        users.add(path);
      }
    }
    expect(users, isEmpty);
  });

  test('the guard refuses a card without the kyber prekey', () async {
    expect(() => lsBundleOf(shim!, _noKyber), throwsA(isA<ClassicRefused>()));
    final b = Phone();
    await b.openOld();
    final card = await b.oldCard();
    expect(() => lsBundleOf(shim!, card), throwsA(isA<ClassicRefused>()));
  }, skip: needsShim);
}

// what starts a session in the old library, or reads an opener for one
final _starts = RegExp(
  r'\b(SessionBuilder|processPreKeyBundle|SessionCipher|PreKeySignalMessage|'
  r'decryptWithCallback)\b',
);

// where each of those stands today: the initiator in the legacy file, the
// responder in lib/app/signal.dart, and send_order.dart reading an opener's
// inner message for its counter only. any new place fails here; when the
// app runs on the shim these go and the map shrinks to nothing
const _startsAllowed = {
  'lib/signal_session.dart': {
    'SessionBuilder': 1,
    'processPreKeyBundle': 1,
    'SessionCipher': 1,
  },
  'lib/app/signal.dart': {
    'SessionCipher': 2,
    'PreKeySignalMessage': 1,
    'decryptWithCallback': 2,
  },
  'lib/send_order.dart': {'PreKeySignalMessage': 1},
};

// a card with none of the kyber fields, its keys never read: the guard
// looks for the kyber prekey before anything else
const _noKyber =
    'eyJyZWdpc3RyYXRpb25JZCI6MSwiZGV2aWNlSWQiOjEsInNpZ25lZFByZUtleUlkIjoxfQ==';
