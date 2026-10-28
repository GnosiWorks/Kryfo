// SPDX-License-Identifier: GPL-3.0-or-later
// libsignal_protocol_dart is gone from the app: not in pubspec.yaml, not in
// pubspec.lock, imported nowhere, so no path can build a classic session or
// read a record without the shim. the guard refuses a card without the
// kyber prekey before the shim sees it
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_session.dart';

import 'shim_lib.dart';

const _old = 'libsignal_protocol_dart';

// the generators that run inside an old checkout to make its fixtures, and
// the peer that plays a 0.5.3 phone: each is its own package, never built
// into the app
bool _outside(String path) =>
    RegExp(r'^test/fixtures/upgrade_0\d\d/make_0\d\d\.dart$').hasMatch(path) ||
    path.startsWith('tool/peer053/');

// the code of a dart file without its comments and string contents, so a
// mention in either does not count
String _code(String src) => src
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '')
    .replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), "''")
    .replaceAll(RegExp(r'"(?:[^"\\\n]|\\.)*"'), '""');

final _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

// what the old library built or read sessions with
final _starts = RegExp(
  r'\b(SessionBuilder|processPreKeyBundle|SessionCipher|PreKeySignalMessage|'
  r'decryptWithCallback|SessionRecord|PreKeyBundle|SignalProtocolAddress)\b',
);

Iterable<String> _dart(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .map((f) => f.path.replaceAll(r'\', '/'));

void main() {
  test('the old library is not a dependency, direct or not', () {
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains(_old)));
    expect(File('pubspec.lock').readAsStringSync(), isNot(contains(_old)));
    final config = File('.dart_tool/package_config.json');
    if (config.existsSync()) {
      expect(config.readAsStringSync(), isNot(contains(_old)));
    }
  });

  test('nothing in the app or its tests imports it', () {
    final found = <String>[];
    for (final path in [..._dart('lib'), ..._dart('test'), ..._dart('tool')]) {
      if (_outside(path)) continue;
      for (final m in _directive.allMatches(File(path).readAsStringSync())) {
        if (m[1]!.contains(_old)) found.add('$path imports ${m[1]}');
      }
    }
    expect(found, isEmpty);
  });

  test('nothing in lib names its session types', () {
    final found = <String>[];
    for (final path in _dart('lib')) {
      for (final m in _starts.allMatches(_code(File(path).readAsStringSync()))) {
        found.add('$path: ${m[1]}');
      }
    }
    expect(found, isEmpty);
  });

  test('the scans see what they look for', () {
    int count(String src) => _starts.allMatches(_code(src)).length;
    expect(count('final c = SessionCipher(a, b, c, d, addr);'), 1);
    expect(count('await sig.SessionBuilder(a, b).x();'), 1);
    expect(count('b.processPreKeyBundle(card);'), 1);
    expect(count('// SessionCipher(a).decrypt(m)'), 0);
    expect(count("dlog('no SessionBuilder here');"), 0);
    final d = _directive.allMatches(
      "import 'package:$_old/$_old.dart' show Curve;\n",
    );
    expect(d.single[1], contains(_old));
    expect(_outside('test/fixtures/upgrade_053/make_053.dart'), isTrue);
    expect(_outside('test/fixtures/upgrade_053/other.dart'), isFalse);
    expect(_outside('test/upgrade_053_test.dart'), isFalse);
  });

  test('the guard refuses a card without the kyber prekey', () async {
    expect(() => lsBundleOf(shim!, _noKyber), throwsA(isA<ClassicRefused>()));
    final b = Phone();
    await b.openLs();
    final card = await b.classicCard();
    expect(() => lsBundleOf(shim!, card), throwsA(isA<ClassicRefused>()));
    expect(() => cardBundle(card), throwsA(isA<ClassicRefused>()));
  }, skip: needsShim);
}

// a card with none of the kyber fields, its keys never read: the guard
// looks for the kyber prekey before anything else
const _noKyber =
    'eyJyZWdpc3RyYXRpb25JZCI6MSwiZGV2aWNlSWQiOjEsInNpZ25lZFByZUtleUlkIjoxfQ==';
