// SPDX-License-Identifier: GPL-3.0-or-later
// verified names the key it was given for. it counts only while that key is
// the one held for them: another key, however it came, reads as not verified.
// a mark is only taken for the number that was on screen. contacts verified
// before the mark named a key are tied to the key held for them at upgrade.
// the rows are the app's own tables, kept in maps
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show heldKeyHex, markVerified, tieVerifiedToKeys, verifiedNow;
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

const _peer = 'calm-orbit-lantern';
final _keyA = List<int>.generate(32, (i) => i + 1);
final _keyB = List<int>.generate(32, (i) => 200 - i);
String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<MemDb> _db({
  List<int>? identity,
  String xpub = '',
  int verified = 0,
}) async {
  final db = MemDb();
  await db.insert('contacts', {
    'halo_id': _peer,
    'onion': 'o',
    'xpub': xpub,
    'first_seen': 1,
    'last_seen': 1,
    'verified': verified,
  });
  if (identity != null) {
    await db.insert('peer_identities', {
      'address': _peer,
      'identity_key': Uint8List.fromList([5, ...identity]),
    });
  }
  return db;
}

Future<bool> _verified(MemDb db) async {
  final rows = await verifiedNow(db, db.rows('contacts'));
  return rows.first['verified'] == 1;
}

void main() {
  test('the key held is the one their sessions are built on, else the '
      "card's", () async {
    expect(
      await heldKeyHex(await _db(identity: _keyA, xpub: _hex(_keyB)), _peer),
      _hex(_keyA),
    );
    expect(
      await heldKeyHex(await _db(xpub: _hex(_keyB).toUpperCase()), _peer),
      _hex(_keyB),
    );
    expect(await heldKeyHex(await _db(), _peer), isNull);
  });

  test('a mark is taken only for the key on screen, and counts while that '
      'key is held', () async {
    final db = await _db(identity: _keyA);
    expect(await markVerified(db, _peer, true, key: _hex(_keyB)), isFalse);
    expect(db.rows('contacts').first['verified'], 0);
    expect(await markVerified(db, _peer, true, key: _hex(_keyA)), isTrue);
    expect(db.rows('contacts').first['verified_key'], _hex(_keyA));
    expect(await _verified(db), isTrue);
    // their key moves on without a word through the store
    await db.update(
      'peer_identities',
      {
        'identity_key': Uint8List.fromList([5, ..._keyB]),
      },
      where: 'address = ?',
      whereArgs: [_peer],
    );
    expect(await _verified(db), isFalse);
    // taking the mark off forgets the key
    expect(await markVerified(db, _peer, false), isTrue);
    expect(db.rows('contacts').first['verified_key'], isNull);
  });

  test(
    'a new key saved for them takes the mark off, the same key leaves it',
    () async {
      final db = await _db(identity: _keyA);
      await markVerified(db, _peer, true, key: _hex(_keyA));
      final store = HaloIdentityKeyStore(db, generateIdentityKeyPair(), 1);
      final addr = SignalProtocolAddress(_peer, 1);
      await store.saveIdentity(
        addr,
        IdentityKey(Curve.decodePoint(Uint8List.fromList([5, ..._keyA]), 0)),
      );
      expect(db.rows('contacts').first['verified'], 1);
      await store.saveIdentity(
        addr,
        IdentityKey(Curve.decodePoint(Uint8List.fromList([5, ..._keyB]), 0)),
      );
      expect(db.rows('contacts').first['verified'], 0);
    },
  );

  test('a contact verified before the upgrade is tied to the key held now; '
      'one with no key held loses the mark', () async {
    final held = await _db(identity: _keyA, verified: 1);
    await tieVerifiedToKeys(held);
    expect(held.rows('contacts').first['verified_key'], _hex(_keyA));
    expect(await _verified(held), isTrue);
    final none = await _db(verified: 1);
    await tieVerifiedToKeys(none);
    expect(none.rows('contacts').first['verified'], 0);
  });

  test('made on create and on the upgrade to 66', () {
    final src = File('lib/main.dart').readAsStringSync();
    final create = src.indexOf('onCreate: (db, _) async {');
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    expect(src.substring(create, upgrade), contains('verified_key TEXT,'));
    final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
    expect(steps, contains('if (oldV < 66) {'));
    expect(steps, contains('await verifiedKeyColumn(db);'));
  });
}
