// SPDX-License-Identifier: GPL-3.0-or-later
// the signal stores over sqlcipher, for the libsignal shim. records go in
// and out as the bytes libsignal writes, in the tables and the record form
// libsignal_protocol_dart kept before, so a store a 0.5.x phone wrote goes
// on here as it is. a prefix names another set of the same tables in the
// same database: the dev chat's made name keeps its own there

import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'devchat/dev_key.dart';
import 'signal_ffi/kryfo_signal.dart';

// the tables of one store, without their prefix. the schema makes them
// (app/database.dart); the kyber ones came with the shim
const kSignalTables = [
  'prekeys',
  'signed_prekeys',
  'sessions',
  'peer_identities',
  'signal_meta',
  'kyber_prekeys',
  'kyber_used',
  'opener_reads',
];

// the anonymous dev chat's store
const kDevSignalPrefix = 'dev_';

// called when a key saved for someone replaces another: whoever shows their
// number reads it again
void Function()? onPeerKeyChanged;

// the one prekey an invite carries. an invite is shared (a handle, a link, a
// qr), so this "one-time" key must survive use: libsignal removes a prekey
// after the first session built on it, and everyone after would fail.
const invitePreKeyId = 999999;

/// the kyber prekey an invite carries, kept as the invite's ec prekey is
const kInviteKyberId = 1;

/// what a signed or kyber prekey is for: an invite's (its id beside it, ''
/// for the main one), the identity's session prekeys (heals, device
/// bundles), one heal's one-time kyber key, or the one-time kyber key of a
/// device bundle the phone keeps in its pool
const kUseInvite = 'invite';
const kUseSession = 'session';
const kUseHeal = 'heal';
const kUsePool = 'pool';

class LsIdentityStore {
  LsIdentityStore(
    this._db,
    this.identity,
    this.registrationId, {
    String prefix = '',
    this.ident = 0,
  }) : _t = '${prefix}peer_identities';

  final DatabaseExecutor _db;
  final LsIdentity identity;
  final int registrationId;
  final String _t;
  // the identity whose rows these are
  final int ident;

