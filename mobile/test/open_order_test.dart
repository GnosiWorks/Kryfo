// SPDX-License-Identifier: GPL-3.0-or-later
// an open from someone and a seal to them that run side by side both keep
// their step of the session, so the seals after it still each get a number
// of their own. real libsignal over rows kept in maps
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show signalDecrypt;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

const _bob = 'bob-open-order';

Future<SignalSession> _store() async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return ss;
}

Future<void> _start(SignalSession from, SignalSession to, String toName) async {
  final spk = await to.signedPreKeyStore.loadSignedPreKey(1);
  final pk = await to.preKeyStore.loadPreKey(invitePreKeyId);
  await SessionBuilder(
    from.sessionStore,
    from.preKeyStore,
    from.signedPreKeyStore,
    from.identityStore,
    SignalProtocolAddress(toName, 1),
  ).processPreKeyBundle(
    PreKeyBundle(
      to.registrationId,
      1,
      pk.id,
      pk.getKeyPair().publicKey,
      spk.id,
      spk.getKeyPair().publicKey,
      spk.signature,
      to.identityKeyPair.getPublicKey(),
    ),
  );
}

Future<String> _bobOpens(SignalSession bob, String from, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final c = SessionCipher(
    bob.sessionStore,
    bob.preKeyStore,
    bob.signedPreKeyStore,
    bob.identityStore,
    SignalProtocolAddress(from, 1),
  );
  final plain = wire[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

void main() {
  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  for (final openFirst in [true, false]) {
    test('a seal beside an open keeps its number '
        '(${openFirst ? 'open' : 'seal'} started first)', () async {
      final bob = await _store();
      final name = '$_bob-$openFirst';
      // a hello each way, the way a chat has one
      await _start(signalSession, bob, name);
      expect(
        await _bobOpens(bob, 'me', await signalSession.encryptTo(name, 'hey')),
        'hey',
      );
      expect(await signalDecrypt(name, await bob.encryptTo('me', 'yo')), 'yo');
      // two from bob on one chain: the second opens while a reply seals
      final m1 = await bob.encryptTo('me', 'm1');
      final m2 = await bob.encryptTo('me', 'm2');
      expect(await signalDecrypt(name, m1), 'm1');
      final Future<String?> open;
      final Future<String> seal;
      if (openFirst) {
        open = signalDecrypt(name, m2);
        seal = signalSession.encryptTo(name, 'r1');
      } else {
        seal = signalSession.encryptTo(name, 'r1');
        open = signalDecrypt(name, m2);
      }
      expect(await open, 'm2');
      final r1 = await seal;
      final r2 = await signalSession.encryptTo(name, 'r2');
      expect(r2, isNot(r1));
      expect(await _bobOpens(bob, 'me', r1), 'r1');
      expect(await _bobOpens(bob, 'me', r2), 'r2');
    });
  }
}
