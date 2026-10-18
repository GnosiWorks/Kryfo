// SPDX-License-Identifier: GPL-3.0-or-later
// the signal stores for the libsignal shim: the same tables and the same
// record bytes signal_stores.dart keeps, so a store written by
// libsignal_protocol_dart opens here as it is. records go in and out as
// bytes; only the kyber prekeys are new, in tables of their own

import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'devchat/dev_key.dart';
import 'signal_ffi/kryfo_signal.dart';
import 'signal_stores.dart' show invitePreKeyId, onPeerKeyChanged;

// the tables the shim adds to a store, without their prefix
const kSignalTablesLs = ['kyber_prekeys', 'kyber_used'];

/// the kyber tables of the store under [prefix]. the rest of the store is
/// made by the app's schema as before
Future<void> ensureLsTables(Database db, {String prefix = ''}) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}kyber_prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL, last_resort INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)',
  );
  // a last resort kyber key outlives its use: the base keys it opened for,
  // so a replayed opener does not build a second session on it
  await db.execute(
    'CREATE TABLE IF NOT EXISTS ${prefix}kyber_used (kyber_id INTEGER NOT NULL, signed_id INTEGER NOT NULL, base_key BLOB NOT NULL, PRIMARY KEY (kyber_id, base_key))',
  );
}

/// the kyber prekey an invite carries, kept as the invite's ec prekey is
const kInviteKyberId = 1;

class LsIdentityStore {
  LsIdentityStore(
    this._db,
    this.identity,
    this.registrationId, {
    String prefix = '',
  }) : _t = '${prefix}peer_identities';

  final Database _db;
  final LsIdentity identity;
  final int registrationId;
  final String _t;

