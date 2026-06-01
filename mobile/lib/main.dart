// halo mobile — phase 1: identity persistence + ECDH + editorial UI

import 'dart:async';
import 'widgets/tor_boot_splash.dart';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'notifications.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/push_settings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'lock_state.dart';
import 'screens/lock_screen.dart';
import 'screens/lock_setup_screen.dart';
import 'push_mode.dart';
import 'ntfy_listener.dart';
import 'message_envelope.dart';
import 'widgets/motion.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:app_links/app_links.dart';
import 'signal_session.dart';
import 'dart:isolate';

typedef CStrFn = Pointer<Utf8> Function();
typedef CStrFnDart = Pointer<Utf8> Function();
typedef OneArgFn = Pointer<Utf8> Function(Pointer<Utf8>);
typedef OneArgFnDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef TwoArgFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef TwoArgFnDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

class HaloEngine {
  late final DynamicLibrary _lib;
  late final CStrFnDart _version;
  late final CStrFnDart _genIdentity;
  late final TwoArgFnDart _restoreIdentity;
  late final CStrFnDart _myId;
  late final CStrFnDart _myEdPub;
  late final CStrFnDart _myXPub;
  late final CStrFnDart _myEdPriv;
  late final CStrFnDart _myXPriv;
  late final TwoArgFnDart _encryptFor;
  late final TwoArgFnDart _decryptFrom;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _start;
  late final CStrFnDart _drainInbox;
  late final CStrFnDart _getStatus;
  late final TwoArgFnDart _send;
  late final OneArgFnDart _nostrInit;
  late final TwoArgFnDart _nostrSend;
  late final OneArgFnDart _nostrSubscribe;
  late final CStrFnDart _nostrPoll;
  late final OneArgFnDart _ntfyPing;
  late final OneArgFnDart _idFromEdPub;
  late final TwoArgFnDart _encryptBackup;
  late final TwoArgFnDart _decryptBackup;

