// SPDX-License-Identifier: GPL-3.0-or-later
// backup.dart - full identity + db + prefs backup, encrypted with a
// user passphrase. one blob, restorable on any device. uses the engine
// for scrypt + aes-gcm (HaloEncryptBackup / HaloDecryptBackup).

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'main.dart' show TwoArgFn, TwoArgFnDart, engine, shredFile;
import 'dlog.dart';

const _kDbPassphrase = 'halo.db.passphrase';
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class BackupError implements Exception {
  final String message;
  BackupError(this.message);
  @override
  String toString() => message;
}

// the four things that can go wrong opening a backup, each with its own
// words. a code or a stack trace on someone's worst day helps nobody.
enum RestoreFailure { wrongPassphrase, notABackup, newerVersion, damaged }

class RestoreError implements Exception {
  final RestoreFailure why;
  const RestoreError(this.why);
  String get line => switch (why) {
    RestoreFailure.wrongPassphrase => 'That passphrase does not open this file',
    RestoreFailure.notABackup => 'That file is not a kryfo backup',
    RestoreFailure.newerVersion =>
      'This backup is from a newer kryfo. Update the app, then try again',
    RestoreFailure.damaged => 'This file is damaged and cannot be read',
  };
  @override
  String toString() => line;
}

// map what the engine says to one of the four. the engine reports a
// failed gcm auth as "wrong passphrase or corrupt", and a wrong
// passphrase is by far the ordinary way to get there.
RestoreFailure classifyRestoreError(String engineError) {
  final e = engineError.toLowerCase();
  if (e.contains('not a halo backup')) return RestoreFailure.notABackup;
  if (e.contains('wrong passphrase') || e.contains('gcm')) {
    return RestoreFailure.wrongPassphrase;
  }
  return RestoreFailure.damaged;
}

// what a backup file holds, read before anything is touched
class BackupSummary {
  final DateTime? when;
  final int version;
  final String haloId;
  final int contacts;
  final int messages;
  const BackupSummary({
    required this.when,
    required this.version,
    required this.haloId,
    required this.contacts,
    required this.messages,
  });
}

// scrypt takes a good second on a phone. it runs on its own isolate so the
// screen keeps painting while it works.
Future<String> _decryptOnIsolate(String blob, String passphrase) {
  return Isolate.run(() {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    final fn = lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloDecryptBackup');
    final p1 = blob.toNativeUtf8();
    final p2 = passphrase.toNativeUtf8();
    try {
      return fn(p1, p2).toDartString();
    } finally {
      calloc.free(p1);
      calloc.free(p2);
    }
  });
}

Future<Map<String, dynamic>> _openPayload(
  String blob,
  String passphrase,
) async {
  if (!(blob.startsWith('kryfo-backup:') || blob.startsWith('halo-backup:'))) {
    throw const RestoreError(RestoreFailure.notABackup);
  }
  final result = await _decryptOnIsolate(blob, passphrase);
  if (result.startsWith('error:')) {
    throw RestoreError(classifyRestoreError(result));
  }
  Map<String, dynamic> payload;
  try {
    payload = jsonDecode(result) as Map<String, dynamic>;
  } catch (_) {
    throw const RestoreError(RestoreFailure.damaged);
  }
  final v = payload['v'];
  if (v is! int) throw const RestoreError(RestoreFailure.damaged);
  if (v > 1) throw const RestoreError(RestoreFailure.newerVersion);
  if (payload['db'] is! String || payload['dbPassphrase'] is! String) {
    throw const RestoreError(RestoreFailure.damaged);
  }
  return payload;
}

// decrypt, look, say what is inside, touch nothing. the database bytes go
// to a private temp file just long enough to be counted, then are shredded.
Future<BackupSummary> inspectBackup(String blob, String passphrase) async {
  final payload = await _openPayload(blob, passphrase);
  final ts = payload['ts'];
  final when = ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
  final dir = await getApplicationSupportDirectory();
  final peek = File(p.join(dir.path, 'restore_peek.db'));
  var contacts = 0;
  var messages = 0;
  var haloId = '';
  try {
    await peek.writeAsBytes(base64Decode(payload['db'] as String), flush: true);
    final db = await openDatabase(
      peek.path,
      password: payload['dbPassphrase'] as String,
      readOnly: true,
    );
    try {
      final c = await db.rawQuery(
        'SELECT COUNT(*) c FROM contacts WHERE accepted = 1',
      );
      contacts = (c.first['c'] as int?) ?? 0;
      final m = await db.rawQuery('SELECT COUNT(*) c FROM messages');
      messages = (m.first['c'] as int?) ?? 0;
      final i = await db.query('identity', columns: ['id'], limit: 1);
      if (i.isNotEmpty) haloId = (i.first['id'] as String?) ?? '';
    } finally {
      await db.close();
    }
  } catch (e) {
    if (e is RestoreError) rethrow;
    throw const RestoreError(RestoreFailure.damaged);
  } finally {
    await shredFile(peek.path);
  }
  return BackupSummary(
    when: when,
    version: payload['v'] as int,
    haloId: haloId,
    contacts: contacts,
    messages: messages,
  );
}