  /// the key held for [peer], 33 bytes
  Future<Uint8List?> getIdentity(String peer) async {
    final rows = await _db.query(
      _t,
      where: 'ident = ? AND address = ?',
      whereArgs: [ident, peer],
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
        'ident': ident,
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
      'ident': ident,
      'address': peer,
      'identity_key': Uint8List.fromList(key),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _unverifyOtherKey(peer, key);
    if (peer != '_pending_back_pair_') onPeerKeyChanged?.call();
    return changed;
  }

  Future<void> removePeerIdentity(String peer) async {
    await _db.delete(
      _t,
      where: 'ident = ? AND address = ?',
      whereArgs: [ident, peer],
    );
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
  _ById(this._db, this._t, this.ident);
  final DatabaseExecutor _db;
  final String _t;
  // the identity whose keys these are
  final int ident;

  Future<Uint8List?> load(int id) async {
    final rows = await _db.query(
      _t,
      where: 'ident = ? AND id = ?',
      whereArgs: [ident, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList(rows.first['record'] as List<int>);
  }

  Future<bool> contains(int id) async => (await _db.query(
    _t,
    columns: ['id'],
    where: 'ident = ? AND id = ?',
    whereArgs: [ident, id],
    limit: 1,
  )).isNotEmpty;

  Future<List<int>> ids() async => [
    for (final r in await _db.query(
      _t,
      columns: ['id'],
      where: 'ident = ?',
      whereArgs: [ident],
    ))
      r['id'] as int,
  ];

  Future<void> _put(Map<String, Object?> row) => _db.insert(_t, {
    ...row,
    'ident': ident,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _drop(int id) =>
      _db.delete(_t, where: 'ident = ? AND id = ?', whereArgs: [ident, id]);
}

class LsPreKeyStore extends _ById {
  LsPreKeyStore(DatabaseExecutor db, {String prefix = '', int ident = 0})
    : super(db, '${prefix}prekeys', ident);

  Future<void> store(int id, Uint8List record) =>
      _put({'id': id, 'record': record});

  // the invite's prekey is shared, so it survives use
  Future<void> remove(int id) async {
    if (id == invitePreKeyId) return;
    await _drop(id);
  }

  /// the v3 invite's key gone for good (its invite's year is over)
  Future<void> dropInvite() => _drop(invitePreKeyId);

  /// a new key in the invite's slot (reset my invite link)
  Future<void> replaceInvite(Uint8List record) => store(invitePreKeyId, record);
}

class LsSignedPreKeyStore extends _ById {
  LsSignedPreKeyStore(DatabaseExecutor db, {String prefix = '', int ident = 0})
    : super(db, '${prefix}signed_prekeys', ident);

  /// [use]: what the key is for (kUseInvite with its invite's id, '' the
  /// main invite; kUseSession)
  Future<void> store(
    int id,
    Uint8List record, {
    String use = kUseInvite,
    String inviteId = '',
    int? createdAt,
  }) => _put({
    'id': id,
    'record': record,
    'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    'use': use,
    'invite_id': inviteId,
  });

  Future<void> remove(int id) => _drop(id);
}

class LsKyberPreKeyStore extends _ById {
  LsKyberPreKeyStore(DatabaseExecutor db, {String prefix = '', int ident = 0})
    : _used = '${prefix}kyber_used',
      _reads = '${prefix}opener_reads',
      super(db, '${prefix}kyber_prekeys', ident);

  final String _used;
  final String _reads;

  /// [opener] (an opener's fingerprint) was read on kyber key [id]
  Future<void> markRead(int id, List<int> opener) => _db.insert(_reads, {
    'ident': ident,
    'kyber_id': id,
    'opener': Uint8List.fromList(opener),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  /// whether [opener] was read on kyber key [id] before. one lookup on the
  /// primary key, however many openers a key that never expires took
  Future<bool> wasRead(int id, List<int> opener) async => (await _db.query(
    _reads,
    columns: ['kyber_id'],
    where: 'ident = ? AND kyber_id = ? AND opener = ?',
    whereArgs: [ident, id, Uint8List.fromList(opener)],
    limit: 1,
  )).isNotEmpty;

  Future<void> store(
    int id,
    Uint8List record, {
    bool lastResort = false,
    String use = kUseInvite,
    String inviteId = '',
    int? createdAt,
  }) => _put({
    'id': id,
    'record': record,
    'last_resort': lastResort ? 1 : 0,
    'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    'use': use,
    'invite_id': inviteId,
  });

  /// what kyber key [id] is for (kUseInvite, kUseSession, ...), null when
  /// it is not held
  Future<String?> useOf(int id) async {
    final rows = await _db.query(
      _t,
      columns: ['use'],
      where: 'ident = ? AND id = ?',
      whereArgs: [ident, id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['use'] as String?;
  }

  Future<bool> isLastResort(int id) async {
    final rows = await _db.query(
      _t,
      columns: ['last_resort'],
      where: 'ident = ? AND id = ?',
      whereArgs: [ident, id],
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
      'ident': ident,
      'kyber_id': id,
      'signed_id': signedId,
      'base_key': Uint8List.fromList(baseKey),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// whether [baseKey] opened a session on last resort key [id]. every row
  /// stays while the key is held (a replayed opener is refused on it), so
  /// this is one lookup on the primary key, not a read of them all
  Future<bool> wasUsed(int id, List<int> baseKey) async => (await _db.query(
    _used,
    columns: ['kyber_id'],
    where: 'ident = ? AND kyber_id = ? AND base_key = ?',
    whereArgs: [ident, id, Uint8List.fromList(baseKey)],
    limit: 1,
  )).isNotEmpty;

  // the openers a key took go with it: nothing opens on it after
  Future<void> remove(int id) async {
    await _drop(id);
    await _db.delete(
      _used,
      where: 'ident = ? AND kyber_id = ?',
      whereArgs: [ident, id],
    );
    await _db.delete(
      _reads,
      where: 'ident = ? AND kyber_id = ?',
      whereArgs: [ident, id],
    );
  }
}

class LsSessionStore {
  LsSessionStore(this._db, {String prefix = '', this.ident = 0})
    : _t = '${prefix}sessions';
  final DatabaseExecutor _db;
  final String _t;
  // the identity whose sessions these are
  final int ident;

  Future<Uint8List?> load(String peer, [int device = 1]) async {
    final rows = await _db.query(
      _t,
      where: 'ident = ? AND address = ? AND device_id = ?',
      whereArgs: [ident, peer, device],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Uint8List.fromList(rows.first['record'] as List<int>);
  }

  Future<void> store(String peer, Uint8List record, [int device = 1]) =>
      _db.insert(_t, {
        'ident': ident,
        'address': peer,
        'device_id': device,
        'record': record,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<bool> contains(String peer, [int device = 1]) async =>
      (await _db.query(
        _t,
        columns: ['address'],
        where: 'ident = ? AND address = ? AND device_id = ?',
        whereArgs: [ident, peer, device],
        limit: 1,
      )).isNotEmpty;

  Future<void> delete(String peer, [int device = 1]) => _db.delete(
    _t,
    where: 'ident = ? AND address = ? AND device_id = ?',
    whereArgs: [ident, peer, device],
  );

  Future<void> deleteAll(String peer) => _db.delete(
    _t,
    where: 'ident = ? AND address = ?',
    whereArgs: [ident, peer],
  );

  // every address a session is held with, contact or not
  Future<List<String>> allSessionAddresses() async => {
    for (final r in await _db.query(
      _t,
      columns: ['address'],
      where: 'ident = ?',
      whereArgs: [ident],
    ))
      r['address'] as String,
  }.toList();

  Future<List<int>> subDeviceSessions(String peer) async => [
    for (final r in await _db.query(
      _t,
      columns: ['device_id'],
      where: 'ident = ? AND address = ?',
      whereArgs: [ident, peer],
    ))
      r['device_id'] as int,
  ];

  /// every row, for the restore marks
  Future<List<(String, Uint8List)>> all() async => [
    for (final r in await _db.query(
      _t,
      columns: ['address', 'record'],
      where: 'ident = ?',
      whereArgs: [ident],
    ))
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