  HaloEngine() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    _version = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloVersion');
    _genIdentity = _lib.lookupFunction<CStrFn, CStrFnDart>(
      'HaloGenerateIdentity',
    );
    _restoreIdentity = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloRestoreIdentity',
    );
    _myId = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyId');
    _myEdPub = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyEdPubkey');
    _myXPub = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyXPubkey');
    _myEdPriv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyEdPrivkey');
    _myXPriv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyXPrivkey');
    _encryptFor = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloEncryptFor');
    _decryptFrom = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloDecryptFrom',
    );
    _start = _lib
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)
        >('HaloStartListener');
    _drainInbox = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloDrainInbox');
    _getStatus = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloGetStatus');
    _send = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSendTo');
    _nostrInit = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrInit');
    _nostrSend = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloNostrSend');
    _nostrSubscribe = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloNostrSubscribe',
    );
    _nostrPoll = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloNostrPoll');
    _ntfyPing = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNtfyPing');
    _idFromEdPub = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloIdFromEdPub',
    );
    _encryptBackup = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloEncryptBackup',
    );
    _decryptBackup = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      'HaloDecryptBackup',
    );
  }

  String version() => _version().toDartString();
  String generateIdentity() => _genIdentity().toDartString();
  String myId() => _myId().toDartString();
  String myEdPubkey() => _myEdPub().toDartString();
  String myXPubkey() => _myXPub().toDartString();
  String myEdPrivkey() => _myEdPriv().toDartString();
  String myXPrivkey() => _myXPriv().toDartString();
  String startListener(String dataDir) {
    final ptr = dataDir.toNativeUtf8();
    try {
      return _start(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  List<String> drainInbox() {
    final raw = _drainInbox().toDartString();
    if (raw.isEmpty) return const [];
    return raw.split('\n');
  }

  String getStatus() => _getStatus().toDartString();

  String nostrInit(String relaysCSV) {
    final ptr = relaysCSV.toNativeUtf8();
    try {
      return _nostrInit(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  String ntfyPing(String endpoint) {
    final ptr = endpoint.toNativeUtf8();
    try {
      return _ntfyPing(ptr).toDartString();
    } finally {
      calloc.free(ptr);
    }
  }

  String idFromEdPub(String hexPub) {
    final ptr = hexPub.toNativeUtf8();
    try {
      return _idFromEdPub(ptr).toDartString();
    } finally {
      calloc.free(ptr);
    }
  }

  String encryptBackup(String plain, String passphrase) {
    final p1 = plain.toNativeUtf8();
    final p2 = passphrase.toNativeUtf8();
    try {
      return _encryptBackup(p1, p2).toDartString();
    } finally {
      calloc.free(p1);
      calloc.free(p2);
    }
  }

  String decryptBackup(String blob, String passphrase) {
    final p1 = blob.toNativeUtf8();
    final p2 = passphrase.toNativeUtf8();
    try {
      return _decryptBackup(p1, p2).toDartString();
    } finally {
      calloc.free(p1);
      calloc.free(p2);
    }
  }

  // offloaded to a background isolate so a slow relay never freezes the ui.
  Future<String> nostrSend(String peerXPubHex, String b64Cipher) =>
      _sendOnIsolate((nostr: true, a: peerXPubHex, b: b64Cipher));

  String nostrSubscribe(String peerXPubHex) {
    final ptr = peerXPubHex.toNativeUtf8();
    try {
      return _nostrSubscribe(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  List<({String peer, String cipher})> nostrPoll() {
    final raw = _nostrPoll().toDartString();
    if (raw.isEmpty) return const [];
    return raw.split('\n').map((line) {
      final idx = line.indexOf('|');
      if (idx < 0) return (peer: '', cipher: line);
      return (peer: line.substring(0, idx), cipher: line.substring(idx + 1));
    }).toList();
  }

  String restoreIdentity(String edPriv, String xPriv) {
    final c1 = edPriv.toNativeUtf8();
    final c2 = xPriv.toNativeUtf8();
    try {
      return _restoreIdentity(c1, c2).toDartString();
    } finally {
      calloc.free(c1);
      calloc.free(c2);
    }
  }

  String encryptFor(String peerPub, String plain) {
    final cPub = peerPub.toNativeUtf8();
    final cPlain = plain.toNativeUtf8();
    try {
      return _encryptFor(cPub, cPlain).toDartString();
    } finally {
      calloc.free(cPub);
      calloc.free(cPlain);
    }
  }

  String decryptFrom(String peerPub, String b64) {
    final cPub = peerPub.toNativeUtf8();
    final cB64 = b64.toNativeUtf8();
    try {
      return _decryptFrom(cPub, cB64).toDartString();
    } finally {
      calloc.free(cPub);
      calloc.free(cB64);
    }
  }

  // offloaded to a background isolate so a slow tor dial never freezes the ui.
  Future<String> sendTo(String addr, String msg) =>
      _sendOnIsolate((nostr: false, a: addr, b: msg));
}

// run a blocking native send on a throwaway background isolate so the ui
// thread never stalls on a tor dial. opens its own handle to libhalo —
// same process image, so it shares the running tor — and frees its strings.
Future<String> _startListenerOnIsolate(String dataDir) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)
        >('HaloStartListener');
    final p = dataDir.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

Future<String> _sendOnIsolate(({bool nostr, String a, String b}) args) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>(
      args.nostr ? 'HaloNostrSend' : 'HaloSendTo',
    );
    final p1 = args.a.toNativeUtf8();
    final p2 = args.b.toNativeUtf8();
    try {
      return fn(p1, p2).toDartString();
    } finally {
      malloc.free(p1);
      malloc.free(p2);
    }
  });
}

class HaloDb {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _passphraseKey = 'halo.db.passphrase';

  Database? _db;

  Future<String> _passphrase() async {
    var pw = await _storage.read(key: _passphraseKey);
    if (pw != null) return pw;
    pw = _randomPassphrase();
    await _storage.write(key: _passphraseKey, value: pw);
    return pw;
  }

  String _randomPassphrase() {
    final r = DateTime.now().microsecondsSinceEpoch.toString();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    var out = StringBuffer(r);
    for (var i = 0; i < 32; i++) {
      out.write(chars[(r.codeUnitAt(i % r.length) + i) % chars.length]);
    }
    return out.toString();
  }

  Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'halo.db');
    final pw = await _passphrase();
    _db = await openDatabase(
      path,
      password: pw,
      version: 15,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE identity (
            id TEXT PRIMARY KEY,
            ed_priv TEXT NOT NULL,
            x_priv TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            halo_id TEXT PRIMARY KEY,
            onion TEXT NOT NULL,
            xpub TEXT NOT NULL,
            first_seen INTEGER NOT NULL,
            last_seen INTEGER NOT NULL,
            back_paired INTEGER NOT NULL DEFAULT 0,
            nickname TEXT,
            blocked INTEGER NOT NULL DEFAULT 0,
            muted INTEGER NOT NULL DEFAULT 0,
            archived INTEGER NOT NULL DEFAULT 0,
            verified INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peer_id TEXT NOT NULL,
            direction TEXT NOT NULL,
            plaintext TEXT NOT NULL,
            sent_at INTEGER NOT NULL,
            burn_at INTEGER,
            msg_uid TEXT,
            reply_to TEXT,
            group_id TEXT,
            edited INTEGER NOT NULL DEFAULT 0,
            pinned INTEGER NOT NULL DEFAULT 0,
            media_path TEXT,
            FOREIGN KEY (peer_id) REFERENCES contacts(halo_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE reactions (
            msg_uid TEXT NOT NULL,
            reactor TEXT NOT NULL,
            emoji TEXT NOT NULL,
            reacted_at INTEGER NOT NULL,
            PRIMARY KEY (msg_uid, reactor)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_msg_uid ON messages(msg_uid)',
        );
        await db.execute(
          'CREATE INDEX idx_messages_group_id ON messages(group_id)',
        );
        await db.execute('''
          CREATE TABLE groups (
            group_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            is_admin INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE group_members (
            group_id TEXT NOT NULL,
            halo_id TEXT NOT NULL,
            joined_at INTEGER NOT NULL,
            PRIMARY KEY (group_id, halo_id),
            FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
          )
        ''');
        await _signalTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _signalTables(db);
        if (oldV < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN burn_at INTEGER');
        }
        if (oldV < 4) {
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN back_paired INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 5) {
          await db.execute('ALTER TABLE messages ADD COLUMN msg_uid TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_msg_uid ON messages(msg_uid)',
          );
          await db.execute('''
            CREATE TABLE reactions (
              msg_uid TEXT NOT NULL,
              reactor TEXT NOT NULL,
              emoji TEXT NOT NULL,
              reacted_at INTEGER NOT NULL,
              PRIMARY KEY (msg_uid, reactor)
            )
          ''');
        }
        if (oldV < 6) {
          await db.execute('ALTER TABLE messages ADD COLUMN reply_to TEXT');
        }
        if (oldV < 8) {
          await db.execute('ALTER TABLE contacts ADD COLUMN nickname TEXT');
        }
        if (oldV < 9) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN edited INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 10) {
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN blocked INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 11) {
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN muted INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 12) {
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 13) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 14) {
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN verified INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 15) {
          await db.execute('ALTER TABLE messages ADD COLUMN media_path TEXT');
        }
        if (oldV < 7) {
          await db.execute('ALTER TABLE messages ADD COLUMN group_id TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_group_id ON messages(group_id)',
          );
          await db.execute('''
            CREATE TABLE groups (
              group_id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              is_admin INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE group_members (
              group_id TEXT NOT NULL,
              halo_id TEXT NOT NULL,
              joined_at INTEGER NOT NULL,
              PRIMARY KEY (group_id, halo_id),
              FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<Map<String, String>?> loadIdentity() async {
    final db = await open();
    final rows = await db.query('identity', limit: 1);
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['id'] as String,
      'ed_priv': rows.first['ed_priv'] as String,
      'x_priv': rows.first['x_priv'] as String,
    };
  }

  Future<void> saveIdentity(String id, String edPriv, String xPriv) async {
    final db = await open();
    await db.delete('identity');
    await db.insert('identity', {
      'id': id,
      'ed_priv': edPriv,
      'x_priv': xPriv,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, Object?>?> getContact(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // upsert a contact stub from group invite info. preserves existing rows
  // (won't overwrite onion/xpub if we already know this peer).
  Future<void> upsertContactStub(
    String haloId,
    String onion,
    String xpub,
  ) async {
    final db = await open();
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('contacts', {
      'halo_id': haloId,
      'onion': onion,
      'xpub': xpub,
      'first_seen': now,
      'last_seen': now,
      'back_paired': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> contacts() async {
    final db = await open();
    return db.query('contacts', orderBy: 'last_seen DESC');
  }

  Future<void> setArchived(String haloId, bool archived) async {
    final db = await open();
    await db.update(
      'contacts',
      {'archived': archived ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setMuted(String haloId, bool muted) async {
    final db = await open();
    await db.update(
      'contacts',
      {'muted': muted ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isMuted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['muted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['muted'] as int? ?? 0) == 1;
  }

  Future<void> setVerified(String haloId, bool verified) async {
    final db = await open();
    await db.update(
      'contacts',
      {'verified': verified ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isVerified(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['verified'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['verified'] as int? ?? 0) == 1;
  }

  Future<void> setBlocked(String haloId, bool blocked) async {
    final db = await open();
    await db.update(
      'contacts',
      {'blocked': blocked ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<bool> isBlocked(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['blocked'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['blocked'] as int? ?? 0) == 1;
  }

  Future<void> setNickname(String haloId, String? name) async {
    final db = await open();
    final v = (name == null || name.trim().isEmpty) ? null : name.trim();
    await db.update(
      'contacts',
      {'nickname': v},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> upsertContact(String haloId, String onion, String xpub) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('contacts', {
        'halo_id': haloId,
        'onion': onion,
        'xpub': xpub,
        'first_seen': now,
        'last_seen': now,
      });
    } else {
      await db.update(
        'contacts',
        {'onion': onion, 'xpub': xpub, 'last_seen': now},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
  }) async {
    final db = await open();
    await db.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'burn_at': burnAt,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'group_id': groupId,
      'media_path': mediaPath,
    });
    // any inbound message proves the peer knows us, so flip back_paired.
    // subsequent sends to them can use nostr safely.
    if (direction == 'in') {
      await db.update(
        'contacts',
        {'back_paired': 1},
        where: 'halo_id = ?',
        whereArgs: [peerId],
      );
    }
  }

  // load back_paired for a contact. true = peer has confirmed they know us
  // (via a received message). false = we should still use direct-onion to
  // give them a chance to back-pair.
  // assign a msg_uid to an existing row that lacks one (used to enable
  // reactions on messages that predate the v5 migration). returns the
  // uid. matches by (peer_id, sent_at) which is unique enough in practice.
  Future<void> assignUidIfMissing(
    String peerId,
    int sentAtMs,
    String uid,
  ) async {
    final db = await open();
    await db.update(
      'messages',
      {'msg_uid': uid},
      where: 'peer_id = ? AND sent_at = ? AND msg_uid IS NULL',
      whereArgs: [peerId, sentAtMs],
    );
  }

  Future<bool> isBackPaired(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['back_paired'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['back_paired'] as int? ?? 0) == 1;
  }

  // ---- groups ----

  // create a group locally. members is the full set INCLUDING the creator
  // (caller must include their own halo id if they want to appear in member
  // list). isAdmin = true for groups we created; false for groups we joined.
  Future<void> createGroup(
    String groupId,
    String name,
    List<String> members, {
    required bool isAdmin,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': isAdmin ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = db.batch();
    for (final m in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': m,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> groupExists(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['group_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> loadGroups() async {
    final db = await open();
    return db.query('groups', orderBy: 'created_at DESC');
  }

  Future<Map<String, Object?>?> getGroup(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<String>> getGroupMembers(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'group_members',
      columns: ['halo_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'joined_at ASC',
    );
    return rows.map((r) => r['halo_id'] as String).toList();
  }

  Future<void> addGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.insert('group_members', {
      'group_id': groupId,
      'halo_id': haloId,
      'joined_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.delete(
      'group_members',
      where: 'group_id = ? AND halo_id = ?',
      whereArgs: [groupId, haloId],
    );
  }

  Future<void> renameGroup(String groupId, String name) async {
    final db = await open();
    await db.update(
      'groups',
      {'name': name},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await open();
    await db.delete(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete('groups', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // load all messages for a group, oldest-first. peer_id on each row is the
  // SENDER's halo id (for our own messages this is our halo id).
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async {
    final db = await open();
    return db.query(
      'messages',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sent_at ASC',
    );
  }

  // add or replace a reaction. reactor is '' for self, peer's halo id
  // for theirs. one reaction per (msgUid, reactor) — re-reacting replaces.
  Future<void> setPinned(String msgUid, bool pinned) async {
    final db = await open();
    await db.update(
      'messages',
      {'pinned': pinned ? 1 : 0},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> deleteMessage(String msgUid) async {
    final db = await open();
    await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
  }

  Future<void> editMessage(String msgUid, String newText) async {
    final db = await open();
    await db.update(
      'messages',
      {'plaintext': newText, 'edited': 1},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> addReaction(String msgUid, String reactor, String emoji) async {
    final db = await open();
    await db.insert('reactions', {
      'msg_uid': msgUid,
      'reactor': reactor,
      'emoji': emoji,
      'reacted_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeReaction(String msgUid, String reactor) async {
    final db = await open();
    await db.delete(
      'reactions',
      where: 'msg_uid = ? AND reactor = ?',
      whereArgs: [msgUid, reactor],
    );
  }

  // load reactions for a batch of messages. returns
  // { msgUid: [ (reactor, emoji), ... ] }.
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async {
    if (msgUids.isEmpty) return {};
    final db = await open();
    final placeholders = List.filled(msgUids.length, '?').join(',');
    final rows = await db.query(
      'reactions',
      columns: ['msg_uid', 'reactor', 'emoji'],
      where: 'msg_uid IN ($placeholders)',
      whereArgs: msgUids,
    );
    final out = <String, List<MapEntry<String, String>>>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      final reactor = r['reactor'] as String;
      final emoji = r['emoji'] as String;
      out.putIfAbsent(uid, () => []).add(MapEntry(reactor, emoji));
    }
    return out;
  }

  // delete messages whose burn_at is past. called by the periodic
  // sweep started in boot().
  Future<int> purgeExpired() async {
    final db = await open();
    return db.delete(
      'messages',
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    final db = await open();
    return db.query(
      'messages',
      where: 'peer_id = ?',
      whereArgs: [peerId],
      orderBy: 'sent_at ASC',
    );
  }

  // newest message for a peer (or null) — drives the home-list preview and
  // ordering without loading the whole conversation.
  Future<Map<String, Object?>?> lastMessageFor(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      where: 'peer_id = ?',
      whereArgs: [peerId],
      orderBy: 'sent_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}

Future<void> _signalTables(Database db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS signed_prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL, created_at INTEGER NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS sessions (address TEXT NOT NULL, device_id INTEGER NOT NULL, record BLOB NOT NULL, PRIMARY KEY (address, device_id))',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS peer_identities (address TEXT PRIMARY KEY, identity_key BLOB NOT NULL)',
  );
  await db.execute(
    'CREATE TABLE IF NOT EXISTS signal_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)',
  );
}

Future<String> makePreKeyBundleB64() async {
  final spk = await signalSession.signedPreKeyStore.loadSignedPreKey(1);
  final database = await db.open();
  final pkRows = await database.query('prekeys', limit: 1, orderBy: 'id ASC');
  if (pkRows.isEmpty) throw 'no prekeys';
  final pk = await signalSession.preKeyStore.loadPreKey(
    pkRows.first['id'] as int,
  );
  final bundle = {
    'registrationId': signalSession.registrationId,
    'deviceId': 1,
    'preKeyId': pk.id,
    'preKeyPublic': base64Encode(pk.getKeyPair().publicKey.serialize()),
    'signedPreKeyId': spk.id,
    'signedPreKeyPublic': base64Encode(spk.getKeyPair().publicKey.serialize()),
    'signedPreKeySignature': base64Encode(spk.signature),
    'identityKey': base64Encode(
      signalSession.identityKeyPair.getPublicKey().serialize(),
    ),
  };
  return base64Encode(utf8.encode(jsonEncode(bundle)));
}

Future<void> processPeerBundle(String haloId, String bundleB64) async {
  final j =
      jsonDecode(utf8.decode(base64Decode(bundleB64))) as Map<String, dynamic>;
  final preKeyBundle = PreKeyBundle(
    j['registrationId'] as int,
    j['deviceId'] as int,
    j['preKeyId'] as int,
    Curve.decodePoint(base64Decode(j['preKeyPublic'] as String), 0),
    j['signedPreKeyId'] as int,
    Curve.decodePoint(base64Decode(j['signedPreKeyPublic'] as String), 0),
    base64Decode(j['signedPreKeySignature'] as String),
    IdentityKey(Curve.decodePoint(base64Decode(j['identityKey'] as String), 0)),
  );
  final addr = SignalProtocolAddress(haloId, 1);
  final builder = SessionBuilder(
    signalSession.sessionStore,
    signalSession.preKeyStore,
    signalSession.signedPreKeyStore,
    signalSession.identityStore,
    addr,
  );
  await builder.processPreKeyBundle(preKeyBundle);
}

Future<String> signalEncrypt(String peerId, String plaintext) async {
  final addr = SignalProtocolAddress(peerId, 1);
  final cipher = SessionCipher(
    signalSession.sessionStore,
    signalSession.preKeyStore,
    signalSession.signedPreKeyStore,
    signalSession.identityStore,
    addr,
  );
  final msg = await cipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
  final wire = Uint8List.fromList([msg.getType(), ...msg.serialize()]);
  return base64Encode(wire);
}

Future<String?> signalDecrypt(String peerId, String wireB64) async {
  try {
    final wire = base64Decode(wireB64);
    if (wire.isEmpty) return null;
    final type = wire[0];
    final body = Uint8List.fromList(wire.sublist(1));
    final addr = SignalProtocolAddress(peerId, 1);
    final cipher = SessionCipher(
      signalSession.sessionStore,
      signalSession.preKeyStore,
      signalSession.signedPreKeyStore,
      signalSession.identityStore,
      addr,
    );
    Uint8List plain;
    if (type == CiphertextMessage.prekeyType) {
      plain = await cipher.decrypt(PreKeySignalMessage(body));
    } else {
      plain = await cipher.decryptFromSignal(
        SignalMessage.fromSerialized(body),
      );
    }
    return utf8.decode(plain);
  } catch (e) {
    debugPrint('signalDecrypt: $e');
    return null;
  }
}

Future<String> handleHaloUri(String raw) async {
  final parsed = parseHaloUri(raw);
  if (parsed == null) return 'invalid uri';
  if (parsed['v'] == '2') {
    try {
      await processPeerBundle(parsed['id']!, parsed['bundle']!);
    } catch (e) {
      return 'bundle error: $e';
    }
    await db.upsertContact(parsed['id']!, parsed['onion']!, '');
    await appState.subscribePeer(parsed['id']!);
    return 'signal session built: ${parsed['id']}';
  } else {
    await db.upsertContact(parsed['id']!, parsed['onion']!, parsed['xpub']!);
    await appState.subscribePeer(parsed['id']!);
    return 'peer imported (v1): ${parsed['id']}';
  }
}

Future<String> saveMediaBytes(List<int> bytes, String name) async {
  final dir = await getApplicationDocumentsDirectory();
  final mediaDir = Directory('${dir.path}/media');
  if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
  final file = File('${mediaDir.path}/$name.jpg');
  await file.writeAsBytes(bytes);
  return file.path;
}

String buildHaloUri(String id, String onion, String xpub) {
  return 'halo://share?id=$id&onion=$onion&xpub=$xpub';
}

Future<String> buildHaloUriV2(String id, String onion) async {
  final bundle = await makePreKeyBundleB64();
  return 'halo://share?id=$id&onion=$onion&v=2&bundle=$bundle';
}

Map<String, String>? parseHaloUri(String raw) {
  raw = raw.trim();
  if (!raw.startsWith('halo://share')) return null;
  try {
    final uri = Uri.parse(raw);
    final id = uri.queryParameters['id'];
    final onion = uri.queryParameters['onion'];
    if (id == null || onion == null) return null;
    final v = uri.queryParameters['v'] ?? '1';
    if (v == '2') {
      final bundle = uri.queryParameters['bundle'];
      if (bundle == null) return null;
      return {'id': id, 'onion': onion, 'bundle': bundle, 'v': '2'};
    }
    final xpub = uri.queryParameters['xpub'];
    if (xpub == null) return null;
    return {'id': id, 'onion': onion, 'xpub': xpub, 'v': '1'};
  } catch (_) {
    return null;
  }
}

// shared singletons + state

final engine = HaloEngine();
final db = HaloDb();

// open ChatScreen for a given halo id. used by notification taps
// (both warm — onDidReceiveNotificationResponse — and cold starts
// via getNotificationAppLaunchDetails). reads contact details from
// the db and pushes the route on the root navigator.
Future<void> openChatForHalo(String? haloId) async {
  if (haloId == null || haloId.isEmpty) return;
  final nav = rootNavKey.currentState;
  if (nav == null) return;
  final rows = await db.contacts();
  final matches = rows.where((r) => r['halo_id'] == haloId).toList();
  if (matches.isEmpty) return;
  final row = matches.first;
  nav.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        peerHaloId: haloId,
        peerOnion: row['onion'] as String,
        peerXPub: row['xpub'] as String,
        avatarSeed: haloId,
      ),
    ),
  );
}

// halo id of the peer whose chat is currently on screen. set by
// ChatScreen.initState, cleared on dispose. used to suppress
// notifications for the conversation the user is already in.
String? currentChatPeer;

final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

int _msgUidCounter = 0;
// stable cross-device message id. used by reactions + replies + group
// fan-out so every recipient sees the same uid. base36 timestamp + random.
String newMsgUid() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = (DateTime.now().microsecondsSinceEpoch ^ _msgUidCounter++)
      .abs()
      .toRadixString(36);
  return '${t.padLeft(8, '0').substring(0, 8)}${r.substring(0, 4).padLeft(4, '0')}';
}

class GroupPreview {
  final String groupId;
  final String name;
  final int memberCount;
  final bool isAdmin;
  final DateTime createdAt;
  const GroupPreview({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.isAdmin,
    required this.createdAt,
  });
}

class AppState extends ChangeNotifier {
  // global send-privacy mode: 'fast' | 'normal' | 'private'. cosmetic for now —
  // every message routes over full tor until fast/hop modes wire up (phase 2).
  String _sendMode = 'private';
  String get sendMode => _sendMode;
  Future<void> loadSendMode() async {
    _sendMode =
        await const FlutterSecureStorage().read(key: 'send_mode') ?? 'private';
    notifyListeners();
  }

  Future<void> setSendMode(String m) async {
    _sendMode = m;
    notifyListeners();
    await const FlutterSecureStorage().write(key: 'send_mode', value: m);
  }

  NtfyListener? _ntfyListener;

  Future<void> applyPushMode(PushMode m) async {
    await savePushMode(m);
    if (m == PushMode.ntfy) {
      _ntfyListener ??= NtfyListener(
        onPing: () => debugPrint('ntfy: wake-up received'),
        log: (msg) => debugPrint(msg),
      );
      await _ntfyListener!.start();
    } else {
      await _ntfyListener?.stop();
      _ntfyListener = null;
    }
  }

  // unified incoming routing. handles three payload variants:
  //   1) group control msg (no chat row, no notif)
  //   2) reaction       (add/remove on a target uid, no chat row, no notif)
  //   3) data message   (1:1 or group — save + maybe notify)
  // called from all three receive paths (back-pair-from-cipher, tor drain,
  // nostr poll) so the routing rules live in exactly one place.
  Future<void> _applyIncomingPayload(
    String senderHaloId,
    UnwrappedMessage env,
  ) async {
    if (await db.isBlocked(senderHaloId)) return;
    // 1) group control
    if (env.groupControl != null) {
      await _applyGroupControl(senderHaloId, env);
      return;
    }
    // 2) reaction
    if (env.reaction != null) {
      final r = env.reaction!;
      if (r.emoji.isEmpty) {
        await db.removeReaction(r.targetUid, senderHaloId);
      } else {
        await db.addReaction(r.targetUid, senderHaloId, r.emoji);
      }
      return;
    }
    // 2.5) edit — swap the text of an existing message
    if (env.edit != null) {
      await db.editMessage(env.edit!.targetUid, env.edit!.newText);
      return;
    }
    // 3) data message — could be 1:1 or group
    final isGroup = env.groupId != null;
    if (isGroup && !await db.groupExists(env.groupId!)) {
      // unknown group — drop. prevents random senders from injecting rows
      // into groups we never joined.
      debugPrint('dropping group msg for unknown group ${env.groupId}');
      return;
    }
    String? mediaPath;
    if (env.imageB64 != null && env.imageB64!.isNotEmpty) {
      try {
        mediaPath = await saveMediaBytes(
          base64Decode(env.imageB64!),
          env.msgUid ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } catch (_) {}
    }
    await db.saveMessage(
      senderHaloId,
      'in',
      env.message,
      burnAt: env.burnSeconds != null && env.burnSeconds! > 0
          ? DateTime.now().millisecondsSinceEpoch + env.burnSeconds! * 1000
          : null,
      msgUid: env.msgUid,
      replyTo: env.replyTo,
      groupId: env.groupId,
      mediaPath: mediaPath,
    );
    // notification context — for groups, title = group name and body
    // prefixes the sender. payload uses "group:<id>" so tap-to-open can
    // route to the right screen.
    final String notifTitle;
    final String notifBody;
    final String notifPayload;
    final bool suppress;
    if (isGroup) {
      final g = await db.getGroup(env.groupId!);
      notifTitle = (g?['name'] as String?) ?? 'group';
      notifBody = '$senderHaloId: ${env.message}';
      notifPayload = 'group:${env.groupId}';
      suppress = currentChatPeer == notifPayload;
    } else {
      notifTitle = senderHaloId;
      notifBody = env.message.isNotEmpty
          ? env.message
          : (mediaPath != null ? 'photo' : env.message);
      notifPayload = senderHaloId;
      suppress =
          currentChatPeer == senderHaloId || await db.isMuted(senderHaloId);
    }
    if (!suppress) {
      await showMessageNotification(
        title: notifTitle,
        body: notifBody,
        payload: notifPayload,
      );
    }
  }

  // apply a group control message. sender is the halo id that sent the
  // control; env.groupId is the target group; env.groupControl carries the
  // action and payload.
  Future<void> _applyGroupControl(
    String senderHaloId,
    UnwrappedMessage env,
  ) async {
    final gc = env.groupControl!;
    final groupId = env.groupId;
    if (groupId == null) return;
    switch (gc.type) {
      case 'create':
        // someone added us to a new group. they are the admin; we are
        // a regular member. group.is_admin stays 0.
        if (gc.members == null || gc.name == null) return;
        if (!await db.groupExists(groupId)) {
          await db.createGroup(groupId, gc.name!, gc.members!, isAdmin: false);
        }
        // auto-create contact stubs for unknown participants so we can
        // immediately send to them.
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null && o != null && x != null && h != myId) {
              await db.upsertContactStub(h, o, x);
            }
          }
        }
        await refreshContacts();
        await refreshGroups();
        break;
      case 'add':
        if (gc.members == null) return;
        for (final h in gc.members!) {
          await db.addGroupMember(groupId, h);
        }
        if (gc.participants != null) {
          for (final p in gc.participants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null && o != null && x != null && h != myId) {
              await db.upsertContactStub(h, o, x);
            }
          }
        }
        await refreshContacts();
        await refreshGroups();
        break;
      case 'remove':
        if (gc.members == null) return;
        for (final h in gc.members!) {
          await db.removeGroupMember(groupId, h);
        }
        break;
      case 'rename':
        if (gc.name == null) return;
        await db.renameGroup(groupId, gc.name!);
        break;
      case 'leave':
        await db.removeGroupMember(groupId, senderHaloId);
        break;
    }
  }

  Future<void> applyNtfyServerChange(String url) async {
    await saveNtfyServer(url);
    if (_ntfyListener != null) {
      await _ntfyListener!.stop();
      _ntfyListener = NtfyListener(
        onPing: () => debugPrint('ntfy: wake-up received'),
        log: (msg) => debugPrint(msg),
      );
      await _ntfyListener!.start();
    }
  }

  bool onboardingComplete = false;
  late AppLinks _appLinks;
  String myId = '';
  String myOnion = '';
  List<GroupPreview> groups = [];
  String myXPub = '';
  bool restored = false;
  bool ready = false;
  List<ContactPreview> contacts = [];
  final Map<String, String> _xPubToHaloId = {};

  // sprint 6.13: when an unknown sender's PreKey message arrives via
  // direct onion, decrypt under a placeholder peerId, then verify the
  // sender's claimed identity (via envelope) and move the libsignal
  // session to the real HaloID.
  Future<String?> backPairFromCipher(String cipher) async {
    const tempPeer = '_pending_back_pair_';
    final tempAddr = SignalProtocolAddress(tempPeer, 1);
    try {
      if (await signalSession.sessionStore.containsSession(tempAddr)) {
        await signalSession.sessionStore.deleteSession(tempAddr);
      }
      final plain = await signalDecrypt(tempPeer, cipher);
      if (plain == null) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        return null;
      }
      final env = unwrapMessage(plain);
      final h = env.senderHaloId;
      final e = env.senderEdPub;
      if (h == null || e == null) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        debugPrint('back-pair: envelope missing identity fields');
        return null;
      }
      final derived = engine.idFromEdPub(e);
      if (derived != h) {
        await signalSession.sessionStore.deleteSession(tempAddr);
        debugPrint('back-pair: HaloID mismatch ($derived vs $h)');
        return null;
      }
      // move session from temp to real HaloID
      final record = await signalSession.sessionStore.loadSession(tempAddr);
      final realAddr = SignalProtocolAddress(h, 1);
      await signalSession.sessionStore.storeSession(realAddr, record);
      await signalSession.sessionStore.deleteSession(tempAddr);
      // persist contact + nostr sub
      await db.upsertContact(h, env.senderOnion ?? '', env.senderXPub ?? '');
      if (env.senderXPub != null && env.senderXPub!.isNotEmpty) {
        _xPubToHaloId[env.senderXPub!] = h;
        engine.nostrSubscribe(env.senderXPub!);
      }
      if (env.endpoint != null) {
        await savePeerEndpoint(h, env.endpoint!);
      }
      await _applyIncomingPayload(h, env);
      await refreshContacts();
      notifyListeners();
      debugPrint('back-pair: created contact $h via direct onion');
      return h;
    } catch (e) {
      debugPrint('back-pair error: $e');
      try {
        await signalSession.sessionStore.deleteSession(tempAddr);
      } catch (_) {}
      return null;
    }
  }

  Future<void> boot() async {
    if (ready) return;
    final saved = await db.loadIdentity();
    if (saved != null) {
      myId = engine.restoreIdentity(saved['ed_priv']!, saved['x_priv']!);
      restored = true;
    } else {
      myId = engine.generateIdentity();
      await db.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    }
    myXPub = engine.myXPubkey();
    await _bootSignal();
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'halo') {
        final result = await handleHaloUri(uri.toString());
        debugPrint('deep link: $result');
        await refreshContacts();
        notifyListeners();
      }
    });

    await refreshContacts();
    await refreshGroups();
    // sprint 7.5: auto-start tor; nostr subs retry every 10s until ready
    final docsDir = await getApplicationDocumentsDirectory();
    _startListenerOnIsolate(docsDir.path).then((addr) {
      if (addr.isNotEmpty && !addr.startsWith('error')) {
        myOnion = addr;
        notifyListeners();
      }
    });
    engine.nostrInit('wss://relay.damus.io,wss://nos.lol');
    await initNotifications(onTap: openChatForHalo);

    // periodic sweep: delete messages whose burn_at has passed.
    Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await db.purgeExpired();
      } catch (_) {}
    });
    for (final c in contacts) {
      final xPub = await signalSession.peerXPubHex(c.haloId);
      if (xPub != null) {
        _xPubToHaloId[xPub] = c.haloId;
        engine.nostrSubscribe(xPub);
      }
    }
    // sprint 11d: open ntfy websocket when push mode is ntfy. on incoming
    // ping, the existing 1s drain loop catches up — we just log for now.
    final mode = await loadPushMode();
    if (mode == PushMode.ntfy) {
      _ntfyListener = NtfyListener(
        onPing: () => debugPrint('ntfy: wake-up received'),
        log: (m) => debugPrint(m),
      );
      _ntfyListener!.start();
    }

    // sprint 6.13: continuous drain of direct-onion inbox. handles back-
    // pair from strangers + falls back to trial-decrypt against known
    // contacts for in-session direct-onion messages.
    Timer.periodic(const Duration(seconds: 1), (_) async {
      final ciphers = engine.drainInbox();
      if (ciphers.isEmpty) return;
      for (final cipher in ciphers) {
        var handled = false;
        for (final c in contacts) {
          final plain = await signalDecrypt(c.haloId, cipher);
          if (plain != null) {
            final env = unwrapMessage(plain);
            if (env.endpoint != null) {
              await savePeerEndpoint(c.haloId, env.endpoint!);
            }
            await _applyIncomingPayload(c.haloId, env);
            notifyListeners();
            handled = true;
            break;
          }
        }
        if (!handled) await backPairFromCipher(cipher);
      }
    });

    Timer.periodic(const Duration(seconds: 1), (_) async {
      final msgs = engine.nostrPoll();
      if (msgs.isEmpty) return;
      debugPrint('nostr poll: ${msgs.length} messages');
      for (final m in msgs) {
        var haloId = _xPubToHaloId[m.peer];
        String? wrapped = haloId == null
            ? null
            : await signalDecrypt(haloId, m.cipher);
        // fallback: xpub not mapped yet (or it decrypted wrong) — trial
        // against known contacts like the direct path, then remember it.
        if (wrapped == null) {
          for (final c in contacts) {
            if (c.haloId == haloId) continue;
            final p = await signalDecrypt(c.haloId, m.cipher);
            if (p != null) {
              wrapped = p;
              haloId = c.haloId;
              _xPubToHaloId[m.peer] = c.haloId;
              break;
            }
          }
        }
        if (wrapped == null) {
          debugPrint('  nostr: no known contact could decrypt');
          continue;
        }
        final env = unwrapMessage(wrapped);
        if (env.endpoint != null) {
          await savePeerEndpoint(haloId!, env.endpoint!);
        }
        await _applyIncomingPayload(haloId!, env);
        notifyListeners();
      }
    });
    final _stored = await const FlutterSecureStorage().read(
      key: 'onboarding_done',
    );
    onboardingComplete = _stored == 'true';
    ready = true;
    notifyListeners();
  }

  Future<void> _bootSignal() async {
    try {
      final database = await db.open();
      await signalSession.bootstrap(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: _hexDecode(engine.myXPrivkey()),
      );
    } catch (e, st) {
      debugPrint('signal bootstrap failed: $e\n$st');
    }
  }

  Uint8List _hexDecode(String s) {
    final bytes = Uint8List(s.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  Future<void> archive(String haloId) async {
    await db.setArchived(haloId, true);
    await refreshContacts();
  }

  Future<void> unarchive(String haloId) async {
    await db.setArchived(haloId, false);
    await refreshContacts();
  }

  Future<void> mute(String haloId) async {
    await db.setMuted(haloId, true);
    await refreshContacts();
  }

  Future<void> unmute(String haloId) async {
    await db.setMuted(haloId, false);
    await refreshContacts();
  }

  Future<void> block(String haloId) async {
    await db.setBlocked(haloId, true);
    await refreshContacts();
  }

  Future<void> unblock(String haloId) async {
    await db.setBlocked(haloId, false);
    await refreshContacts();
  }

  Future<List<({String haloId, String? nickname})>> blockedContacts() async {
    final rows = await db.contacts();
    return [
      for (final r in rows)
        if ((r['blocked'] as int? ?? 0) == 1)
          (haloId: r['halo_id'] as String, nickname: r['nickname'] as String?),
    ];
  }

  Future<void> refreshContacts() async {
    final rows = await db.contacts();
    final list = <ContactPreview>[];
    for (final r in rows) {
      final haloId = r['halo_id'] as String;
      final last = await db.lastMessageFor(haloId);
      String? preview;
      // default to the contact's last_seen; a real message overrides it.
      DateTime when = DateTime.fromMillisecondsSinceEpoch(
        r['last_seen'] as int,
      );
      if (last != null) {
        final dir = last['direction'] as String?;
        final text = (last['plaintext'] as String?) ?? '';
        final media = last['media_path'] as String?;
        final body = text.isNotEmpty ? text : (media != null ? 'photo' : '');
        if (body.isNotEmpty) preview = dir == 'out' ? 'you: $body' : body;
        final sentAt = last['sent_at'] as int?;
        if (sentAt != null) {
          when = DateTime.fromMillisecondsSinceEpoch(sentAt);
        }
      }
      list.add(
        ContactPreview(
          haloId: haloId,
          nickname: r['nickname'] as String?,
          avatarSeed: haloId,
          preview: preview,
          when: when,
          blocked: (r['blocked'] as int? ?? 0) == 1,
          archived: (r['archived'] as int? ?? 0) == 1,
        ),
      );
    }
    // most-recent conversation floats to the top
    list.sort(
      (a, b) => (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0)),
    );
    contacts = list;
    notifyListeners();
  }

  // ---- groups ----

  Future<void> refreshGroups() async {
    final rows = await db.loadGroups();
    final list = <GroupPreview>[];
    for (final r in rows) {
      final gid = r['group_id'] as String;
      final members = await db.getGroupMembers(gid);
      list.add(
        GroupPreview(
          groupId: gid,
          name: r['name'] as String,
          memberCount: members.length,
          isAdmin: (r['is_admin'] as int? ?? 0) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            r['created_at'] as int,
          ),
        ),
      );
    }
    groups = list;
    notifyListeners();
  }

  SenderInfo _mySender() => SenderInfo(
    haloId: myId,
    edPub: engine.myEdPubkey(),
    onion: myOnion,
    xPub: engine.myXPubkey(),
  );

  // pairwise envelope send. wraps libsignal encrypt + transport choice
  // (direct-onion if peer hasn't back-paired yet, nostr otherwise).
  Future<bool> _sendOneEnvelope(String memberId, String wrapped) async {
    try {
      final contact = await db.getContact(memberId);
      if (contact == null) {
        debugPrint('send: no contact for \$memberId');
        return false;
      }
      final cipher = await signalEncrypt(memberId, wrapped);
      final backPaired = await db.isBackPaired(memberId);
      final xpub = contact['xpub'] as String;
      final onion = contact['onion'] as String;
      // try direct tor first only when peer hasn't back-paired and we have
      // their onion. on timeout / failure, fall back to nostr store-and-forward.
      if (!backPaired && onion.isNotEmpty) {
        final tor = await Future(() => engine.sendTo(onion, cipher));
        if (tor == 'ok') return true;
        debugPrint('send: tor direct failed (\$tor), trying nostr');
      }
      final n = await Future(() => engine.nostrSend(xpub, cipher));
      if (n == 'ok') return true;
      debugPrint('send: nostr also failed (\$n)');
      return false;
    } catch (e) {
      debugPrint('send to \$memberId failed: \$e');
      return false;
    }
  }

  Future<void> _sendControlToGroup(String groupId, GroupControl gc) async {
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      groupControl: gc,
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
  }

  // send a normal text message into a group. saves the local row, then
  // multicasts pairwise to every other member. returns true if at least
  // one recipient acknowledged.
  Future<bool> sendToGroup(
    String groupId,
    String plain, {
    String? msgUid,
    String? replyTo,
    int? burnSeconds,
  }) async {
    msgUid ??= newMsgUid();
    final burnAt = (burnSeconds != null && burnSeconds > 0)
        ? DateTime.now().millisecondsSinceEpoch + burnSeconds * 1000
        : null;
    // save the local row up-front so the chat list shows it immediately.
    // peer_id = self so we render it as outgoing.
    await db.saveMessage(
      myId,
      'out',
      plain,
      groupId: groupId,
      msgUid: msgUid,
      replyTo: replyTo,
      burnAt: burnAt,
    );
    final wrapped = await wrapMessage(
      plain,
      msgUid: msgUid,
      replyTo: replyTo,
      burnSeconds: burnSeconds,
      groupId: groupId,
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    final results = await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
    final anyOk = results.any((ok) => ok);
    notifyListeners();
    return anyOk;
  }

  // pairwise reaction multicast for group messages.
  Future<void> reactInGroup(
    String groupId,
    String targetMsgUid,
    String emoji,
  ) async {
    if (emoji.isEmpty) {
      await db.removeReaction(targetMsgUid, '');
    } else {
      await db.addReaction(targetMsgUid, '', emoji);
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      reaction: ReactionFrame(targetUid: targetMsgUid, emoji: emoji),
      sender: _mySender(),
    );
    final members = await db.getGroupMembers(groupId);
    await Future.wait([
      for (final memberId in members)
        if (memberId != myId) _sendOneEnvelope(memberId, wrapped),
    ]);
    notifyListeners();
  }

  // build participant info {h,o,x} for each halo_id we have as a contact
  // (or for our own halo). used to give group invites enough info that
  // recipients can fan-out to members they don't yet know.
  Future<List<Map<String, String>>> _buildParticipants(
    List<String> haloIds,
  ) async {
    final out = <Map<String, String>>[];
    for (final h in haloIds) {
      if (h == myId) {
        out.add({'h': myId, 'o': myOnion, 'x': engine.myXPubkey()});
      } else {
        final c = await db.getContact(h);
        if (c != null) {
          out.add({
            'h': h,
            'o': c['onion'] as String,
            'x': c['xpub'] as String,
          });
        }
      }
    }
    return out;
  }

  // create a group locally and announce it to invited members. memberHaloIds
  // is the set of OTHER members (caller's halo id is added automatically).
  // returns the new group id.
  Future<String> createGroupAndAnnounce(
    String name,
    List<String> memberHaloIds,
  ) async {
    final groupId = newMsgUid();
    final full = [myId, ...memberHaloIds];
    await db.createGroup(groupId, name, full, isAdmin: true);
    final participants = await _buildParticipants(full);
    final gc = GroupControl(
      type: 'create',
      name: name,
      members: full,
      participants: participants,
    );
    await _sendControlToGroup(groupId, gc);
    await refreshGroups();
    return groupId;
  }

  // admin-only. adds members locally, sends 'add' to existing members
  // (with participants for the new ones), and sends a full 'create' to
  // each new member so they bootstrap the group.
  Future<void> addMembersToGroup(
    String groupId,
    List<String> newHaloIds,
  ) async {
    final group = await db.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final existingMembers = await db.getGroupMembers(groupId);
    for (final h in newHaloIds) {
      await db.addGroupMember(groupId, h);
    }
    final newParticipants = await _buildParticipants(newHaloIds);
    final addGc = GroupControl(
      type: 'add',
      members: newHaloIds,
      participants: newParticipants,
    );
    for (final memberId in existingMembers) {
      if (memberId == myId) continue;
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: addGc,
        sender: _mySender(),
      );
      await _sendOneEnvelope(memberId, wrapped);
    }
    final allMembers = await db.getGroupMembers(groupId);
    final allParticipants = await _buildParticipants(allMembers);
    final createGc = GroupControl(
      type: 'create',
      name: group['name'] as String,
      members: allMembers,
      participants: allParticipants,
    );
    for (final newMember in newHaloIds) {
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: createGc,
        sender: _mySender(),
      );
      await _sendOneEnvelope(newMember, wrapped);
    }
    await refreshGroups();
  }

  // admin-only. removes locally and tells everyone (including removed) so
  // both sides converge on the new member list.
  Future<void> removeMembersFromGroup(
    String groupId,
    List<String> removedHaloIds,
  ) async {
    final group = await db.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final allMembers = await db.getGroupMembers(groupId);
    for (final h in removedHaloIds) {
      await db.removeGroupMember(groupId, h);
    }
    final gc = GroupControl(type: 'remove', members: removedHaloIds);
    for (final memberId in allMembers) {
      if (memberId == myId) continue;
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: gc,
        sender: _mySender(),
      );
      await _sendOneEnvelope(memberId, wrapped);
    }
    await refreshGroups();
  }

  Future<void> renameGroupAndAnnounce(String groupId, String newName) async {
    final group = await db.getGroup(groupId);
    if (group == null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    await db.renameGroup(groupId, newName);
    final gc = GroupControl(type: 'rename', name: newName);
    await _sendControlToGroup(groupId, gc);
    await refreshGroups();
  }

  // anyone can leave. tells the remaining members so they can drop us from
  // their copies. caller deletes the group locally.
  Future<void> leaveGroupAndAnnounce(String groupId) async {
    final gc = GroupControl(type: 'leave');
    await _sendControlToGroup(groupId, gc);
    await db.deleteGroup(groupId);
    await refreshGroups();
  }

  Future<void> regenerateIdentity() async {
    myId = engine.generateIdentity();
    await db.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    myXPub = engine.myXPubkey();
    restored = false;
    notifyListeners();
  }

  Future<void> subscribePeer(String haloId) async {
    final xPub = await signalSession.peerXPubHex(haloId);
    if (xPub != null) {
      _xPubToHaloId[xPub] = haloId;
      engine.nostrSubscribe(xPub);
    }
  }

  Future<void> markOnboardingComplete() async {
    onboardingComplete = true;
    await const FlutterSecureStorage().write(
      key: 'onboarding_done',
      value: 'true',
    );
    notifyListeners();
  }
}

final appState = AppState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HaloApp());
  // cold-start: if launched from a notification tap, open the chat
  // after the first frame so rootNavKey has a navigator.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final details = await notifPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      Future.delayed(
        const Duration(milliseconds: 500),
        () => openChatForHalo(payload),
      );
    }
  });
}

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavKey,
      title: 'Halo',
      theme: buildHaloTheme(),
      home: const _LockGate(child: _OnboardingGate(child: RootShell())),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_onChange);
    appState.boot();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    appState.removeListener(_onChange);
    super.dispose();
  }

  void _open(Widget w) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.ready) {
      return Scaffold(
        backgroundColor: HaloColors.surface,
        body: Center(
          child: Text(
            'booting...',
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ),
      );
    }
    return HomeScreen(
      haloId: appState.myId,
      contacts: appState.contacts,
      groups: appState.groups
          .map(
            (g) => GroupSummary(
              groupId: g.groupId,
              name: g.name,
              memberCount: g.memberCount,
            ),
          )
          .toList(),
      onAddContact: () => _open(const DevScreen()),
      onNewGroup: () => _open(const NewGroupScreen()),
      onOpenDev: () => _open(const DevScreen()),
      onOpenSettings: () => _open(SettingsScreen()),
      onOpenChat: (id) async {
        final rows = await db.contacts();
        final matches = rows.where((r) => r['halo_id'] == id).toList();
        if (matches.isEmpty || !mounted) return;
        final row = matches.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              peerHaloId: id,
              peerOnion: row['onion'] as String,
              peerXPub: row['xpub'] as String,
              avatarSeed: id,
            ),
          ),
        );
      },
      onOpenGroup: (groupId) async {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId)),
        );
      },
    );
  }
}

class DevScreen extends StatefulWidget {
  const DevScreen({super.key});
  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen> {
  final _msgCtrl = TextEditingController(text: 'hello from the other side');
  String _myAddr = '';
  String _status = '';
  TorStatus _torStatus = TorStatus.off;
  int _bootstrapPct = 0;
  String _peerId = '';
  String _peerOnion = '';
  String _peerXPub = '';
  String _receivedCipher = '';
  String _receivedPlain = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _status = appState.restored ? 'identity restored' : 'identity created';
    _loadLastPeer();
  }

  Future<void> _loadLastPeer() async {
    final rows = await db.contacts();
    if (rows.isEmpty) return;
    setState(() {
      _peerId = rows.first['halo_id'] as String;
      _peerOnion = rows.first['onion'] as String;
      _peerXPub = rows.first['xpub'] as String;
    });
  }

  Future<void> _startListener() async {
    setState(() => _status = 'starting tor (~30s)...');
    final docsDir = await getApplicationDocumentsDirectory();
    final addr = await Future(() => engine.startListener(docsDir.path));
    setState(() {
      if (addr.startsWith('error')) {
        _status = addr;
      } else {
        _myAddr = addr;
        _status = '';
      }
    });
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final raw = engine.getStatus();
      final newStatus = parseTorStatus(raw);
      final newPct = parseBootstrapPct(raw);
      if ((newStatus != _torStatus || newPct != _bootstrapPct) && mounted) {
        setState(() {
          _torStatus = newStatus;
          _bootstrapPct = newPct;
        });
      }
      final msgs = engine.drainInbox();
      if (msgs.isEmpty || _peerXPub.isEmpty) return;
      for (final r in msgs) {
        final plain = engine.decryptFrom(_peerXPub, r);
        if (!plain.startsWith('error')) {
          db.saveMessage(_peerId, 'in', plain);
        }
        setState(() {
          _receivedCipher = r;
          _receivedPlain = plain;
        });
      }
    });
  }

  Future<void> _send() async {
    if (_peerOnion.isEmpty || _peerXPub.isEmpty) {
      setState(() => _status = 'scan or import a peer first');
      return;
    }
    setState(() => _status = 'encrypting + sending (~30s)...');
    final plain = _msgCtrl.text;
    final cipher = engine.encryptFor(_peerXPub, plain);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => engine.sendTo(_peerOnion, cipher));
    if (result == 'ok') {
      await db.saveMessage(_peerId, 'out', plain);
    }
    setState(() => _status = result);
  }

  Future<void> _showMyQr() async {
    if (_myAddr.isEmpty) {
      setState(() => _status = 'tap start listening first');
      return;
    }
    final uri = await buildHaloUriV2(appState.myId, _myAddr);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: HaloColors.onAmber,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'your halo',
                style: HaloType.serif(
                  size: 14,
                  italic: true,
                  color: HaloColors.amber,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appState.myId,
                style: HaloType.mono(size: 18, color: HaloColors.amber),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HaloColors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  uri,
                  style: HaloType.mono(size: 9, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uri));
                  showHaloToast(context, 'uri copied');
                },
                child: Text(
                  'copy uri',
                  style: HaloType.sans(color: HaloColors.amber),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importPeer() async {
    final ctrl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HaloColors.surface2,
        title: Text(
          'add a halo',
          style: HaloType.sans(color: HaloColors.amber),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'scan'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('scan qr'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '— or paste —',
              style: HaloType.sans(size: 11, color: HaloColors.text3),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 4,
              style: HaloType.mono(size: 11, color: HaloColors.text),
              decoration: InputDecoration(
                hintText: 'halo://share?...',
                hintStyle: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'paste'),
            child: Text(
              'import',
              style: HaloType.sans(color: HaloColors.amber),
            ),
          ),
        ],
      ),
    );
    if (action == null) return;

    String uri;
    if (action == 'scan') {
      final result = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
      if (result == null) return;
      uri = result;
    } else {
      uri = ctrl.text;
    }

    final status = await handleHaloUri(uri);
    await appState.refreshContacts();
    final parsed = parseHaloUri(uri);
    if (!mounted) return;
    setState(() {
      if (parsed != null) {
        _peerId = parsed['id'] ?? '';
        _peerOnion = parsed['onion'] ?? '';
        _peerXPub = parsed['xpub'] ?? '';
      }
      _status = status;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text(
          'dev',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'halo',
                style: HaloType.serif(
                  size: 56,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.amber,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                engine.version(),
                style: HaloType.sans(size: 11, color: HaloColors.text3),
              ),
              const SizedBox(height: 16),
              Text(
                'your halo:',
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: HaloColors.onAmber,
                  border: Border.all(color: HaloColors.amber, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appState.myId.isEmpty ? '...' : appState.myId,
                  style: HaloType.mono(
                    size: 18,
                    color: HaloColors.amber,
                    letter: 0.04,
                  ),
                ),
              ),
              if (appState.restored)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'restored from disk',
                    style: HaloType.mono(size: 9, color: HaloColors.green),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _myAddr.isEmpty ? _startListener : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_myAddr.isEmpty ? 'start listening' : 'listening'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code, color: HaloColors.amber),
                      label: const Text('show my qr'),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.content_paste,
                        color: HaloColors.violet,
                      ),
                      label: const Text('import peer'),
                      onPressed: _importPeer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_peerId.isNotEmpty) ...[
                Text(
                  'peer:',
                  style: HaloType.sans(size: 11, color: HaloColors.text2),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    border: Border.all(color: HaloColors.green, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _peerId,
                    style: HaloType.mono(size: 14, color: HaloColors.green),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _msgCtrl,
                style: HaloType.sans(color: HaloColors.text),
                decoration: InputDecoration(
                  labelText: 'message (will be encrypted)',
                  labelStyle: HaloType.sans(color: HaloColors.text2),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (_myAddr.isEmpty || _peerOnion.isEmpty)
                    ? null
                    : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('encrypt + send'),
              ),
              const SizedBox(height: 16),
              TorWarmupGraph(status: _torStatus, bootstrapPct: _bootstrapPct),
              const SizedBox(height: 12),
              if (_status.isNotEmpty)
                Text(
                  'status: $_status',
                  style: HaloType.sans(size: 12, color: HaloColors.text2),
                ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ModesScreen())),
                child: Text(
                  'speed & privacy →',
                  style: HaloType.mono(size: 11, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PushSettingsScreen()),
                ),
                child: Text(
                  'notifications →',
                  style: HaloType.mono(size: 11, color: HaloColors.amber),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  if (lockState.enabled) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: HaloColors.surface3,
                        title: Text(
                          'disable app lock?',
                          style: HaloType.serif(
                            size: 18,
                            color: HaloColors.text,
                          ),
                        ),
                        content: Text(
                          'the pin will be removed. anyone with your phone will see halo when they open it.',
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              'cancel',
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.text2,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(
                              'disable',
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await lockState.disable();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LockSetupScreen(),
                      ),
                    );
                  }
                },
                child: AnimatedBuilder(
                  animation: lockState,
                  builder: (_, __) => Text(
                    lockState.enabled ? 'app lock · on →' : 'app lock · off →',
                    style: HaloType.mono(size: 11, color: HaloColors.amber),
                  ),
                ),
              ),
              if (_receivedPlain.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    border: Border.all(color: HaloColors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'decrypted:',
                        style: HaloType.mono(size: 10, color: HaloColors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _receivedPlain,
                        style: HaloType.sans(size: 14, color: HaloColors.text),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingGate extends StatefulWidget {
  final Widget child;
  const _OnboardingGate({required this.child});
  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  @override
  void initState() {
    super.initState();
    if (!appState.ready) {
      appState.boot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.ready) {
          return const TorBootSplash();
        }
        if (!appState.onboardingComplete) {
          return OnboardingScreen(
            appState: appState,
            onComplete: () => appState.markOnboardingComplete(),
          );
        }
        return widget.child;
      },
    );
  }
}

class _LockGate extends StatefulWidget {
  final Widget child;
  const _LockGate({required this.child});
  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lockState.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      lockState.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: lockState,
      builder: (_, __) {
        if (lockState.locked) return const LockScreen();
        return widget.child;
      },
    );
  }
}
