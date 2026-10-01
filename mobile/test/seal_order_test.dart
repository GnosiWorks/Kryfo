// SPDX-License-Identifier: GPL-3.0-or-later
// seals started together for one person each get a message number of their
// own, so the other side opens every one of them. the stores are the real
// ones over rows kept in maps
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

typedef _Phone = ({SignalSession ss, String name});

Future<_Phone> _phone(String name) async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, name: name);
}

Future<void> _start(_Phone from, _Phone to) async {
  final spk = await to.ss.signedPreKeyStore.loadSignedPreKey(1);
  final pk = await to.ss.preKeyStore.loadPreKey(invitePreKeyId);
  await SessionBuilder(
    from.ss.sessionStore,
    from.ss.preKeyStore,
    from.ss.signedPreKeyStore,
    from.ss.identityStore,
    SignalProtocolAddress(to.name, 1),
  ).processPreKeyBundle(
    PreKeyBundle(
      to.ss.registrationId,
      1,
      pk.id,
      pk.getKeyPair().publicKey,
      spk.id,
      spk.getKeyPair().publicKey,
      spk.signature,
      to.ss.identityKeyPair.getPublicKey(),
    ),
  );
}

Future<String> _open(_Phone at, _Phone from, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final c = SessionCipher(
    at.ss.sessionStore,
    at.ss.preKeyStore,
    at.ss.signedPreKeyStore,
    at.ss.identityStore,
    SignalProtocolAddress(from.name, 1),
  );
  final plain = wire[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

void main() {
  test('seals started together all open, in any order', () async {
    final alice = await _phone('alice');
    final bob = await _phone('bob');
    await _start(alice, bob);
    // one round trip first, so the burst is plain messages on one chain
    expect(
      await _open(bob, alice, await alice.ss.encryptTo('bob', 'hi')),
      'hi',
    );
    expect(
      await _open(alice, bob, await bob.ss.encryptTo('alice', 'hey')),
      'hey',
    );
    final burst = await Future.wait([
      for (var i = 0; i < 4; i++) alice.ss.encryptTo('bob', 'm$i'),
    ]);
    expect(burst.toSet(), hasLength(4));
    for (final i in [2, 0, 3, 1]) {
      expect(await _open(bob, alice, burst[i]), 'm$i');
    }
  });

  test('openers started together all open', () async {
    final alice = await _phone('alice');
    final bob = await _phone('bob');
    await _start(alice, bob);
    final burst = await Future.wait([
      for (var i = 0; i < 3; i++) alice.ss.encryptTo('bob', 'o$i'),
    ]);
    for (var i = 0; i < 3; i++) {
      expect(await _open(bob, alice, burst[i]), 'o$i');
    }
  });

  test('a seal that fails does not hold up the next', () async {
    final alice = await _phone('alice');
    final bob = await _phone('bob');
    // no session with bob yet: the seal throws
    await expectLater(alice.ss.encryptTo('bob', 'x'), throwsA(anything));
    await _start(alice, bob);
    expect(
      await _open(bob, alice, await alice.ss.encryptTo('bob', 'after')),
      'after',
    );
  });
}
