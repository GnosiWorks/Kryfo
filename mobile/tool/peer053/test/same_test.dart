// SPDX-License-Identifier: GPL-3.0-or-later
// the peer runs 0.5.3's own signal layer: each file is the one the v0.5.3
// tag holds, byte for byte
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'signal_session.dart',
  'signal_stores.dart',
  'dlog.dart',
  'wire_pad.dart',
];

void main() {
  for (final f in _files) {
    test('$f is 0.5.3\'s', () async {
      final r = await Process.run('git', ['show', 'v0.5.3:mobile/lib/$f']);
      if (r.exitCode != 0) {
        markTestSkipped('no v0.5.3 tag here: ${r.stderr}');
        return;
      }
      expect(File('lib/$f').readAsStringSync(), r.stdout as String);
    });
  }

  test('the library is the one 0.5.3 locked', () async {
    final r = await Process.run('git', ['show', 'v0.5.3:mobile/pubspec.lock']);
    if (r.exitCode != 0) {
      markTestSkipped('no v0.5.3 tag here');
      return;
    }
    String entry(String lock) => RegExp(
      r'\n  libsignal_protocol_dart:\n((?:    .*\n)+)',
    ).firstMatch(lock)![1]!;

    expect(
      entry(File('pubspec.lock').readAsStringSync()),
      entry(r.stdout as String),
    );
  });
}
