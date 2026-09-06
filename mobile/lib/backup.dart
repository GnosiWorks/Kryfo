// SPDX-License-Identifier: GPL-3.0-or-later
// backup.dart - full identity + db + prefs backup, encrypted with a
// user passphrase. one blob, restorable on any device. uses the engine
// for scrypt + aes-gcm (HaloEncryptBackup / HaloDecryptBackup).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show engine;
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
  final result = engine.decryptBackup(blob, passphrase);
  if (result.startsWith('error:')) {
    throw BackupError(result);
  }
  Map<String, dynamic> payload;
  try {
    payload = jsonDecode(result) as Map<String, dynamic>;
  } catch (_) {
    throw BackupError('payload not valid json');
  }
  if (payload['v'] != 1) {
    throw BackupError('unsupported backup version: ${payload['v']}');
  }

  final docsDir = await getApplicationDocumentsDirectory();

  // restore db passphrase first (must be in secure storage before db opens)
  final dbPassphrase = payload['dbPassphrase'] as String?;
  if (dbPassphrase == null) throw BackupError('missing db passphrase');
  await _secureStorage.write(key: _kDbPassphrase, value: dbPassphrase);

  // restore db bytes
  final dbB64 = payload['db'] as String?;
  if (dbB64 == null) throw BackupError('missing db bytes');
  final dbBytes = base64Decode(dbB64);
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
