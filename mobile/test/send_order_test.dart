// SPDX-License-Identifier: GPL-3.0-or-later
// a catch-up comes back from the relays in any order. one sender's
// messages on one chain are opened in the order they were sent; everyone
// else keeps their place. real signal messages, sealed by real stores
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/send_order.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

typedef _Phone = ({SignalSession ss, String name});
typedef _Got = ({String peer, String cipher});

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

List<_Got> _ordered(List<_Got> batch, {bool Function(String)? lane}) =>
    inSendOrder(
      batch,
      peer: (m) => m.peer,
      cipher: (m) => m.cipher,
      lane: lane,
    );

void main() {
  late _Phone me;
  late _Phone alice;
  late _Phone carol;

  setUp(() async {
    me = await _phone('me');
    alice = await _phone('alice');
    carol = await _phone('carol');
    await _start(alice, me);
    await _start(carol, me);
  });

  Future<List<String>> said(_Phone from, List<String> words) async => [
    for (final w in words) await from.ss.encryptTo('me', w),
  ];

  test('one sender\'s openers go back in the order they were sent', () async {
    final a = await said(alice, ['are you free?', 'at 6', 'at the station']);
    final batch = [
      (peer: 'x-alice', cipher: a[2]),
      (peer: 'x-alice', cipher: a[0]),
      (peer: 'x-alice', cipher: a[1]),
    ];
    final out = _ordered(batch);
    expect(
      [for (final m in out) await _open(me, alice, m.cipher)],
      ['are you free?', 'at 6', 'at the station'],
    );
  });

  test('plain messages on one chain too, others keep their places', () async {
    // a reply makes alice's next ones plain messages on a new chain
    expect(await _open(me, alice, (await said(alice, ['hi'])).single), 'hi');
    final back = await me.ss.encryptTo('alice', 'hey');
    expect(await _open(alice, me, back), 'hey');
    final a = await said(alice, ['one', 'two', 'three', 'four']);
    final c = await said(carol, ['c0']);
    final batch = <_Got>[
      (peer: 'x-alice', cipher: a[3]),
      (peer: 'x-carol', cipher: c[0]),
      (peer: 'x-alice', cipher: a[1]),
      (peer: 'room:abc', cipher: 'not signal'),
      (peer: 'x-alice', cipher: a[0]),
      (peer: 'x-alice', cipher: a[2]),
    ];
    final out = _ordered(batch);
    expect(out[1], batch[1]);
    expect(out[3], batch[3]);
    final alices = [
      for (final m in out)
        if (m.peer == 'x-alice') await _open(me, alice, m.cipher),
    ];
    expect(alices, ['one', 'two', 'three', 'four']);
  });

  test('a lane many senders share is left as it came', () async {
    final a = await said(alice, ['a0', 'a1']);
    final batch = [
      (peer: 'firstcontact', cipher: a[1]),
      (peer: 'firstcontact', cipher: a[0]),
    ];
    expect(_ordered(batch, lane: (p) => p == 'firstcontact'), batch);
  });
}
