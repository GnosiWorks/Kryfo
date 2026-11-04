// SPDX-License-Identifier: GPL-3.0-or-later
// the key number a blocked key is listed by: 20 digits from the identity
// key, and another key gives another number. real libsignal over rows kept
// in maps
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/key_number.dart';
import 'package:kryfo/signal_session.dart';
import 'signal_kit.dart';

import 'mem_db.dart';

Future<SignalSession> _phone() async {
  final pair = testKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return ss;
}

List<int> _own(SignalSession ss) => ss.identity.public;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the derivation is fixed: domain, key, four groups of five', () {
    final k = [0x05, for (var i = 0; i < 32; i++) i];
    expect(keyNumber(k), '10009 47272 67828 22347');
    // the bare key reads as signal writes it
    expect(keyNumber(k.sublist(1)), keyNumber(k));
    final g = keyNumberGroups(k)!;
    expect(g, hasLength(4));
    expect(g, everyElement(matches(RegExp(r'^\d{5}$'))));
    // never under about 60 bits
    expect(4 * log(100000) / ln2, greaterThan(60));
    // what is not an identity key has no number
    expect(keyNumber(const []), isNull);
    expect(keyNumber(List.filled(33, 7)), isNull);
  });

  test('another key gives another number', () async {
    final alice = await _phone();
    final mallory = await _phone();
    expect(keyNumber(_own(mallory)), isNotNull);
    expect(keyNumber(_own(mallory)), isNot(keyNumber(_own(alice))));
  });
}
