// SPDX-License-Identifier: GPL-3.0-or-later
// four libsignal stores backed by sqlcipher.

import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class HaloIdentityKeyStore implements IdentityKeyStore {
  final Database _db;
  final IdentityKeyPair _idPair;
  final int _regId;
  HaloIdentityKeyStore(this._db, this._idPair, this._regId);

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async => _idPair;

  @override
  Future<int> getLocalRegistrationId() async => _regId;

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    if (identityKey == null) return false;
    final addr = address.getName();
    final existing = await _db.query(
      'peer_identities',
      where: 'address = ?',
      whereArgs: [addr],
      limit: 1,
    );
    final newBytes = identityKey.serialize();
    final changed =
        existing.isNotEmpty &&
        !_eq(existing.first['identity_key'] as Uint8List, newBytes);
    await _db.insert('peer_identities', {
      'address': addr,
      'identity_key': newBytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return changed;
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async {
    if (identityKey == null) return false;
    final rows = await _db.query(
      'peer_identities',
      where: 'address = ?',
      whereArgs: [address.getName()],
      limit: 1,
    );
    // unknown peer: trust on first use.
    if (rows.isEmpty) return true;
    final matches = _eq(
      rows.first['identity_key'] as Uint8List,
      identityKey.serialize(),
    );
    if (matches) return true;
    // key changed. deliver-and-warn: trust the new key so the message still
    // arrives and the session re-establishes, but flag the contact so the chat
    // shows a security-code-changed banner. reinstall or mitm looks the same
    // here - surface it, let the user decide, never silently drop.
    await _db.update(
      'contacts',
      {'key_changed': 1},
      where: 'halo_id = ?',
      whereArgs: [address.getName()],
    );
    return true;
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final rows = await _db.query(
      'peer_identities',
      where: 'address = ?',
      whereArgs: [address.getName()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final bytes = rows.first['identity_key'] as Uint8List;
    return IdentityKey(Curve.decodePoint(bytes, 0));
  }

  // drop a peer's stored identity so a genuinely-changed key can be
  // re-trusted. only called after the user accepts the new safety number.
  // next isTrustedIdentity sees no row -> trust-first-use -> new session ok.
  Future<void> removePeerIdentity(SignalProtocolAddress address) async {
    await _db.delete(
      'peer_identities',
      where: 'address = ?',
      whereArgs: [address.getName()],
    );
  }

  bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }
}

class HaloPreKeyStore implements PreKeyStore {
  final Database _db;
  HaloPreKeyStore(this._db);

  @override
  Future<PreKeyRecord> loadPreKey(int id) async {
    final rows = await _db.query(
      'prekeys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw InvalidKeyIdException('no prekey id $id');
    return PreKeyRecord.fromBuffer(rows.first['record'] as Uint8List);
  }

  @override
  Future<void> storePreKey(int id, PreKeyRecord record) async {
    await _db.insert('prekeys', {
      'id': id,
      'record': record.serialize(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> containsPreKey(int id) async {
    final rows = await _db.query(
      'prekeys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> removePreKey(int id) async {
    await _db.delete('prekeys', where: 'id = ?', whereArgs: [id]);
  }
}

class HaloSessionStore implements SessionStore {
  final Database _db;
  HaloSessionStore(this._db);

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final rows = await _db.query(
      'sessions',
      where: 'address = ? AND device_id = ?',
      whereArgs: [address.getName(), address.getDeviceId()],
      limit: 1,
    );
    if (rows.isEmpty) return SessionRecord();
    return SessionRecord.fromSerialized(rows.first['record'] as Uint8List);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final rows = await _db.query(
      'sessions',
      columns: ['device_id'],
      where: 'address = ?',
      whereArgs: [name],
    );
    return rows.map((r) => r['device_id'] as int).toList();
  }

  @override
  Future<void> storeSession(
    SignalProtocolAddress address,
    SessionRecord record,
  ) async {
    await _db.insert('sessions', {
      'address': address.getName(),
      'device_id': address.getDeviceId(),
      'record': record.serialize(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final rows = await _db.query(
      'sessions',
      where: 'address = ? AND device_id = ?',
      whereArgs: [address.getName(), address.getDeviceId()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    await _db.delete(
      'sessions',
      where: 'address = ? AND device_id = ?',
      whereArgs: [address.getName(), address.getDeviceId()],
    );
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    await _db.delete('sessions', where: 'address = ?', whereArgs: [name]);
  }
}

class HaloSignedPreKeyStore implements SignedPreKeyStore {
  final Database _db;
  HaloSignedPreKeyStore(this._db);

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int id) async {
    final rows = await _db.query(
      'signed_prekeys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw InvalidKeyIdException('no signed prekey $id');
    return SignedPreKeyRecord.fromSerialized(rows.first['record'] as Uint8List);
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final rows = await _db.query('signed_prekeys');
    return rows
        .map((r) => SignedPreKeyRecord.fromSerialized(r['record'] as Uint8List))
        .toList();
  }

  @override
  Future<void> storeSignedPreKey(int id, SignedPreKeyRecord record) async {
    await _db.insert('signed_prekeys', {
      'id': id,
      'record': record.serialize(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> containsSignedPreKey(int id) async {
    final rows = await _db.query(
      'signed_prekeys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> removeSignedPreKey(int id) async {
    await _db.delete('signed_prekeys', where: 'id = ?', whereArgs: [id]);
  }
}
