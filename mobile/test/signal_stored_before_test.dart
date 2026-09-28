// SPDX-License-Identifier: GPL-3.0-or-later
// signal stores written by libsignal_protocol_dart 0.7.4 on protobuf 4,
// three identities as the app keeps them: what a phone holds must open
// after a library update. the fixture carries a session with an archived
// state, a skipped message key, a one-time prekey someone has written on and
// messages still in flight both ways.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart' show kSignalTables;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

final _fixture =
    jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
        as Map<String, dynamic>;

Object? _value(Object? v) => v is Map ? base64Decode(v['b64'] as String) : v;

List<Map<String, dynamic>> _rows(String who) => [
  for (final r in (_fixture[who] as Map)['rows'] as List)
    Map<String, dynamic>.from(r as Map),
];

Future<({SignalSession ss, MemDb db})> _load(String who) async {
  final db = MemDb();
  for (final r in _rows(who)) {
    await db.insert(r['t'] as String, {
      for (final e in (r['row'] as Map).entries)
        e.key as String: _value(e.value),
    });
  }
  final me = _fixture[who] as Map;
  final ss = SignalSession();
  await ss.bootstrap(
    database: db,
    xPubBytes: base64Decode(me['pub'] as String),
    xPrivBytes: base64Decode(me['priv'] as String),
  );
  return (ss: ss, db: db);
}

Future<String> _open(SignalSession ss, String peer, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final c = SessionCipher(
    ss.sessionStore,
    ss.preKeyStore,
    ss.signedPreKeyStore,
    ss.identityStore,
    SignalProtocolAddress(peer, 1),
  );
  final plain = wire[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

String _wire(String k) => (_fixture['wire'] as Map)[k] as String;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opening the stores keeps every key as it was written', () async {
    for (final who in ['alice', 'bob', 'carol']) {
      final (:ss, :db) = await _load(who);
      for (final r in _rows(who)) {
        final t = r['t'] as String;
        if (t == 'sessions' || t == 'peer_identities') continue;
        final key = t == 'signal_meta' ? 'k' : 'id';
        final now = await db.query(
          t,
          where: '$key = ?',
          whereArgs: [(r['row'] as Map)[key]],
        );
        expect(now, hasLength(1), reason: '$who $t');
        for (final e in (r['row'] as Map).entries) {
          expect(now.first[e.key], _value(e.value), reason: '$who $t ${e.key}');
        }
      }
      // nothing was made fresh: a new signed prekey would orphan every
      // bundle already handed out
      for (final t in kSignalTables) {
        final before = _rows(who).where((r) => r['t'] == t).length;
        expect(await db.query(t), hasLength(before), reason: '$who $t');
      }
      expect(ss.ready, isTrue);
    }
  });

  test('stored records read and write back byte for byte', () async {
    for (final who in ['alice', 'bob', 'carol']) {
      for (final r in _rows(who)) {
        final t = r['t'] as String;
        final raw = _value((r['row'] as Map)['record']);
        if (raw is! Uint8List) continue;
        final again = switch (t) {
          'sessions' => SessionRecord.fromSerialized(raw).serialize(),
          'prekeys' => PreKeyRecord.fromBuffer(raw).serialize(),
          'signed_prekeys' => SignedPreKeyRecord.fromSerialized(
            raw,
          ).serialize(),
          _ => throw StateError('unexpected table $t'),
        };
        expect(again, raw, reason: '$who $t');
      }
    }
  });

  test('messages on archived states open from the stored record', () async {
    // each on a load of its own: a message for an archived state is tried
    // against the current one first, and the tries are kept apart here
    Future<String> bobOpens(List<String> wires) async {
      final bob = (await _load('bob')).ss;
      final out = <String>[];
      for (final w in wires) {
        out.add(await _open(bob, 'alice', _wire(w)));
      }
      return out.join(', ');
    }

    // the first session, archived when alice started over, and the key it
    // kept for a2 since a3 overtook it
    expect(await bobOpens(['a4', 'a2']), 'a4 old chain, a2 skipped');
    // bob's reply on that first session, archived on alice's side
    final alice = (await _load('alice')).ss;
    expect(await _open(alice, 'bob', _wire('b2')), 'b2 old session');
  });

  test('messages in flight open and the ratchet goes on', () async {
    final alice = (await _load('alice')).ss;
    final bob = (await _load('bob')).ss;
    final carol = (await _load('carol')).ss;

    // the current session
    expect(await _open(bob, 'alice', _wire('a6')), 'a6 pending');
    // a first message on one of bob's one-time prekeys, which it uses up
    expect(await bob.preKeyStore.containsPreKey(3), isTrue);
    expect(await _open(bob, 'carol', _wire('c1')), 'c1 first');
    expect(await bob.preKeyStore.containsPreKey(3), isFalse);

    // on from there, both ways
    for (var i = 0; i < 3; i++) {
      expect(
        await _open(alice, 'bob', await bob.encryptTo('alice', 'b$i')),
        'b$i',
      );
      expect(
        await _open(bob, 'alice', await alice.encryptTo('bob', 'a$i')),
        'a$i',
      );
      expect(
        await _open(carol, 'bob', await bob.encryptTo('carol', 'b$i')),
        'b$i',
      );
      expect(
        await _open(bob, 'carol', await carol.encryptTo('bob', 'c$i')),
        'c$i',
      );
    }
    // a message opens once
    await expectLater(
      _open(bob, 'alice', _wire('a6')),
      throwsA(isA<DuplicateMessageException>()),
    );
  });

  test('stored identities are the ones the peers hold', () async {
    final alice = (await _load('alice')).ss;
    final bob = (await _load('bob')).ss;
    final carol = (await _load('carol')).ss;
    final bobKnowsAlice = await bob.identityStore.getIdentity(
      SignalProtocolAddress('alice', 1),
    );
    expect(
      bobKnowsAlice?.serialize(),
      alice.identityKeyPair.getPublicKey().serialize(),
    );
    final aliceKnowsBob = await alice.identityStore.getIdentity(
      SignalProtocolAddress('bob', 1),
    );
    expect(
      aliceKnowsBob?.serialize(),
      bob.identityKeyPair.getPublicKey().serialize(),
    );
    final carolKnowsBob = await carol.identityStore.getIdentity(
      SignalProtocolAddress('bob', 1),
    );
    expect(
      carolKnowsBob?.serialize(),
      bob.identityKeyPair.getPublicKey().serialize(),
    );
  });
}
