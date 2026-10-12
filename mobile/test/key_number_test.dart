// SPDX-License-Identifier: GPL-3.0-or-later
// the key number on the pair-code screens: the sharer reads it off its own
// identity key, the joiner off the invite it fetched, and both land on the
// same 20 digits. another key, even under the same three words, gives
// another number, and the number is the one of the key the session the add
// builds really runs on. real libsignal over rows kept in maps
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/key_number.dart';
import 'package:kryfo/main.dart'
    show
        buildHaloUri,
        haloUriV3,
        inviteKeyNumber,
        inviteSessionKey,
        makePreKeyBundleB64,
        processPeerBundle;
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

const _words = 'thumb-behave-boring';

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

Future<SignalSession> _phone() async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return ss;
}

List<int> _own(SignalSession ss) =>
    ss.identityKeyPair.getPublicKey().serialize();

Future<String> _inviteOf(SignalSession ss, {String id = _words}) async =>
    haloUriV3(id, 'o.onion', await makePreKeyBundleB64(ss), 'ab' * 32);

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

  test('both phones land on the same number', () async {
    final alice = await _phone();
    final invite = await _inviteOf(alice);
    // the sharer, from its own key; the joiner, from what it fetched
    expect(inviteKeyNumber(invite), keyNumber(_own(alice)));
    expect(inviteKeyNumber(invite), isNotNull);
  });

  test('another key gives another number, under the same words too', () async {
    final alice = await _phone();
    final mallory = await _phone();
    final real = inviteKeyNumber(await _inviteOf(alice));
    final swapped = inviteKeyNumber(await _inviteOf(mallory));
    expect(swapped, isNotNull);
    expect(swapped, isNot(real));
    expect(keyNumber(_own(mallory)), isNot(keyNumber(_own(alice))));
  });

  test('the number is the one of the key the session runs on', () async {
    final alice = await _phone();
    final bob = await _phone();
    final invite = await _inviteOf(alice);
    final bundle = Uri.parse(invite).queryParameters['bundle']!;
    await processPeerBundle(_words, bundle, into: bob);
    final record = await bob.sessionStore.loadSession(
      SignalProtocolAddress(_words, 1),
    );
    final used = record.sessionState.getRemoteIdentityKey()!.serialize();
    expect(inviteSessionKey(invite), used);
    expect(inviteKeyNumber(invite), keyNumber(used));
    expect(keyNumber(used), keyNumber(_own(alice)));
  });

  test('an old card is numbered from its x key', () async {
    final alice = await _phone();
    final x = _hex(_own(alice).sublist(1));
    final card = buildHaloUri(_words, 'o.onion', x);
    expect(inviteKeyNumber(card), keyNumber(_own(alice)));
  });

  test('an invite that does not read has no number', () {
    expect(inviteKeyNumber('kryfo://share?id=$_words&onion=o&v=3'), isNull);
    expect(
      inviteKeyNumber('kryfo://share?id=$_words&onion=o&v=2&bundle=zz'),
      isNull,
    );
    expect(inviteKeyNumber('https://example.com'), isNull);
  });
}