  /// the key held for [peer], 33 bytes
  Future<Uint8List?> getIdentity(String peer) async {
    final rows = await _db.query(
      _t,
      where: 'address = ?',
      whereArgs: [peer],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList(rows.first['identity_key'] as List<int>);
  }

  /// the only key the dev chat takes for [peer]; null for anyone else. a
  /// dev chat whose key is gone trusts nothing
  Uint8List? pinnedFor(String peer) {
    if (!isDevChat(peer)) return null;
    final k = devKeyById(peer.substring(4));
    if (k == null || k.status == DevKeyStatus.retired) {
      throw const LsError(LsError.untrusted);
    }
    return pinnedIdentity(k);
  }

  /// [key] seen for [peer] on a message that opened or a session built:
  /// trust on first use, and deliver and warn on a new key. a reinstall
  /// and a mitm look the same here, so the contact is flagged and the user
  /// decides. true when another key was held before
  Future<bool> saw(String peer, List<int> key) async {
    // the dev chat keeps no key but the pinned one, and flags nothing
    if (isDevChat(peer)) {
      final k = devKeyById(peer.substring(4));
      if (k == null || k.status == DevKeyStatus.retired) return false;
      if (!_eq(pinnedIdentity(k), key)) return false;
      await _db.insert(_t, {
        'address': peer,
        'identity_key': Uint8List.fromList(key),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return false;
    }
    final held = await getIdentity(peer);
    final changed = held != null && !_eq(held, key);
    if (changed) {
      await _db.update(
        'contacts',
        {'key_changed': 1, 'verified': 0},
        where: 'halo_id = ?',
        whereArgs: [peer],
      );
    }
    if (held != null && !changed) return false;
    await _db.insert(_t, {
      'address': peer,
      'identity_key': Uint8List.fromList(key),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _unverifyOtherKey(peer, key);
    if (peer != '_pending_back_pair_') onPeerKeyChanged?.call();
    return changed;
  }

  Future<void> removePeerIdentity(String peer) async {
    await _db.delete(_t, where: 'address = ?', whereArgs: [peer]);
  }

  // a verified mark names the key it was given for
  Future<void> _unverifyOtherKey(String peer, List<int> key) async {
    final pub = key.length == 33 ? key.sublist(1) : key;
    final hex = pub.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final rows = await _db.query(
      'contacts',
      columns: ['verified', 'verified_key'],
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    if (rows.isEmpty || (rows.first['verified'] as int? ?? 0) != 1) return;
    if ((rows.first['verified_key'] as String?)?.toLowerCase() == hex) return;
    await _db.update(
      'contacts',
      {'verified': 0},
      where: 'halo_id = ?',
      whereArgs: [peer],
    );
  }
}

// one table of records by id
class _ById {
  _ById(this._db, this._t);
  final Database _db;
  final String _t;

  Future<Uint8List?> load(int id) async {
    final rows = await _db.query(
      _t,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList(rows.first['record'] as List<int>);
  }

  Future<bool> contains(int id) async => (await _db.query(
    _t,
    columns: ['id'],
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  )).isNotEmpty;

  Future<List<int>> ids() async => [
    for (final r in await _db.query(_t, columns: ['id'])) r['id'] as int,
  ];

  Future<void> _put(Map<String, Object?> row) =>
      _db.insert(_t, row, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _drop(int id) =>
      _db.delete(_t, where: 'id = ?', whereArgs: [id]);
}

class LsPreKeyStore extends _ById {
  LsPreKeyStore(Database db, {String prefix = ''})
    : super(db, '${prefix}prekeys');

  Future<void> store(int id, Uint8List record) =>
      _put({'id': id, 'record': record});

  // the invite's prekey is shared, so it survives use
  Future<void> remove(int id) async {
    if (id == invitePreKeyId) return;
    await _drop(id);
  }

  /// a new key in the invite's slot (reset my invite link)
  Future<void> replaceInvite(Uint8List record) => store(invitePreKeyId, record);
}

class LsSignedPreKeyStore extends _ById {
  LsSignedPreKeyStore(Database db, {String prefix = ''})
    : super(db, '${prefix}signed_prekeys');

  Future<void> store(int id, Uint8List record) => _put({
    'id': id,
    'record': record,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  });

  Future<void> remove(int id) => _drop(id);
}

class LsKyberPreKeyStore extends _ById {
  LsKyberPreKeyStore(Database db, {String prefix = ''})
    : _used = '${prefix}kyber_used',
      super(db, '${prefix}kyber_prekeys');

  final String _used;

  Future<void> store(int id, Uint8List record, {bool lastResort = false}) =>
      _put({
        'id': id,
        'record': record,
        'last_resort': lastResort ? 1 : 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<bool> isLastResort(int id) async {
    final rows = await _db.query(
      _t,
      columns: ['last_resort'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['last_resort'] == 1;
  }

  /// [id] opened a session for [baseKey]: a one-time key goes, a last
  /// resort one keeps the base key so the same opener is not taken twice
  Future<void> markUsed(int id, int signedId, List<int> baseKey) async {
    if (!await isLastResort(id)) {
      await _drop(id);
      return;
    }
    await _db.insert(_used, {
      'kyber_id': id,
      'signed_id': signedId,
      'base_key': Uint8List.fromList(baseKey),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<bool> wasUsed(int id, List<int> baseKey) async {
    for (final r in await _db.query(
      _used,
      columns: ['base_key'],
      where: 'kyber_id = ?',
      whereArgs: [id],
    )) {
      if (_eq(r['base_key'] as List<int>, baseKey)) return true;
    }
    return false;
  }

  Future<void> remove(int id) async {
    await _drop(id);
    await _db.delete(_used, where: 'kyber_id = ?', whereArgs: [id]);
  }
}

class LsSessionStore {
  LsSessionStore(this._db, {String prefix = ''}) : _t = '${prefix}sessions';
  final Database _db;
  final String _t;

  Future<Uint8List?> load(String peer, [int device = 1]) async {
    final rows = await _db.query(
      _t,
      where: 'address = ? AND device_id = ?',
      whereArgs: [peer, device],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList(rows.first['record'] as List<int>);
  }

  Future<void> store(String peer, Uint8List record, [int device = 1]) =>
      _db.insert(_t, {
        'address': peer,
        'device_id': device,
        'record': record,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<bool> contains(String peer, [int device = 1]) async =>
      (await _db.query(
        _t,
        columns: ['address'],
        where: 'address = ? AND device_id = ?',
        whereArgs: [peer, device],
        limit: 1,
      )).isNotEmpty;

  Future<void> delete(String peer, [int device = 1]) => _db.delete(
    _t,
    where: 'address = ? AND device_id = ?',
    whereArgs: [peer, device],
  );

  Future<void> deleteAll(String peer) =>
      _db.delete(_t, where: 'address = ?', whereArgs: [peer]);

  // every address a session is held with, contact or not
  Future<List<String>> allSessionAddresses() async => {
    for (final r in await _db.query(_t, columns: ['address']))
      r['address'] as String,
  }.toList();

  Future<List<int>> subDeviceSessions(String peer) async => [
    for (final r in await _db.query(
      _t,
      columns: ['device_id'],
      where: 'address = ?',
      whereArgs: [peer],
    ))
      r['device_id'] as int,
  ];

  /// every row, for the restore marks
  Future<List<(String, Uint8List)>> all() async => [
    for (final r in await _db.query(_t, columns: ['address', 'record']))
      (r['address'] as String, Uint8List.fromList(r['record'] as List<int>)),
  ];
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
