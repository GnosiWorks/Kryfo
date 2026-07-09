// SPDX-License-Identifier: GPL-3.0-or-later
// halo mobile - phase 1: identity persistence + ECDH + editorial UI

import 'dart:async';
import 'widgets/tor_boot_splash.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/group_chat_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/modes_screen.dart';
import 'screens/push_settings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_halo_screen.dart';
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

typedef VoidFn = Void Function();
typedef VoidFnDart = void Function();
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
  late final VoidFnDart _shutdown;
  late final CStrFnDart _getStatus;
  late final TwoArgFnDart _send;
  late final OneArgFnDart _nostrInit;
  late final TwoArgFnDart _nostrSend;
  late final OneArgFnDart _nostrSubscribe;
  late final CStrFnDart _nostrPoll;
  late final OneArgFnDart _ntfyPing;
  late final OneArgFnDart _torGet;
  late final OneArgFnDart _torGetB64;
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
    _shutdown = _lib.lookupFunction<VoidFn, VoidFnDart>('HaloShutdown');
    _getStatus = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloGetStatus');
    _send = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSendTo');
    _nostrInit = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrInit');
    _nostrSend = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloNostrSend');
    _nostrSubscribe = _lib.lookupFunction<OneArgFn, OneArgFnDart>(
      'HaloNostrSubscribe',
    );
    _nostrPoll = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloNostrPoll');
    _ntfyPing = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNtfyPing');
    _torGet = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGet');
    _torGetB64 = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGetB64');
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

  void shutdown() => _shutdown();

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
      _sendOnIsolate((nostr: true, a: peerXPubHex, b: b64Cipher)).timeout(
        const Duration(seconds: 30),
        onTimeout: () => 'error: relay timeout',
      );

  void nostrSubscribeBg(String peerXPubHex) {
    _subscribeOnIsolate(peerXPubHex).ignore();
  }

  String nostrSubscribe(String peerXPubHex) {
    final ptr = peerXPubHex.toNativeUtf8();
    try {
      return _nostrSubscribe(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  // fetch a url's html over tor (for sender-side link previews). slow + can
  // fail - caller treats anything starting 'error:' as no-preview.
  String torGet(String url) {
    final ptr = url.toNativeUtf8();
    try {
      return _torGet(ptr).toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  // fetch binary (preview image) over tor, returns 'ok:<base64>' or 'error:..'.
  String torGetB64(String url) {
    final ptr = url.toNativeUtf8();
    try {
      return _torGetB64(ptr).toDartString();
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
      _sendOnIsolate((nostr: false, a: addr, b: msg)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => 'error: onion timeout',
      );
}

// run a blocking native send on a throwaway background isolate so the ui
// thread never stalls on a tor dial. opens its own handle to libhalo -
// same process image, so it shares the running tor - and frees its strings.
Future<String> _nostrInitOnIsolate(String relaysCSV) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrInit');
    final p = relaysCSV.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

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

Future<String> _subscribeOnIsolate(String xPub) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloNostrSubscribe');
    final p = xPub.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

// tor fetches run on a background isolate. the raw ffi call blocks for the whole
// tor round-trip (5-8s), so doing it on the main isolate froze the ui while a
// link preview resolved. re-open the lib inside the isolate, same as sends.
Future<String> torGetOnIsolate(String url) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGet');
    final p = url.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
    }
  });
}

Future<String> torGetB64OnIsolate(String url) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloTorGetB64');
    final p = url.toNativeUtf8();
    try {
      return fn(p).toDartString();
    } finally {
      malloc.free(p);
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
      version: 27,
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
            verified INTEGER NOT NULL DEFAULT 0,
            unread INTEGER NOT NULL DEFAULT 0,
            atmosphere TEXT,
            note TEXT,
            pinned INTEGER NOT NULL DEFAULT 0,
            key_changed INTEGER NOT NULL DEFAULT 0,
            accepted INTEGER NOT NULL DEFAULT 1
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
            file_path TEXT,
            file_name TEXT,
            voice_disguised INTEGER NOT NULL DEFAULT 0,
            saved INTEGER NOT NULL DEFAULT 0,
            sent INTEGER NOT NULL DEFAULT 1,
            preview TEXT,
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
            description TEXT,
            created_at INTEGER NOT NULL,
            is_admin INTEGER NOT NULL DEFAULT 0,
            admin_id TEXT
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
        await db.execute('''
          CREATE TABLE seen_msgs (
            hash TEXT PRIMARY KEY,
            ts INTEGER NOT NULL
          )
        ''');
        await _signalTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 27) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS seen_msgs (
              hash TEXT PRIMARY KEY,
              ts INTEGER NOT NULL
            )
          ''');
        }
        if (oldV < 26) {
          // message requests: existing contacts stay accepted (default 1),
          // only new unknown senders arrive unaccepted.
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN accepted INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldV < 25) {
          await db.execute('ALTER TABLE groups ADD COLUMN admin_id TEXT');
        }
        if (oldV < 24) {
          await db.execute('ALTER TABLE groups ADD COLUMN description TEXT');
        }
        if (oldV < 23) {
          await db.execute('ALTER TABLE messages ADD COLUMN preview TEXT');
        }
        if (oldV < 22) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN voice_disguised INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE messages ADD COLUMN saved INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 21) {
          await db.execute('ALTER TABLE messages ADD COLUMN file_path TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN file_name TEXT');
        }
        if (oldV < 20) {
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN key_changed INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 19) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN sent INTEGER NOT NULL DEFAULT 1',
          );
        }
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
        if (oldV < 16) {
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN unread INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldV < 17) {
          await db.execute('ALTER TABLE contacts ADD COLUMN atmosphere TEXT');
        }
        if (oldV < 18) {
          await db.execute('ALTER TABLE contacts ADD COLUMN note TEXT');
          await db.execute(
            'ALTER TABLE contacts ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
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

  Future<void> setNote(String haloId, String note) async {
    final db = await open();
    await db.update(
      'contacts',
      {'note': note},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> setContactPinned(String haloId, bool pinned) async {
    final db = await open();
    await db.update(
      'contacts',
      {'pinned': pinned ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
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

  Future<bool> keyChanged(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['key_changed'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['key_changed'] as int? ?? 0) == 1;
  }

  // flag that a known peer's identity key changed (reinstall or mitm).
  // the chat surfaces this so the user verifies before trusting.
  Future<void> setKeyChanged(String haloId, bool changed) async {
    final db = await open();
    await db.update(
      'contacts',
      {'key_changed': changed ? 1 : 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<void> clearKeyChanged(String haloId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'key_changed': 0},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  Future<List<Map<String, Object?>>> contacts() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 1',
      orderBy: 'last_seen DESC',
    );
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

  // true only when we've accepted this sender. unknown senders read false.
  Future<bool> isAccepted(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['accepted'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['accepted'] as int? ?? 0) == 1;
  }

  // how many messages we already hold from a sender - caps strangers.
  Future<int> countMessagesFrom(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM messages WHERE peer_id = ? AND direction = ?',
      [peerId, 'in'],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // how many messages we've sent a peer - caps our own request messages.
  Future<int> countMessagesTo(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM messages WHERE peer_id = ? AND direction = ?',
      [peerId, 'out'],
    );
    return (r.first['c'] as int?) ?? 0;
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

  // unknown senders waiting for accept/block. blocked ones stay hidden.
  Future<List<Map<String, Object?>>> pendingRequests() async {
    final db = await open();
    return db.query(
      'contacts',
      where: 'accepted = 0 AND blocked = 0',
      orderBy: 'last_seen DESC',
    );
  }

  Future<int> pendingRequestCount() async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE accepted = 0 AND blocked = 0',
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // accept a request: the stranger becomes a normal contact.
  Future<void> acceptRequest(String haloId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'accepted': 1},
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
  }

  // quietly dismiss a request: drop the stranger's row and pending messages.
  // not a block - they can reach us again later.
  Future<void> declineRequest(String haloId) async {
    final db = await open();
    await db.delete('contacts', where: 'halo_id = ?', whereArgs: [haloId]);
    await db.delete('messages', where: 'peer_id = ?', whereArgs: [haloId]);
  }

  Future<void> upsertContact(
    String haloId,
    String onion,
    String xpub, {
    int accepted = 1,
  }) async {
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
        'accepted': accepted,
      });
    } else {
      // xpub changed on someone we already know = they reinstalled, or its a
      // mitm. dont just swap the key silently, flag it so the chat warns
      final priorX = existing.first['xpub'] as String?;
      final changed =
          priorX != null &&
          priorX.isNotEmpty &&
          xpub.isNotEmpty &&
          priorX != xpub;
      await db.update(
        'contacts',
        {
          'onion': onion,
          'xpub': xpub,
          'last_seen': now,
          if (changed) 'key_changed': 1,
          if (changed) 'verified': 0,
        },
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
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
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
      'file_path': filePath,
      'file_name': fileName,
      'voice_disguised': voiceDisguised ? 1 : 0,
      'preview': preview,
      'saved': saved ? 1 : 0,
      'sent': sent,
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

  // dedup: skip a message we've already handled. duplicates arrive because
  // tor times out and the same msg comes via nostr too (plus retries). the
  // first copy sets up the session; a duplicate crashes on the used-up
  // prekey, so drop it before any decrypt.
  Future<bool> alreadySeen(String hash) async {
    final db = await open();
    final rows = await db.query(
      'seen_msgs',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markSeen(String hash) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // prune anything older than a day so the table stays tiny
    await db.delete('seen_msgs', where: 'ts < ?', whereArgs: [now - 86400000]);
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

  Future<void> markBackPaired(String peerId) async {
    final d = await open();
    await d.update(
      'contacts',
      {'back_paired': 1},
      where: 'halo_id = ?',
      whereArgs: [peerId],
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
    String? adminId,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': isAdmin ? 1 : 0,
      'admin_id': adminId,
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

  // the group creator/admin halo id. used to verify a roster self-heal
  // really came from the admin, not a member spoofing membership changes.
  Future<String?> groupAdminId(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['admin_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['admin_id'] as String?;
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

  // replace the whole member set for a group with the authoritative list.
  // used when a create/reconcile control arrives so a re-add or membership
  // change syncs cleanly instead of leaving stale or missing rows.
  Future<void> syncGroupMembers(String groupId, List<String> members) async {
    final db = await open();
    final batch = db.batch();
    batch.delete('group_members', where: 'group_id = ?', whereArgs: [groupId]);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final h in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': h,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
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
      columns: ['*', 'rowid'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sent_at ASC',
    );
  }

  // group messages newer than a rowid, for the append-fast-path (mirrors
  // messagesAfter but scoped to a group).
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: 'group_id = ? AND rowid > ?',
      whereArgs: [groupId, afterRowid],
      orderBy: 'sent_at ASC',
    );
  }

  // add or replace a reaction. reactor is '' for self, peer's halo id
  // for theirs. one reaction per (msgUid, reactor) - re-reacting replaces.
  Future<void> setPinned(String msgUid, bool pinned) async {
    final db = await open();
    await db.update(
      'messages',
      {'pinned': pinned ? 1 : 0},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> setSaved(String msgUid, bool saved) async {
    final db = await open();
    await db.update(
      'messages',
      {'saved': saved ? 1 : 0},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // every saved message across all chats, newest first. peer_id rides along
  // so the saved screen can show who it's from.
  Future<List<Map<String, Object?>>> savedMessages() async {
    final db = await open();
    return db.query('messages', where: 'saved = 1', orderBy: 'sent_at DESC');
  }

  // kill the jpgs too, not just the rows. otherwise a burned photo is still
  // sitting on disk
  Future<void> _scrubMedia(List<Map<String, Object?>> rows) async {
    for (final r in rows) {
      final mp = r['media_path'] as String?;
      if (mp != null && mp.isNotEmpty) {
        try {
          final f = File(mp);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> deleteMessage(String msgUid) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
    await _scrubMedia(media);
  }

  Future<void> purgeExpiredBurns() async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'messages',
      columns: ['msg_uid'],
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
      }
    }
    await db.delete(
      'messages',
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    await _scrubMedia(rows);
  }

  Future<void> bumpUnread(String peerId) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE contacts SET unread = unread + 1 WHERE halo_id = ?',
      [peerId],
    );
  }

  Future<void> clearUnread(String peerId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'unread': 0},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<void> setAtmosphere(String peerId, String atmosphere) async {
    final db = await open();
    await db.update(
      'contacts',
      {'atmosphere': atmosphere},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<String?> getAtmosphere(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['atmosphere'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['atmosphere'] as String?;
  }

  Future<void> clearConversation(String peerId) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
    );
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE peer_id = ? AND msg_uid IS NOT NULL)',
      [peerId],
    );
    await db.delete('messages', where: 'peer_id = ?', whereArgs: [peerId]);
    await _scrubMedia(media);
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

  Future<bool> messageExists(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['rowid'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> getMsgPreview(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['preview'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['preview'] as String?;
  }

  Future<int> setMsgPreview(String msgUid, String previewJson) async {
    final db = await open();
    return db.update(
      'messages',
      {'preview': previewJson},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<void> setMsgBurnAt(String msgUid, int burnAt) async {
    final db = await open();
    await db.update(
      'messages',
      {'burn_at': burnAt},
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final media = await db.query(
      'messages',
      columns: ['media_path'],
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    final n = await db.delete(
      'messages',
      where: 'burn_at IS NOT NULL AND burn_at < ?',
      whereArgs: [now],
    );
    await _scrubMedia(media);
    return n;
  }

  Future<void> markSent(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': 1},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      // group_id IS NULL keeps group messages out of the 1:1 thread - a group
      // row carries peer_id = sender AND a group_id, so without this it leaked
      // into the direct chat with that sender.
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: 'sent_at ASC',
    );
  }

  // newest page of a 1:1 thread. beforeRowid pages older on scroll-up so a
  // 5000-message chat doesn't parse the world on open.
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int limit = 60,
  }) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: beforeRowid == null
          ? 'peer_id = ? AND group_id IS NULL'
          : 'peer_id = ? AND group_id IS NULL AND rowid < ?',
      whereArgs: beforeRowid == null ? [peerId] : [peerId, beforeRowid],
      orderBy: 'rowid DESC',
      limit: limit,
    );
    return rows.reversed.toList();
  }

  // only messages newer than a timestamp, oldest-first. used by the chat's
  // append-on-receive fast path so a live message doesn't reload the world.
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async {
    final db = await open();
    // key off rowid (insertion order), not sent_at - a received note can carry
    // a sent_at older than our local newest (clock skew) and would be missed by
    // a timestamp filter. rowid always climbs as rows are saved.
    return db.query(
      'messages',
      columns: ['*', 'rowid'],
      where: "peer_id = ? AND group_id IS NULL AND rowid > ?",
      whereArgs: [peerId, afterRowid],
      orderBy: 'rowid ASC',
    );
  }

  // newest message for a peer (or null) - drives the home-list preview and
  // ordering without loading the whole conversation.
  Future<Map<String, Object?>?> lastMessageFor(String peerId) async {
    final db = await open();
    // order by rowid (insertion order), not sent_at - a received note can carry
    // a sent_at older than our local newest (clock skew between phones) and
    // would otherwise never surface as the latest. rowid always climbs.
    final rows = await db.query(
      'messages',
      where: 'peer_id = ?',
      whereArgs: [peerId],
      orderBy: 'rowid DESC',
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

// overwrite a byte buffer with zeros - best-effort wipe of key/plaintext
// material from ram. dart strings cant be wiped (immutable+gc), only lists.
void _zeroBytes(List<int> b) {
  for (var i = 0; i < b.length; i++) {
    b[i] = 0;
  }
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

Future<String?> signalDecrypt(
  String peerId,
  String wireB64, {
  bool flagKeyChange = false,
}) async {
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
      final pkm = PreKeySignalMessage(body);
      if (await signalSession.sessionStore.containsSession(addr)) {
        // session exists - use it. rebuilding from the prekey record here is
        // wrong when the slot was refilled with a fresh key (old bundle refs
        // would bad-mac the rebuilt session).
        try {
          plain = await cipher.decryptFromSignal(pkm.getWhisperMessage());
        } catch (e) {
          debugPrint(
            'signalDecrypt: session path failed ($e), prekey fallback',
          );
          plain = await cipher.decrypt(pkm);
        }
      } else {
        final pkId = pkm.getPreKeyId();
        final havePk =
            !pkId.isPresent ||
            await signalSession.preKeyStore.containsPreKey(pkId.value);
        if (!havePk) {
          debugPrint('signalDecrypt: prekey gone, no session for $peerId');
          return null;
        }
        plain = await cipher.decrypt(pkm);
      }
    } else {
      plain = await cipher.decryptFromSignal(
        SignalMessage.fromSerialized(body),
      );
    }
    final text = utf8.decode(plain);
    _zeroBytes(plain); // cleartext decoded out, wipe the raw buffer
    return text;
  } on DuplicateMessageException catch (_) {
    debugPrint('signalDecrypt: duplicate from $peerId, dropped');
    // store-and-forward re-delivers messages - a duplicate is expected and
    // benign. the original already decrypted, so drop this one quietly.
    return null;
  } on UntrustedIdentityException catch (_) {
    // known peer's identity key no longer matches - reinstall or mitm.
    // only flag when the caller knows this cipher was really for this peer
    // (targeted decrypt). trial-decrypt callers pass flagKeyChange:false so a
    // normal no-match against the wrong contact never sets the flag.
    if (flagKeyChange) {
      await db.setKeyChanged(peerId, true);
      appState.notifyListeners();
    }
    return null;
  } on InvalidKeyIdException catch (_) {
    // one-time prekey already used up. if a session with this peer
    // exists, an earlier copy set it up (tor+nostr both delivered, or a
    // retry) so this is a duplicate - drop quietly. no session = can't
    // read this one.
    final addr = SignalProtocolAddress(peerId, 1);
    if (await signalSession.sessionStore.containsSession(addr)) {
      return null;
    }
    return null;
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

Future<String> saveFileBytes(List<int> bytes, String uid, String name) async {
  final dir = await getApplicationDocumentsDirectory();
  final mediaDir = Directory('${dir.path}/media');
  if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${mediaDir.path}/f_${uid}_$safe');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<String> saveMediaBytes(List<int> bytes, String name) async {
  final dir = await getApplicationDocumentsDirectory();
  final mediaDir = Directory('${dir.path}/media');
  if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${mediaDir.path}/$safe.jpg');
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
// (both warm - onDidReceiveNotificationResponse - and cold starts
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
  if (haloId == currentChatPeer) return;
  nav.push(
    haloRoute(
      ChatScreen(
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
  // uids being processed right now, to dedup near-simultaneous arrivals
  // (preview re-send racing a manual retry) before the db write lands.
  final Set<String> _inflightUids = <String>{};
  // incoming media chunks buffered by mediaId until all arrive, then
  // reassembled into the full base64. single-chunk media skips this.
  final Map<String, Map<int, String>> _mediaChunks = {};
  // global send-privacy mode: 'fast' | 'normal' | 'private'. cosmetic for now -
  // every message routes over full tor until fast/hop modes wire up (phase 2).
  String _sendMode = 'private';
  String get sendMode => _sendMode;

  Future<void> saveGhostPref(bool on, int secs) async {
    const s = FlutterSecureStorage();
    await s.write(key: 'ghost_on', value: on ? '1' : '0');
    await s.write(key: 'ghost_secs', value: '$secs');
  }

  Future<(bool, int)> loadGhostPref() async {
    const s = FlutterSecureStorage();
    final on = (await s.read(key: 'ghost_on')) == '1';
    final secs = int.tryParse(await s.read(key: 'ghost_secs') ?? '') ?? 300;
    return (on, secs);
  }

  Future<bool> loadDisguisePref() async {
    const s = FlutterSecureStorage();
    return (await s.read(key: 'disguise_on')) == '1';
  }

  Future<void> saveDisguisePref(bool on) async {
    const s = FlutterSecureStorage();
    await s.write(key: 'disguise_on', value: on ? '1' : '0');
  }

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

  String _displayName = '';
  String get displayName => _displayName;
  Future<void> loadDisplayName() async {
    _displayName =
        await const FlutterSecureStorage().read(key: 'display_name') ?? '';
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    notifyListeners();
    await const FlutterSecureStorage().write(key: 'display_name', value: name);
  }

  static const _platformChannel = MethodChannel('halo/platform');
  bool _blockScreenshots = false;
  bool get blockScreenshots => _blockScreenshots;
  Future<void> loadScreenshotPref() async {
    _blockScreenshots =
        (await const FlutterSecureStorage().read(key: 'block_screenshots')) ==
        'true';
    await _applyScreenSecure();
    notifyListeners();
  }

  Future<void> setBlockScreenshots(bool v) async {
    _blockScreenshots = v;
    notifyListeners();
    await const FlutterSecureStorage().write(
      key: 'block_screenshots',
      value: v.toString(),
    );
    await _applyScreenSecure();
  }

  Future<void> loadThemePref() async {
    try {
      final v =
          (await const FlutterSecureStorage().read(key: 'theme_light')) ==
          'true';
      HaloColors.setLight(v);
    } catch (_) {}
  }

  Future<void> setLight(bool v) async {
    HaloColors.setLight(v);
    themeRevision.value++;
    notifyListeners();
    await const FlutterSecureStorage().write(
      key: 'theme_light',
      value: v.toString(),
    );
  }

  Future<void> _applyScreenSecure() async {
    try {
      await _platformChannel.invokeMethod('setSecure', {
        'on': _blockScreenshots,
      });
    } catch (_) {}
  }

  NtfyListener? _ntfyListener;

  Future<void> applyPushMode(PushMode m) async {
    await savePushMode(m);
    if (m == PushMode.ntfy) {
      _ntfyListener ??= NtfyListener(
        onPing: () {},
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
  //   3) data message   (1:1 or group - save + maybe notify)
  // called from all three receive paths (back-pair-from-cipher, tor drain,
  // nostr poll) so the routing rules live in exactly one place.
  Future<void> _applyIncomingPayload(
    String senderHaloId,
    UnwrappedMessage env,
  ) async {
    _bumpChatRev(senderHaloId);
    await db.markBackPaired(senderHaloId);
    debugPrint(
      'INCOMING len=${env.message.length} hasPreview=${env.preview != null} uid=${env.msgUid}',
    );
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
    // 2.5) edit - swap the text of an existing message
    if (env.edit != null) {
      await db.editMessage(env.edit!.targetUid, env.edit!.newText);
      return;
    }
    // 2.6) unsend - sender recalled a message; delete our copy
    if (env.unsend != null) {
      await db.deleteMessage(env.unsend!);
      // refresh so it vanishes live if the peer's looking at the chat now,
      // not only after they leave and come back.
      notifyListeners();
      return;
    }
    // 3) data message - could be 1:1 or group
    final isGroup = env.groupId != null;
    if (isGroup && !await db.groupExists(env.groupId!)) {
      // unknown group - drop. prevents random senders from injecting rows
      // into groups we never joined.
      debugPrint('dropping group msg for unknown group ${env.groupId}');
      return;
    }
    // roster self-heal: if the admin rode their full member list on this
    // message and our copy drifted, reconcile. only trust it from the real
    // admin so a member can't rewrite membership by spoofing a roster.
    if (isGroup && env.roster != null) {
      final adminId = await db.groupAdminId(env.groupId!);
      if (adminId != null && senderHaloId == adminId) {
        await db.syncGroupMembers(env.groupId!, env.roster!);
        // create contact stubs for self-healed members so we can actually
        // encrypt to them - ids alone aren't enough, we need their keys.
        if (env.rosterParticipants != null) {
          for (final p in env.rosterParticipants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null && o != null && x != null && h != myId) {
              await db.upsertContactStub(h, o, x);
            }
          }
          await refreshContacts();
        }
      }
    }
    // stranger lock + proof-of-work gate (1:1 only, unaccepted senders).
    if (!isGroup && !await db.isAccepted(senderHaloId)) {
      // pow: first-contact messages must carry a valid nonce. drop silently if
      // missing/weak - the spammer learns nothing, and this runs before media
      // decode so a bad sender can't burn our cpu on an attachment we'll toss.
      if (env.powNonce == null ||
          !verifyPow(env.message, env.powNonce!, powBits)) {
        debugPrint(
          'pow: dropping first-contact from $senderHaloId (nonce=${env.powNonce} bits=${env.powBitsUsed})',
        );
        return;
      }
      // 2-message cap: a stranger gets 2 into requests, then the chat is locked
      // until we accept them. drop past the cap - no receipt.
      final have = await db.countMessagesFrom(senderHaloId);
      if (have >= 2) {
        debugPrint('stranger lock: dropping from $senderHaloId (cap hit)');
        return;
      }
    }
    // chunked media: a big image/file arrives as several envelopes sharing one
    // mediaId. buffer the slices until all chunkTotal are in, then rebuild the
    // full base64. single-chunk (or unchunked) media skips this entirely.
    String? imgB64 = env.imageB64;
    String? fileB64v = env.fileB64;
    if (env.mediaId != null && env.chunkTotal != null && env.chunkTotal! > 1) {
      final mid = env.mediaId!;
      final slot = _mediaChunks.putIfAbsent(mid, () => <int, String>{});
      final slice = (env.imageB64 ?? env.fileB64) ?? '';
      slot[env.chunkIndex ?? 0] = slice;
      if (slot.length < env.chunkTotal!) {
        // still waiting on more pieces - nothing to show yet.
        return;
      }
      // all pieces in: stitch them back in index order.
      final full = StringBuffer();
      for (var i = 0; i < env.chunkTotal!; i++) {
        full.write(slot[i] ?? '');
      }
      _mediaChunks.remove(mid);
      // preview thumbnail: reassembled chunks patch onto the card of the
      // message with this uid, not a new media bubble. update + refresh, done.
      if (env.pvImg && env.msgUid != null) {
        final existing = await db.getMsgPreview(env.msgUid!);
        final pv = existing != null
            ? Map<String, String>.from(jsonDecode(existing) as Map)
            : <String, String>{};
        pv['img'] = full.toString();
        await db.setMsgPreview(env.msgUid!, jsonEncode(pv));
        await refreshContacts();
        return;
      }
      // which field it belonged to: file if a name was sent, else image.
      if (env.fileName != null) {
        fileB64v = full.toString();
      } else {
        imgB64 = full.toString();
      }
    }
    String? mediaPath;
    if (imgB64 != null && imgB64.isNotEmpty) {
      try {
        mediaPath = await saveMediaBytes(
          base64Decode(imgB64),
          env.msgUid ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } catch (_) {}
    }
    String? filePath;
    final fileName = env.fileName;
    if (fileB64v != null && fileB64v.isNotEmpty) {
      try {
        filePath = await saveFileBytes(
          base64Decode(fileB64v),
          env.msgUid ?? DateTime.now().millisecondsSinceEpoch.toString(),
          fileName ?? 'file',
        );
      } catch (_) {}
    }
    // dedup: a message can arrive twice - the original, then the preview re-send
    // (option A), and sometimes a manual retry too. the db check alone races when
    // two copies arrive in the same instant (both pass before either saves), so
    // we also hold an in-memory set of uids currently being processed. first one
    // in claims the uid; any twin takes the update path instead of inserting.
    final uid = env.msgUid;
    if (uid != null) {
      final known = _inflightUids.contains(uid) || await db.messageExists(uid);
      if (known) {
        if (env.preview != null) {
          await db.setMsgPreview(uid, jsonEncode(env.preview));
        }
        notifyListeners();
        return;
      }
      _inflightUids.add(uid);
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
      voiceDisguised: env.voiceDisguised,
      mediaPath: mediaPath,
      filePath: filePath,
      fileName: fileName,
      preview: env.preview != null ? jsonEncode(env.preview) : null,
    );
    // notification context - for groups, title = group name and body
    // prefixes the sender. payload uses "group:<id>" so tap-to-open can
    // route to the right screen.
    if (!isGroup && currentChatPeer != senderHaloId) {
      await db.bumpUnread(senderHaloId);
    } else if (!isGroup && currentChatPeer == senderHaloId) {
      // already reading this chat - clear any stale badge instead of leaving it.
      await db.clearUnread(senderHaloId);
    }
    // a message landed: rebuild the contact list so the home shows the
    // new preview, time and unread dot without needing the chat opened.
    await refreshContacts();
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
          : (fileName != null
                ? fileName
                : (mediaPath != null ? 'photo' : env.message));
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
          await db.createGroup(
            groupId,
            gc.name!,
            gc.members!,
            isAdmin: false,
            adminId: senderHaloId,
          );
        } else {
          // already in the group - reconcile the member list so a re-add or
          // membership change syncs instead of leaving a stale count.
          await db.syncGroupMembers(groupId, gc.members!);
          await db.renameGroup(groupId, gc.name!);
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
          // removed person drops the whole group locally so it leaves
          // their list and they stop multicasting into it.
          if (h == myId) await db.deleteGroup(groupId);
        }
        await refreshGroups();
        break;
      case 'rename':
        if (gc.name == null) return;
        await db.renameGroup(groupId, gc.name!);
        await refreshGroups();
        break;
      case 'leave':
        await db.removeGroupMember(groupId, senderHaloId);
        await refreshGroups();
        break;
    }
  }

  Future<void> applyNtfyServerChange(String url) async {
    await saveNtfyServer(url);
    if (_ntfyListener != null) {
      await _ntfyListener!.stop();
      _ntfyListener = NtfyListener(
        onPing: () {},
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
  // live tor state; the home halo breathes off this.
  // bumped whenever something changes for a peer's thread. open chats
  // compare against this instead of reloading on every notify.
  final Map<String, int> _chatRev = {};
  int chatRevOf(String haloId) => _chatRev[haloId] ?? 0;
  void _bumpChatRev(String haloId) {
    _chatRev[haloId] = (_chatRev[haloId] ?? 0) + 1;
  }

  bool _draining = false;
  bool _polling = false;
  TorStatus _torStatus = TorStatus.off;
  int _bootstrapPct = 0;
  TorStatus get torStatus => _torStatus;
  int get bootstrapPct => _bootstrapPct;
  bool _online = true;
  bool get online => _online;
  List<ContactPreview> contacts = [];
  int pendingCount = 0;
  final Map<String, String> _xPubToHaloId = {};

  // when an unknown sender's PreKey message arrives via
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
        debugPrint('back-pair: HaloID mismatch');
        return null;
      }
      // move session from temp to real HaloID
      final record = await signalSession.sessionStore.loadSession(tempAddr);
      final realAddr = SignalProtocolAddress(h, 1);
      await signalSession.sessionStore.storeSession(realAddr, record);
      await signalSession.sessionStore.deleteSession(tempAddr);
      // persist contact + nostr sub. a stranger who back-paired to us lands
      // unaccepted - their message waits in requests until we accept.
      await db.upsertContact(
        h,
        env.senderOnion ?? '',
        env.senderXPub ?? '',
        accepted: 0,
      );
      if (env.senderXPub != null && env.senderXPub!.isNotEmpty) {
        _xPubToHaloId[env.senderXPub!] = h;
        engine.nostrSubscribeBg(env.senderXPub!);
      }
      if (env.endpoint != null) {
        await savePeerEndpoint(h, env.endpoint!);
      }
      await _applyIncomingPayload(h, env);
      await refreshContacts();
      notifyListeners();
      debugPrint('back-pair: created contact via direct onion');
      return h;
    } catch (e) {
      debugPrint('back-pair error: $e');
      try {
        await signalSession.sessionStore.deleteSession(tempAddr);
      } catch (_) {}
      return null;
    }
  }

  Future<Map<String, String>> _loadXPubCache() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: 'xpub_cache');
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveXPubCache(Map<String, String> cache) async {
    try {
      await const FlutterSecureStorage().write(
        key: 'xpub_cache',
        value: jsonEncode(cache),
      );
    } catch (_) {}
  }

  Future<void> boot() async {
    final _bsw = Stopwatch()..start();
    if (ready) return;
    // let the splash paint one frame before any heavy native call. sqlcipher
    // key derivation + the first go ffi hop block the ui thread long enough
    // that android's anr watchdog fired on weak phones during cold start.
    await Future.delayed(const Duration(milliseconds: 16));
    final docsDir = await getApplicationDocumentsDirectory();
    final saved = await db.loadIdentity();
    if (saved != null) {
      myId = engine.restoreIdentity(saved['ed_priv']!, saved['x_priv']!);
      restored = true;
    } else {
      myId = engine.generateIdentity();
      await db.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    }
    myXPub = engine.myXPubkey();
    debugPrint('BOOT identity +${_bsw.elapsedMilliseconds}ms');
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
    debugPrint('BOOT contacts +${_bsw.elapsedMilliseconds}ms');
    await refreshGroups();
    debugPrint('BOOT groups +${_bsw.elapsedMilliseconds}ms');
    // paint the home as soon as contacts/groups are ready; notifications,
    // nostr subscriptions and ntfy keep warming up in the background.
    onboardingComplete =
        (await const FlutterSecureStorage().read(key: 'onboarding_done')) ==
        'true';
    // let the onion linger a beat before the home appears
    if (onboardingComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    ready = true;
    debugPrint('BOOT ready +${_bsw.elapsedMilliseconds}ms');
    notifyListeners();
    // signal prekey gen is cpu-heavy (~5s on a fresh identity) and nothing
    // above needs it - defer it so the home paints first. tor + nostr also
    // start after this, and both take longer to warm than the prekeys, so
    // the session is ready well before any message can arrive.
    _bootSignal().then((_) => debugPrint('BOOT signal (deferred) done'));
    // start tor last, after all sync identity + signal work. nothing
    // above needs it, and starting it earlier stalled the main thread
    // while tor bootstrapped.
    _startListenerOnIsolate(docsDir.path).then((addr) {
      if (addr.isNotEmpty && !addr.startsWith('error')) {
        myOnion = addr;
        notifyListeners();
      }
    });
    // poll bootstrap so the halo can breathe while the listener warms up.
    Timer.periodic(const Duration(seconds: 1), (t) {
      final raw = engine.getStatus();
      final st = parseTorStatus(raw);
      final pct = parseBootstrapPct(raw);
      if (st != _torStatus || pct != _bootstrapPct) {
        _torStatus = st;
        _bootstrapPct = pct;
        notifyListeners();
      }
      if (st == TorStatus.reachable) t.cancel();
    });
    _initConnectivity();
    _nostrInitOnIsolate('wss://relay.damus.io,wss://nos.lol');
    await loadDisplayName();
    await loadScreenshotPref();
    await initNotifications(onTap: openChatForHalo);

    // periodic sweep: delete messages whose burn_at has passed.
    Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await db.purgeExpired();
      } catch (_) {}
    });
    // warm up signal sessions + nostr subs after the first frame. a cached
    // xpub→haloId map (encrypted) lets returning users skip the per-contact
    // crypto entirely; only uncached contacts hit the heavy lookup.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      final currentIds = {for (final c in contacts) c.haloId};
      final cache = await _loadXPubCache();
      final knownIds = <String>{};
      final fresh = <String, String>{};
      var changed = false;
      cache.forEach((xPub, haloId) {
        if (!currentIds.contains(haloId)) {
          changed = true;
          return;
        }
        fresh[xPub] = haloId;
        _xPubToHaloId[xPub] = haloId;
        engine.nostrSubscribeBg(xPub);
        knownIds.add(haloId);
      });
      for (final c in contacts) {
        if (knownIds.contains(c.haloId)) continue;
        await Future.delayed(Duration.zero);
        final xPub = await signalSession.peerXPubHex(c.haloId);
        if (xPub != null) {
          _xPubToHaloId[xPub] = c.haloId;
          engine.nostrSubscribeBg(xPub);
          fresh[xPub] = c.haloId;
          knownIds.add(c.haloId);
          changed = true;
        }
      }
      if (changed) await _saveXPubCache(fresh);
    });
    // open ntfy websocket when push mode is ntfy. on incoming
    // ping, the existing 1s drain loop catches up - we just log for now.
    final mode = await loadPushMode();
    if (mode == PushMode.ntfy) {
      _ntfyListener = NtfyListener(onPing: () {}, log: (m) => debugPrint(m));
      _ntfyListener!.start();
    }

    // continuous drain of direct-onion inbox. handles back-
    // pair from strangers + falls back to trial-decrypt against known
    // contacts for in-session direct-onion messages.
    Timer.periodic(const Duration(seconds: 1), (_) async {
      // reentrancy guard: the ffi drain + decrypt can outrun the 1s tick
      // while tor is still warming, and stacked calls pinned the main
      // thread hard enough to anr on weak phones. skip if one's running.
      if (_torStatus != TorStatus.reachable) return;
      if (_draining) return;
      _draining = true;
      try {
        final ciphers = engine.drainInbox();
        if (ciphers.isEmpty) return;
        for (final cipher in ciphers) {
          // dedup: same msg can arrive twice (tor late + nostr, or a retry).
          // the first copy consumes the one-time prekey; a duplicate would
          // crash on it, so skip anything we've already handled.
          final h = sha256.convert(utf8.encode(cipher)).toString();
          if (await db.alreadySeen(h)) continue;
          await db.markSeen(h);
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
          if (!handled) {
            // request contacts sit outside the accepted list - try them before
            // treating this as a brand new stranger.
            for (final r in await db.pendingRequests()) {
              final id = r['halo_id'] as String;
              final plain = await signalDecrypt(id, cipher);
              if (plain != null) {
                final env = unwrapMessage(plain);
                await _applyIncomingPayload(id, env);
                notifyListeners();
                handled = true;
                break;
              }
            }
          }
          if (!handled) {
            await backPairFromCipher(cipher);
          }
        }
      } finally {
        _draining = false;
      }
    });

    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_torStatus != TorStatus.reachable) return;
      if (_polling) return;
      _polling = true;
      try {
        final msgs = engine.nostrPoll();
        if (msgs.isEmpty) return;
        for (final m in msgs) {
          // dedup: skip a message we've already handled (see direct-onion note).
          final h = sha256.convert(utf8.encode(m.cipher)).toString();
          if (await db.alreadySeen(h)) continue;
          await db.markSeen(h);
          var haloId = _xPubToHaloId[m.peer];
          String? wrapped = haloId == null
              ? null
              : await signalDecrypt(haloId, m.cipher, flagKeyChange: true);
          // fallback: xpub not mapped yet (or it decrypted wrong) - trial
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
            for (final r in await db.pendingRequests()) {
              final id = r['halo_id'] as String;
              final p = await signalDecrypt(id, m.cipher);
              if (p != null) {
                wrapped = p;
                haloId = id;
                _xPubToHaloId[m.peer] = id;
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
      } finally {
        _polling = false;
      }
    });
    final _stored = await const FlutterSecureStorage().read(
      key: 'onboarding_done',
    );
    onboardingComplete = _stored == 'true';
    ready = true;
    notifyListeners();
  }

  Future<void> _initConnectivity() async {
    try {
      final init = await Connectivity().checkConnectivity();
      _online = init.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    } catch (_) {}
    Connectivity().onConnectivityChanged.listen((results) {
      final on = results.any((r) => r != ConnectivityResult.none);
      if (on != _online) {
        _online = on;
        notifyListeners();
      }
    });
  }

  Future<void> _bootSignal() async {
    try {
      final database = await db.open();
      final xpb = _hexDecode(engine.myXPrivkey());
      await signalSession.bootstrap(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb); // priv bytes consumed by bootstrap, wipe from ram
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
        final fileName = last['file_name'] as String?;
        String body;
        if (text.isNotEmpty) {
          body = text;
        } else if (fileName == 'voice.wav') {
          body = 'voice message';
        } else if (fileName != null) {
          body = fileName;
        } else if (media != null) {
          body = 'photo';
        } else {
          body = '';
        }
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
          muted: (r['muted'] as int? ?? 0) == 1,
          verified: (r['verified'] as int? ?? 0) == 1,
          unread: (r['unread'] as int? ?? 0),
          pinned: (r['pinned'] as int? ?? 0) == 1,
        ),
      );
    }
    // most-recent conversation floats to the top
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.when ?? DateTime(0)).compareTo(a.when ?? DateTime(0));
    });
    contacts = list;
    pendingCount = await db.pendingRequestCount();
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
        debugPrint('send: no contact for $memberId');
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
        debugPrint('send: tor direct failed ($tor), trying nostr');
      }
      final n = await Future(() => engine.nostrSend(xpub, cipher));
      if (n == 'ok') return true;
      debugPrint('send: nostr also failed ($n)');
      return false;
    } catch (e) {
      debugPrint('send to $memberId failed: $e');
      return false;
    }
  }

  // tells a just-accepted stranger they're in. the empty frame flips their
  // back_paired on arrival, which melts their request lock without waiting
  // for our first reply.
  Future<void> sendAcceptAck(String haloId) async {
    try {
      final wrapped = await wrapMessage('', sender: _mySender());
      await _sendOneEnvelope(haloId, wrapped);
    } catch (e) {
      debugPrint('accept ack failed: $e');
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
    final members = await db.getGroupMembers(groupId);
    // if we are the group admin, ride the full roster on the message so any
    // member whose list drifted self-heals the moment they receive it.
    final adminId = await db.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // ride the member key bundles too, not just ids - a self-healed member the
    // receiver had no contact for would otherwise throw InvalidKeyException on
    // encrypt. participants let the receiver upsert a stub and encrypt to them.
    final rosterParts = amAdmin ? await _buildParticipants(members) : null;
    final wrapped = await wrapMessage(
      plain,
      msgUid: msgUid,
      replyTo: replyTo,
      burnSeconds: burnSeconds,
      groupId: groupId,
      roster: amAdmin ? members : null,
      rosterParticipants: rosterParts,
      sender: _mySender(),
    );
    debugPrint(
      'GRPSEND group=$groupId members=$members me=$myId admin=$amAdmin',
    );
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
    await db.createGroup(groupId, name, full, isAdmin: true, adminId: myId);
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
      engine.nostrSubscribeBg(xPub);
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
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await appState.loadThemePref();
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

final themeRevision = ValueNotifier<int>(0);

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeRevision,
      builder: (context, _, __) => MaterialApp(
        navigatorKey: rootNavKey,
        title: 'Halo',
        theme: buildHaloTheme(),
        home: _LockGate(child: _OnboardingGate(child: RootShell())),
      ),
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
    // boot after the first frame is on screen. loading libhalo.so pulls in the
    // whole go runtime + embedded tor and blocks briefly; doing it before the
    // first paint let android's anr watchdog kill a cold start on weak phones.
    WidgetsBinding.instance.addPostFrameCallback((_) => appState.boot());
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    appState.removeListener(_onChange);
    super.dispose();
  }

  void _open(Widget w) {
    Navigator.push(context, haloRoute(w));
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.ready) {
      return Scaffold(
        backgroundColor: HaloColors.surface,
        body: Center(
          child: Text(
            appState.onboardingComplete
                ? 'booting...'
                : 'setting up your identity...',
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ),
      );
    }
    return HomeScreen(
      haloId: appState.myId,
      contacts: appState.contacts,
      pendingCount: appState.pendingCount,
      groups: appState.groups
          .map(
            (g) => GroupSummary(
              groupId: g.groupId,
              name: g.name,
              memberCount: g.memberCount,
            ),
          )
          .toList(),
      onAddContact: () => showAddContact(context),
      onNewGroup: () => _open(const NewGroupScreen()),
      onOpenDev: () => _open(const DevScreen()),
      onOpenSettings: () => _open(const ProfileScreen()),
      onOpenSettingsDirect: () => _open(SettingsScreen()),
      onOpenChat: (id) async {
        final rows = await db.contacts();
        final matches = rows.where((r) => r['halo_id'] == id).toList();
        if (matches.isEmpty || !mounted) return;
        final row = matches.first;
        Navigator.push(
          context,
          haloRoute(
            ChatScreen(
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
        Navigator.push(context, haloRoute(GroupChatScreen(groupId: groupId)));
      },
    );
  }
}

Future<void> showAddContact(BuildContext context) async {
  final ctrl = TextEditingController();
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: HaloColors.surface2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        24 + MediaQuery.of(sheetCtx).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HaloColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'add a contact',
            style: HaloType.serif(
              size: 22,
              italic: true,
              color: HaloColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'scan their code in person, or paste an invite link',
            style: HaloType.sans(size: 12.5, color: HaloColors.text),
          ),
          const SizedBox(height: 14),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'scan'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33F59E0B),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 19,
                    color: HaloColors.onAmber,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'scan qr code',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: HaloColors.onAmber,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'mine'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2, size: 16, color: HaloColors.amber),
                const SizedBox(width: 7),
                Text(
                  'show my own code',
                  style: HaloType.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: HaloColors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: HaloColors.line, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'or paste a link',
                  style: HaloType.sans(size: 11, color: HaloColors.text2),
                ),
              ),
              Expanded(child: Divider(color: HaloColors.line, height: 1)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: HaloColors.surface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaloColors.line, width: 0.5),
            ),
            child: TextField(
              controller: ctrl,
              minLines: 1,
              maxLines: 3,
              style: HaloType.mono(size: 12, color: HaloColors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'halo://share?...',
                hintStyle: HaloType.mono(size: 12, color: HaloColors.text3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Pressable(
            onTap: () => Navigator.pop(sheetCtx, 'paste'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HaloColors.amber, width: 1),
              ),
              child: Center(
                child: Text(
                  'import from link',
                  style: HaloType.sans(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: HaloColors.amber,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
  if (action == null) return;
  if (action == 'mine') {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MyHaloScreen()));
    return;
  }

  String uri;
  if (action == 'scan') {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (result == null) return;
    uri = result;
  } else {
    uri = ctrl.text.trim();
    if (uri.isEmpty) return;
  }

  final status = await handleHaloUri(uri);
  await appState.refreshContacts();
  showHaloToast(context, status);
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  double _scale = 1;
  void _set(double v) {
    if (mounted) setState(() => _scale = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(0.96),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
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
    // must run off the ui thread - starting tor blocks on socket i/o long
    // enough that android anr'd the onboarding page. isolate twin already
    // used on the main boot path.
    final addr = await _startListenerOnIsolate(docsDir.path);
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
        setState(() {});
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
    if (!context.mounted) return;
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
                      icon: Icon(Icons.qr_code, color: HaloColors.amber),
                      label: const Text('show my qr'),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.content_paste, color: HaloColors.violet),
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

class TorHalo extends StatefulWidget {
  final bool label;
  const TorHalo({this.label = false});
  @override
  State<TorHalo> createState() => TorHaloState();
}

class TorHaloState extends State<TorHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  bool get _isConnecting {
    final s = appState.torStatus;
    return s == TorStatus.starting ||
        s == TorStatus.bootstrapped ||
        s == TorStatus.publishing;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    appState.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (_isConnecting && !_c.isAnimating) {
      _c.repeat();
    } else if (!_isConnecting && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    appState.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  void _explain() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final s = appState.torStatus;
          final pct = appState.bootstrapPct;
          final line = s == TorStatus.off
              ? 'tor is off'
              : s == TorStatus.reachable
              ? 'connected · routed through 3 relays'
              : s == TorStatus.publishing
              ? 'connecting · publishing your route'
              : 'connecting · $pct%';
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'tor',
                  style: HaloType.serif(
                    size: 20,
                    italic: true,
                    color: HaloColors.text,
                  ),
                ),
                const SizedBox(height: 16),
                TorWarmupGraph(status: s, bootstrapPct: pct),
                const SizedBox(height: 16),
                Text(
                  line,
                  style: HaloType.mono(size: 12, color: HaloColors.text),
                ),
                if (s != TorStatus.reachable) ...[
                  const SizedBox(height: 16),
                  Text(
                    s == TorStatus.off
                        ? 'tor is off. turn it on to connect privately.'
                        : 'the first connection takes a minute or two while tor builds a private route. after that it is cached, so opening halo later is much faster.',
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text,
                    ).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'a faster mode that skips tor (and reveals your ip) is coming soon.',
                    style: HaloType.sans(size: 11, color: HaloColors.text2),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ring(double size, Color color, double w) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: w),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _explain,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([appState, _c]),
        builder: (context, _) {
          final s = appState.torStatus;
          final off = s == TorStatus.off;
          final secured = s == TorStatus.reachable;
          final connecting = !off && !secured;
          const torGreen = Color(0xFF34D399);
          final accent = off
              ? HaloColors.text3
              : secured
              ? torGreen
              : HaloColors.amber;
          final t = _c.value;
          final dot = SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (connecting)
                  Transform.scale(
                    scale: 0.5 + t,
                    child: Opacity(
                      opacity: (1 - t) * 0.7,
                      child: _ring(12, HaloColors.amber, 1.4),
                    ),
                  ),
                _ring(
                  12,
                  off
                      ? HaloColors.text3.withValues(alpha: 0.4)
                      : accent.withValues(alpha: secured ? 1.0 : 0.85),
                  1.4,
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              ],
            ),
          );
          if (!widget.label) {
            return SizedBox(width: 20, height: 20, child: Center(child: dot));
          }
          final txt = off
              ? 'tor off'
              : secured
              ? 'connected'
              : 'connecting';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot,
              const SizedBox(width: 6),
              Text(txt, style: HaloType.mono(size: 11, color: accent)),
            ],
          );
        },
      ),
    );
  }
}
