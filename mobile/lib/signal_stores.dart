// SPDX-License-Identifier: GPL-3.0-or-later
// four libsignal stores backed by sqlcipher. a prefix names another set of
// the same tables in the same database: the dev chat's made name keeps its
// own there, so nothing of it touches the everyday store

import 'dart:typed_data';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'devchat/dev_key.dart';

// the tables of one store, without their prefix
const kSignalTables = [
  'prekeys',
  'signed_prekeys',
  'sessions',
  'peer_identities',
  'signal_meta',
];

// the anonymous dev chat's store
const kDevSignalPrefix = 'dev_';

class HaloIdentityKeyStore implements IdentityKeyStore {
  final Database _db;
  final IdentityKeyPair _idPair;
  final int _regId;
  final String _t;
  HaloIdentityKeyStore(
    this._db,
    this._idPair,
    this._regId, {
    String prefix = '',
  }) : _t = '${prefix}peer_identities';

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
    // the dev chat keeps no key but the pinned one
    if (isDevChat(addr) && !_pinned(addr, identityKey)) return false;
    final existing = await _db.query(
      _t,
      where: 'address = ?',
      whereArgs: [addr],
      limit: 1,
    );
    final newBytes = identityKey.serialize();
    final changed =
        existing.isNotEmpty &&
        !_eq(existing.first['identity_key'] as Uint8List, newBytes);
    await _db.insert(_t, {
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
    // the dev chat trusts the pinned key and nothing else: no first use,
    // no warning, and nothing written
    if (isDevChat(address.getName())) {
      return _pinned(address.getName(), identityKey);
    }
    final rows = await _db.query(
      _t,
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
    // arrives, but flag the contact so the chat shows a banner. a reinstall
    // and a mitm look the same here, so the user decides.
    await _db.update(
      'contacts',
      {'key_changed': 1, 'verified': 0},
      where: 'halo_id = ?',
      whereArgs: [address.getName()],
    );
    return true;
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final rows = await _db.query(
      _t,
      where: 'address = ?',
      whereArgs: [address.getName()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final bytes = rows.first['identity_key'] as Uint8List;
    return IdentityKey(Curve.decodePoint(bytes, 0));
  }

  // drop a peer's stored identity so a changed key is trusted on first use
  // again. only called after the user accepts the new safety number.
  Future<void> removePeerIdentity(SignalProtocolAddress address) async {
    await _db.delete(_t, where: 'address = ?', whereArgs: [address.getName()]);
  }

  // the key an address dev:<id> is pinned to, while that key still works
  bool _pinned(String addr, IdentityKey key) {
    final k = devKeyById(addr.substring(4));
    if (k == null || k.status == DevKeyStatus.retired) return false;
    return _eq(key.serialize(), pinnedIdentity(k));
  }

  bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// the one prekey an invite carries. an invite is shared (a handle, a link, a
// qr), so this "one-time" key must survive use: libsignal removes a prekey
// after the first session built on it, and everyone after would fail.
const invitePreKeyId = 999999;

class HaloPreKeyStore implements PreKeyStore {
  final Database _db;
  final String _t;
  HaloPreKeyStore(this._db, {String prefix = ''}) : _t = '${prefix}prekeys';

  @override
  Future<PreKeyRecord> loadPreKey(int id) async {
    final rows = await _db.query(
      _t,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw InvalidKeyIdException('no prekey id $id');
    return PreKeyRecord.fromBuffer(rows.first['record'] as Uint8List);
  }

  @override
  Future<void> storePreKey(int id, PreKeyRecord record) async {
    await _db.insert(_t, {
      'id': id,
      'record': record.serialize(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> containsPreKey(int id) async {
    final rows = await _db.query(
      _t,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> removePreKey(int id) async {
    if (id == invitePreKeyId) return;
    await _db.delete(_t, where: 'id = ?', whereArgs: [id]);
  }
}

class HaloSessionStore implements SessionStore {
  final Database _db;
  final String _t;
  HaloSessionStore(this._db, {String prefix = ''}) : _t = '${prefix}sessions';

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final rows = await _db.query(
      _t,
      where: 'address = ? AND device_id = ?',
      whereArgs: [address.getName(), address.getDeviceId()],
      limit: 1,
    );
    if (rows.isEmpty) return SessionRecord();
    return _ownRecord(rows.first['record'] as Uint8List);
  }

  // every address we hold a session with, contact or not, so the drain loop
  // can decrypt a deleted peer's next message and file it as a request
  Future<List<String>> allSessionAddresses() async {
    final rows = await _db.query(_t, columns: ['address']);
    return rows.map((r) => r['address'] as String).toSet().toList();
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final rows = await _db.query(
      _t,
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
    await _db.insert(_t, {
      'address': address.getName(),
      'device_id': address.getDeviceId(),
      'record': _onceEach(record).serialize(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final rows = await _db.query(
      _t,
      where: 'address = ? AND device_id = ?',
      whereArgs: [address.getName(), address.getDeviceId()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    await _db.delete(
      _t,
      where: 'address = ? AND device_id = ?',
      whereArgs: [address.getName(), address.getDeviceId()],
    );
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    await _db.delete(_t, where: 'address = ?', whereArgs: [name]);
  }
}

// states are handed out as copies, so a try that does not open a message
// leaves the stored record as it was
base class _CopiedState extends SessionState {
  _CopiedState(super.structure) : super.fromStructure();

  // a state on the structure itself, for writing the record
  SessionState bare() => SessionState.fromStructure(super.structure);

  @override
  get structure => SessionRecord.fromSerialized(
    SessionRecord.fromSessionState(
      SessionState.fromStructure(super.structure),
    ).serialize(),
  ).sessionState.structure;
}

SessionRecord _ownRecord(Uint8List bytes) {
  final read = SessionRecord.fromSerialized(bytes);
  final archived = [
    for (final s in read.previousSessionStates) _CopiedState(s.structure),
  ];
  read
    ..state = _CopiedState(read.sessionState.structure)
    ..removePreviousSessionStates();
  read.previousSessionStates.addAll(archived);
  return read;
}

// [record] with each session once, the newest copy of it kept. an archived
// state that opens a message is promoted without leaving the archive, and
// what stays there is its state from before
SessionRecord _onceEach(SessionRecord record) {
  SessionState plain(SessionState s) =>
      s is _CopiedState ? s.bare() : SessionState.fromStructure(s.structure);
  final out = SessionRecord.fromSessionState(plain(record.sessionState));
  final seen = {_sessionKey(record.sessionState)};
  for (final s in record.previousSessionStates) {
    final k = _sessionKey(s);
    if (k.isNotEmpty && !seen.add(k)) continue;
    out.previousSessionStates.add(plain(s));
  }
  return out;
}

String _sessionKey(SessionState s) {
  final base = s.aliceBaseKey;
  return base.isEmpty ? '' : '${s.getSessionVersion()}:${base.join(',')}';
}

class HaloSignedPreKeyStore implements SignedPreKeyStore {
  final Database _db;
  final String _t;
  HaloSignedPreKeyStore(this._db, {String prefix = ''})
    : _t = '${prefix}signed_prekeys';

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int id) async {
    final rows = await _db.query(
      _t,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw InvalidKeyIdException('no signed prekey $id');
    return SignedPreKeyRecord.fromSerialized(rows.first['record'] as Uint8List);
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final rows = await _db.query(_t);
    return rows
        .map((r) => SignedPreKeyRecord.fromSerialized(r['record'] as Uint8List))
        .toList();
  }

  @override
  Future<void> storeSignedPreKey(int id, SignedPreKeyRecord record) async {
    await _db.insert(_t, {
      'id': id,
      'record': record.serialize(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> containsSignedPreKey(int id) async {
    final rows = await _db.query(
      _t,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> removeSignedPreKey(int id) async {
    await _db.delete(_t, where: 'id = ?', whereArgs: [id]);
  }
}
