// SPDX-License-Identifier: GPL-3.0-or-later
// a session started over keeps the old one archived. a late message leaves
// the current session as it was, so both sides go on reading each other.
// the everyday store and the dev chat's are the same code under another
// prefix, so both run here.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

typedef _Phone = ({SignalSession ss, MemDb db, String name, String prefix});

Future<_Phone> _phone(String name, String prefix) async {
  final pair = Curve.generateKeyPair();
  final db = MemDb();
  final ss = SignalSession();
  await ss.bootstrap(
    database: db,
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
    prefix: prefix,
  );
  return (ss: ss, db: db, name: name, prefix: prefix);
}

SignalProtocolAddress _addr(_Phone p) => SignalProtocolAddress(p.name, 1);

// [from] starts a session with [to] from its invite, archiving any it had
Future<void> _start(_Phone from, _Phone to) async {
  final spk = await to.ss.signedPreKeyStore.loadSignedPreKey(1);
  final pk = await to.ss.preKeyStore.loadPreKey(invitePreKeyId);
  await SessionBuilder(
    from.ss.sessionStore,
    from.ss.preKeyStore,
    from.ss.signedPreKeyStore,
    from.ss.identityStore,
    _addr(to),
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

Future<String> _send(_Phone from, _Phone to, String text) =>
    from.ss.encryptTo(to.name, text);

Future<String> _open(_Phone at, _Phone from, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final c = SessionCipher(
    at.ss.sessionStore,
    at.ss.preKeyStore,
    at.ss.signedPreKeyStore,
    at.ss.identityStore,
    _addr(from),
  );
  final plain = wire[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

Future<void> _roundTrip(_Phone a, _Phone b, String tag) async {
  expect(await _open(b, a, await _send(a, b, '$tag a')), '$tag a');
  expect(await _open(a, b, await _send(b, a, '$tag b')), '$tag b');
}

// alice and bob with a first session, a message alice sent on it still in
// flight, and a second session alice started that bob has answered on.
// with [opener] the late message is one of alice's first ones, sent before
// bob answered, so it still carries the prekey
Future<({_Phone alice, _Phone bob, String late})> _startedOver(
  String prefix, {
  bool opener = false,
}) async {
  final alice = await _phone('alice', prefix);
  final bob = await _phone('bob', prefix);
  await _start(alice, bob);
  final String late;
  if (opener) {
    final first = await _send(alice, bob, 'first a');
    late = await _send(alice, bob, 'late');
    expect(await _open(bob, alice, first), 'first a');
    expect(
      await _open(alice, bob, await _send(bob, alice, 'first b')),
      'first b',
    );
  } else {
    await _roundTrip(alice, bob, 'first');
    late = await _send(alice, bob, 'late');
  }
  await _start(alice, bob);
  expect(await _open(bob, alice, await _send(alice, bob, 'again')), 'again');
  expect(await _open(alice, bob, await _send(bob, alice, 'back')), 'back');
  return (alice: alice, bob: bob, late: late);
}

Future<Uint8List?> _stored(_Phone at, _Phone peer) async {
  final rows = await at.db.query(
    '${at.prefix}sessions',
    where: 'address = ?',
    whereArgs: [peer.name],
  );
  return rows.isEmpty ? null : rows.first['record'] as Uint8List;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final prefix in ['', kDevSignalPrefix]) {
    final store = prefix.isEmpty ? 'everyday store' : 'dev chat store';

    test('$store: replies open both ways after a late message, '
        'the sender of it writing first', () async {
      final (:alice, :bob, :late) = await _startedOver(prefix);
      expect(await _open(bob, alice, late), 'late');
      for (var i = 0; i < 3; i++) {
        await _roundTrip(alice, bob, 'after $i');
      }
    });

    test('$store: replies open both ways after a late message, '
        'the reader of it writing first', () async {
      final (:alice, :bob, :late) = await _startedOver(prefix);
      final inFlight = await _send(bob, alice, 'in flight');
      expect(await _open(bob, alice, late), 'late');
      expect(await _open(alice, bob, await _send(bob, alice, 'next')), 'next');
      expect(await _open(alice, bob, inFlight), 'in flight');
      for (var i = 0; i < 3; i++) {
        await _roundTrip(bob, alice, 'after $i');
      }
    });

    test('$store: replies open both ways after a late first message', () async {
      final (:alice, :bob, :late) = await _startedOver(prefix, opener: true);
      expect(base64Decode(late).first, CiphertextMessage.prekeyType);
      expect(await _open(bob, alice, late), 'late');
      for (var i = 0; i < 3; i++) {
        await _roundTrip(alice, bob, 'after $i');
      }
    });

    test(
      '$store: a message that opens under no state stores nothing',
      () async {
        final (:alice, :bob, :late) = await _startedOver(prefix);
        final before = await _stored(bob, alice);
        final stranger = await _phone('alice', prefix);
        await _start(stranger, bob);
        final foreign = base64Decode(await _send(stranger, bob, 'not yours'));
        await expectLater(
          _open(
            bob,
            alice,
            base64Encode([
              CiphertextMessage.whisperType,
              ...PreKeySignalMessage(
                Uint8List.fromList(foreign.sublist(1)),
              ).getWhisperMessage().serialize(),
            ]),
          ),
          throwsException,
        );
        expect(await _stored(bob, alice), before);
        expect(await _open(bob, alice, late), 'late');
      },
    );

    test('$store: a record holds each session once', () async {
      final (:alice, :bob, :late) = await _startedOver(prefix);
      expect(await _open(bob, alice, late), 'late');
      final record = await bob.ss.sessionStore.loadSession(_addr(alice));
      final keys = [
        base64Encode(record.sessionState.aliceBaseKey),
        for (final s in record.previousSessionStates)
          base64Encode(s.aliceBaseKey),
      ];
      expect(keys.toSet(), hasLength(keys.length));
      expect(keys, hasLength(2));
    });
  }
}