// produces an encrypted backup blob. throws BackupError on failure.
Future<String> createBackupBlob(String passphrase) async {
  if (passphrase.length < 6) {
    throw BackupError('passphrase too short');
  }
  try {
    final docsDir = await getApplicationDocumentsDirectory();

    // identity keys (hex strings)
    final edPriv = engine.myEdPrivkey();
    final xPriv = engine.myXPrivkey();
    if (edPriv.isEmpty || xPriv.isEmpty) {
      throw BackupError('identity not loaded');
    }

    // onion key - may not exist yet if user never started the listener
    String? onionKeyB64;
    final onionPath = p.join(docsDir.path, 'onion.key');
    final onionFile = File(onionPath);
    if (await onionFile.exists()) {
      onionKeyB64 = base64Encode(await onionFile.readAsBytes());
    }

    // sqlcipher passphrase
    final dbPassphrase = await _secureStorage.read(key: _kDbPassphrase);
    if (dbPassphrase == null) {
      throw BackupError('db passphrase missing');
    }

    // database bytes
    final dbPath = p.join(docsDir.path, 'halo.db');
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw BackupError('db file not found');
    }
    final dbBytes = await dbFile.readAsBytes();
    final dbB64 = base64Encode(dbBytes);

    // prefs (push mode, ntfy topic, ntfy server, app lock state)
    final prefs = await SharedPreferences.getInstance();
    final prefKeys = <String>[
      'push_mode',
      'ntfy_topic',
      'ntfy_server',
      'onboarding.complete',
    ];
    final prefsMap = <String, dynamic>{};
    for (final k in prefKeys) {
      final v = prefs.get(k);
      if (v != null) prefsMap[k] = v;
    }

    // onboarding_done lives in default FlutterSecureStorage, not the
    // halo.db one. read it separately.
    final defaultStorage = const FlutterSecureStorage();
    final onboardingDone = await defaultStorage.read(key: 'onboarding_done');

    final payload = {
      'v': 1,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'edPriv': edPriv,
      'xPriv': xPriv,
      'onionKey': onionKeyB64,
      'dbPassphrase': dbPassphrase,
      'db': dbB64,
      'prefs': prefsMap,
      'onboardingDone': onboardingDone,
    };
    final json = jsonEncode(payload);

    final blob = engine.encryptBackup(json, passphrase);
    if (blob.startsWith('error:')) {
      throw BackupError(blob);
    }
    return blob;
  } catch (e) {
    if (e is BackupError) rethrow;
    throw BackupError('$e');
  }
}

// applies a previously-created backup blob. must be called BEFORE the
// engine has fully booted (specifically before identity is generated)
// otherwise the new identity will clash.
Future<void> restoreBackupBlob(String blob, String passphrase) async {
  final payload = await _openPayload(blob, passphrase);

  final docsDir = await getApplicationDocumentsDirectory();

  // restore db passphrase first (must be in secure storage before db opens)
  final dbPassphrase = payload['dbPassphrase'] as String;
  await _secureStorage.write(key: _kDbPassphrase, value: dbPassphrase);

  // restore db bytes
  final dbBytes = base64Decode(payload['db'] as String);
  final dbPath = p.join(docsDir.path, 'halo.db');
  await File(dbPath).writeAsBytes(dbBytes, flush: true);

  // restore onion key
  final onionKeyB64 = payload['onionKey'] as String?;
  if (onionKeyB64 != null) {
    final onionBytes = base64Decode(onionKeyB64);
    await File(
      p.join(docsDir.path, 'onion.key'),
    ).writeAsBytes(onionBytes, flush: true);
  }

  // restore prefs
  final prefs = await SharedPreferences.getInstance();
  final prefsMap = payload['prefs'] as Map<String, dynamic>? ?? {};
  for (final entry in prefsMap.entries) {
    final v = entry.value;
    if (v is String) {
      await prefs.setString(entry.key, v);
    } else if (v is int) {
      await prefs.setInt(entry.key, v);
    } else if (v is bool) {
      await prefs.setBool(entry.key, v);
    } else if (v is double) {
      await prefs.setDouble(entry.key, v);
    }
  }

  // restore the onboarding_done flag to default secure storage
  final defaultStorage = const FlutterSecureStorage();
  final onboardingDone = payload['onboardingDone'] as String?;
  if (onboardingDone != null) {
    await defaultStorage.write(key: 'onboarding_done', value: onboardingDone);
  }

  // restore identity in engine (this also rehydrates myId)
  final edPriv = payload['edPriv'] as String;
  final xPriv = payload['xPriv'] as String;
  engine.restoreIdentity(edPriv, xPriv);
  dlog('backup: restored identity');
}
