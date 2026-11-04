// SPDX-License-Identifier: GPL-3.0-or-later
// the decoy's fallback invite carries its bundle encoded, so any byte of it
// reads back as it was; one proof-of-work check serves every first contact
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show parseHaloUri, quietInviteUri;

import 'source_body.dart';

const _w = 'thumb-behave-boring';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the decoy\'s invite reads back the bundle it was made with', () {
    // every byte base64 has that a query reads as something else
    const bundle = 'ab+cd/ef==';
    for (final fc in ['ab' * 32, 'error: none']) {
      final uri = quietInviteUri(_w, 'q.onion', bundle, fc);
      expect(uri, isNot(contains(' ')));
      final p = parseHaloUri(uri);
      expect(p?['bundle'], bundle, reason: fc);
      expect(p?['v'], fc.startsWith('error') ? '2' : '3');
    }
    // the decoy hands out its v4 invite, and this one only when that one
    // could not be made
    final src = sourceOf('lib/app/state.dart');
    expect(src, contains('invite = inviteLink(row.link);'));
    expect(src, contains('invite = quietInviteUri(id, onion, bundle, fc);'));
  });

  test('one proof-of-work check for a first contact, shared', () {
    final src = [
      'lib/main.dart',
      for (final f in Directory('lib/app').listSync()) f.path,
    ].map((f) => File(f).readAsStringSync()).join('\n');
    // the gate and a deleted chat's words ask the same thing
    expect(RegExp(r'verifyPow\(').allMatches(src), hasLength(1));
    expect(
      RegExp(
        r'!vouched && fromBackPair && !firstPowHolds\(env\)',
      ).hasMatch(src),
      isTrue,
    );
    expect(RegExp(r'firstPowHolds\(env\) &&').hasMatch(src), isTrue);
  });
}
