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
import 'main.dart' show TwoArgFn, TwoArgFnDart, appState, db, engine, shredFile;
import 'dlog.dart';
import 'dart:typed_data';
import 'backup_stream.dart';
import 'dart:math';

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
// what a backup holds, before anything is touched. bytes and files are
// zero for a v1 file, which never carried attachments.
class BackupSummary {
  final DateTime? when;
  final int bytes;
  final int files;
  // true when the phone that made the file retired itself. null for v1
  final bool? moved;
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
    this.bytes = 0,
    this.files = 0,
    this.moved,
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

  // a v1 backup carries none of these; what is here is the old identity's
  await _applyIdentitySecure(payload['secure']);

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

// ───────────────────────── v2: the streamed file ─────────────────────────
//
// one key from the passphrase, every record sealed on its own, the files
// read and written a chunk at a time. see backup_stream.dart for the
// layout. the cryptography is the engine's (HaloBackupKey, HaloSealChunk,
// HaloOpenChunk); it is reached from a worker isolate, which opens the
// library itself, so scrypt and a year of photos never block the screen.

typedef _KeyFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Uint8>);
typedef _KeyFnDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Uint8>);
typedef _ChunkFn =
    Int32 Function(
      Pointer<Utf8>,
      Uint64,
      Uint8,
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
    );
typedef _ChunkFnDart =
    int Function(Pointer<Utf8>, int, int, Pointer<Uint8>, int, Pointer<Uint8>);

DynamicLibrary _engineLib() => Platform.isAndroid
    ? DynamicLibrary.open('libhalo.so')
    : DynamicLibrary.process();

// derives the key. null when the engine refused, which it never should
String? _backupKey(DynamicLibrary lib, String passphrase, Uint8List salt) {
  final fn = lib.lookupFunction<_KeyFn, _KeyFnDart>('HaloBackupKey');
  final p1 = passphrase.toNativeUtf8();
  final ps = calloc<Uint8>(16);
  try {
    ps.asTypedList(16).setAll(0, salt);
    final r = fn(p1, ps).toDartString();
    return r.startsWith('error:') ? null : r;
  } finally {
    calloc.free(p1);
    calloc.free(ps);
  }
}

class _EngineCipher implements ChunkCipher {
  final _ChunkFnDart _seal;
  final _ChunkFnDart _open;
  final Pointer<Utf8> _key;
  final Pointer<Uint8> _in;
  final Pointer<Uint8> _out;
  final int _cap;
  _EngineCipher(DynamicLibrary lib, String keyHex, int chunk)
    : _seal = lib.lookupFunction<_ChunkFn, _ChunkFnDart>('HaloSealChunk'),
      _open = lib.lookupFunction<_ChunkFn, _ChunkFnDart>('HaloOpenChunk'),
      _key = keyHex.toNativeUtf8(),
      _cap = chunk + 16 + 4096,
      _in = calloc<Uint8>(chunk + 16 + 4096),
      _out = calloc<Uint8>(chunk + 16 + 4096);

  @override
  Uint8List seal(int index, int type, Uint8List plain) {
    if (plain.length + 16 > _cap) throw ArgumentError('record too big');
    _in.asTypedList(_cap).setAll(0, plain);
    final n = _seal(_key, index, type, _in, plain.length, _out);
    if (n < 0) throw const BackupDamaged('seal failed');
    return Uint8List.fromList(_out.asTypedList(n));
  }

  @override
  Uint8List? open(int index, int type, Uint8List sealed) {
    if (sealed.length > _cap) return null;
    _in.asTypedList(_cap).setAll(0, sealed);
    final n = _open(_key, index, type, _in, sealed.length, _out);
    if (n < 0) return null;
    return Uint8List.fromList(_out.asTypedList(n));
  }

  void dispose() {
    calloc.free(_key);
    calloc.free(_in);
    calloc.free(_out);
  }
}

// everything under docs that a restore has to bring back, relative to
// docs, in a fixed order: the database first so a peek can stop early
Future<List<BackupFileEntry>> _filesToCarry(Directory docs) async {
  final out = <BackupFileEntry>[];
  Future<void> add(String rel) async {
    final f = File(p.join(docs.path, rel));
    if (await f.exists()) out.add(BackupFileEntry(rel, await f.length()));
  }

  await add('halo.db');
  await add('onion.key');
  for (final folder in ['media', 'wallpapers']) {
    final d = Directory(p.join(docs.path, folder));
    if (!await d.exists()) continue;
    final names = <String>[];
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File) names.add(p.relative(e.path, from: docs.path));
    }
    names.sort();
    for (final n in names) {
      if (safeBackupName(n)) await add(n);
    }
  }
  return out;
}

// what belongs to the identity but lives in secure storage, outside the
// database: the public handle and its line, which first-contact address is
// the live one, and where each contact takes first contact. left behind,
// the new phone did not know its own handle, and after a reset of the
// invite it listened on address 0 while the published invite named another,
// so a stranger's first message went nowhere and nothing said so.
const kIdentitySecureKeys = [
  'my_handle',
  'my_handle_bio',
  'fc_counter',
  'peer_fc',
];

/// what a restore does to those keys: the carried ones are written, and
/// every other one is removed, because whatever sits there belonged to the
/// identity being replaced. a backup from before they were carried has
/// none, and removes them all.
({Map<String, String> write, List<String> remove}) identitySecurePlan(
  Object? carried,
) {
  final write = <String, String>{};
  if (carried is Map) {
    for (final k in kIdentitySecureKeys) {
      final v = carried[k];
      if (v is String && v.isNotEmpty) write[k] = v;
    }
  }
  return (
    write: write,
    remove: [
      for (final k in kIdentitySecureKeys)
        if (!write.containsKey(k)) k,
    ],
  );
}

Future<Map<String, String>> _readIdentitySecure() async {
  const st = FlutterSecureStorage();
  final out = <String, String>{};
  for (final k in kIdentitySecureKeys) {
    final v = await st.read(key: k);
    if (v != null && v.isNotEmpty) out[k] = v;
  }
  return out;
}

Future<void> _applyIdentitySecure(Object? carried) async {
  const st = FlutterSecureStorage();
  final plan = identitySecurePlan(carried);
  for (final e in plan.write.entries) {
    await st.write(key: e.key, value: e.value);
  }
  for (final k in plan.remove) {
    await st.delete(key: k);
  }
}

/// writes a v2 backup to [outPath]. everything the phone holds: identity,
/// database, onion key, prefs, and every photo, voice note and file.
/// [onProgress] is told bytes done of bytes total.
Future<void> createBackupFile(
  String passphrase,
  String outPath, {
  bool move = false,
  void Function(int done, int total)? onProgress,
}) async {
  if (passphrase.length < 6) throw BackupError('passphrase too short');
  final docs = await getApplicationDocumentsDirectory();
  final edPriv = engine.myEdPrivkey();
  final xPriv = engine.myXPrivkey();
  if (edPriv.isEmpty || xPriv.isEmpty) throw BackupError('identity not loaded');
  final dbPassphrase = await _secureStorage.read(key: _kDbPassphrase);
  if (dbPassphrase == null) throw BackupError('db passphrase missing');
  // fold the write-ahead log in first, or the last minutes are not in
  // the file that gets copied
  await db.checkpoint();
  final prefs = await SharedPreferences.getInstance();
  final prefsMap = <String, dynamic>{};
  for (final k in [
    'push_mode',
    'ntfy_topic',
    'ntfy_server',
    'onboarding.complete',
  ]) {
    final v = prefs.get(k);
    if (v != null) prefsMap[k] = v;
  }
  final onboardingDone = await const FlutterSecureStorage().read(
    key: 'onboarding_done',
  );
  final files = await _filesToCarry(docs);
  if (!files.any((f) => f.name == 'halo.db')) {
    throw BackupError('db file not found');
  }
  final manifest = <String, dynamic>{
    'v': 2,
    'ts': DateTime.now().millisecondsSinceEpoch,
    'haloId': appState.myId,
    // whether the phone that made this retired itself. a copy to keep
    // says false, and the restore then warns that two phones on one
    // identity lose messages on both
    'moved': move,
    'edPriv': edPriv,
    'xPriv': xPriv,
    'dbPassphrase': dbPassphrase,
    'prefs': prefsMap,
    'secure': await _readIdentitySecure(),
    'onboardingDone': onboardingDone,
    'chunk': kBackupChunk,
    'files': [for (final f in files) f.toJson()],
  };
  final salt = Uint8List(16);
  final rnd = Random.secure();
  for (var i = 0; i < 16; i++) {
    salt[i] = rnd.nextInt(256);
  }
  final port = ReceivePort();
  final sub = port.listen((m) {
    if (m is List && m.length == 2) {
      onProgress?.call(m[0] as int, m[1] as int);
    }
  });
  try {
    final err = await _runJob(
      _exportJob,
      _Job(
        passphrase: passphrase,
        salt: salt,
        path: outPath,
        root: docs.path,
        manifest: manifest,
        tell: port.sendPort,
      ),
    );
    if (err is String && err.isNotEmpty) throw BackupError(err);
  } finally {
    await sub.cancel();
    port.close();
  }
}

// what crosses into a worker isolate: plain values and a SendPort, nothing
// else. the job runs as a top-level function and the closure handed to
// Isolate.run captures this one object and nothing more. an inline closure
// dragged its whole enclosing scope along - the ReceivePort, a completer -
// and Isolate.run refused it, silently from the user's side.
class _Job {
  final String passphrase;
  final Uint8List salt;
  final String path;
  final String root;
  final Map<String, dynamic>? manifest;
  final SendPort? tell;
  const _Job({
    required this.passphrase,
    required this.salt,
    required this.path,
    required this.root,
    this.manifest,
    this.tell,
  });
}

Future<Object?> _runJob(Future<Object?> Function(_Job) job, _Job j) =>
    Isolate.run(() => job(j));

Future<Object?> _exportJob(_Job j) async {
  final lib = _engineLib();
  final key = _backupKey(lib, j.passphrase, j.salt);
  if (key == null) return 'could not make the key';
  final cipher = _EngineCipher(lib, key, kBackupChunk);
  try {
    await writeBackup(
      outPath: j.path,
      salt: j.salt,
      cipher: cipher,
      manifest: j.manifest!,
      root: j.root,
      onProgress: (a, b) => j.tell?.send([a, b]),
    );
  } finally {
    cipher.dispose();
  }
  return '';
}

// reads the manifest and streams halo.db to j.root (the peek path), so the
// caller can count what is inside without touching the phone's own files
Future<Object?> _inspectJob(_Job j) async {
  final lib = _engineLib();
  final key = _backupKey(lib, j.passphrase, j.salt);
  if (key == null) throw const BackupLocked();
  final cipher = _EngineCipher(lib, key, kBackupChunk);
  try {
    final m = await readBackupManifest(j.path, cipher);
    if (m['v'] is! int) throw const BackupDamaged('no version');
    if ((m['v'] as int) > 2) {
      throw const RestoreError(RestoreFailure.newerVersion);
    }
    if (m['dbPassphrase'] is! String || m['edPriv'] is! String) {
      throw const BackupDamaged('manifest secrets');
    }
    await extractBackup(
      j.path,
      cipher,
      want: (n) => n == 'halo.db' ? j.root : null,
    );
    return m;
  } finally {
    cipher.dispose();
  }
}

// streams every file into a staging folder under j.root and only then
// moves them into place. the file is proved whole - end record and all -
// before a single byte of the phone's own data is touched, so a backup
// cut short halfway leaves the phone exactly as it was. the earlier order
// deleted the media and wrote the database first, and a bad file would
// have left a database the phone could not open with its old identity
// already gone.
Future<Object?> _restoreJob(_Job j) async {
  final lib = _engineLib();
  final key = _backupKey(lib, j.passphrase, j.salt);
  if (key == null) throw const BackupLocked();
  final cipher = _EngineCipher(lib, key, kBackupChunk);
  final stage = Directory(p.join(j.root, 'restore_stage'));
  try {
    if (await stage.exists()) await stage.delete(recursive: true);
    await stage.create(recursive: true);
    final m = await readBackupManifest(j.path, cipher);
    if ((m['v'] as int? ?? 99) > 2) {
      throw const RestoreError(RestoreFailure.newerVersion);
    }
    await extractBackup(
      j.path,
      cipher,
      want: (n) => p.join(stage.path, n),
      onProgress: (a, b) => j.tell?.send([a, b]),
    );
    // whole. now, and only now, the phone's own files go
    for (final folder in ['media', 'wallpapers']) {
      final d = Directory(p.join(j.root, folder));
      if (await d.exists()) await d.delete(recursive: true);
    }
    // a rollback journal left by the open database would be replayed
    // over the restored one on the next open
    for (final side in ['halo.db-journal', 'halo.db-wal', 'halo.db-shm']) {
      final f = File(p.join(j.root, side));
      if (await f.exists()) await f.delete();
    }
    final files = [
      for (final f in m['files'] as List)
        BackupFileEntry.fromJson(f as Map<String, dynamic>),
    ];
    for (final f in files) {
      final dest = File(p.join(j.root, f.name));
      await dest.parent.create(recursive: true);
      await File(p.join(stage.path, f.name)).rename(dest.path);
    }
    return m;
  } finally {
    cipher.dispose();
    try {
      if (await stage.exists()) await stage.delete(recursive: true);
    } catch (_) {}
  }
}

RestoreError _classify(Object e) {
  if (e is RestoreError) return e;
  if (e is BackupLocked) {
    return const RestoreError(RestoreFailure.wrongPassphrase);
  }
  return const RestoreError(RestoreFailure.damaged);
}

/// looks inside a v2 file: who it is, how much it holds, touching nothing.
/// the database is streamed to a private temp file just long enough to be
/// counted, then shredded.
Future<BackupSummary> inspectBackupFile(String path, String passphrase) async {
  if (!await isBackupV2(path)) {
    throw const RestoreError(RestoreFailure.notABackup);
  }
  final salt = await backupSalt(path);
  final dir = await getApplicationSupportDirectory();
  final peek = p.join(dir.path, 'restore_peek.db');
  Map<String, dynamic> manifest;
  try {
    manifest =
        await _runJob(
              _inspectJob,
              _Job(passphrase: passphrase, salt: salt, path: path, root: peek),
            )
            as Map<String, dynamic>;
  } catch (e) {
    await shredFile(peek);
    throw _classify(e);
  }
  var contacts = 0;
  var messages = 0;
  var haloId = manifest['haloId'] as String? ?? '';
  try {
    final db = await openDatabase(
      peek,
      password: manifest['dbPassphrase'] as String,
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
      if (i.isNotEmpty) haloId = (i.first['id'] as String?) ?? haloId;
    } finally {
      await db.close();
    }
  } catch (_) {
    throw const RestoreError(RestoreFailure.damaged);
  } finally {
    await shredFile(peek);
  }
  final files = [
    for (final f in manifest['files'] as List)
      BackupFileEntry.fromJson(f as Map<String, dynamic>),
  ];
  final ts = manifest['ts'];
  return BackupSummary(
    when: ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
    version: manifest['v'] as int,
    haloId: haloId,
    contacts: contacts,
    messages: messages,
    bytes: files.fold<int>(0, (a, f) => a + f.size),
    // the database and the onion key are not attachments
    files: files.where((f) => f.name.contains('/')).length,
    moved: manifest['moved'] as bool?,
  );
}

/// brings a v2 file in. the files land under docs exactly where they came
/// from, then the secrets and prefs go where the app reads them. the app
/// is expected to exit afterwards and boot from what was written.
Future<void> restoreBackupFile(
  String path,
  String passphrase, {
  void Function(int done, int total)? onProgress,
}) async {
  if (!await isBackupV2(path)) {
    throw const RestoreError(RestoreFailure.notABackup);
  }
  final salt = await backupSalt(path);
  final docs = await getApplicationDocumentsDirectory();
  final root = docs.path;
  final port = ReceivePort();
  final sub = port.listen((m) {
    if (m is List && m.length == 2) {
      onProgress?.call(m[0] as int, m[1] as int);
    }
  });
  Map<String, dynamic> manifest;
  try {
    manifest =
        await _runJob(
              _restoreJob,
              _Job(
                passphrase: passphrase,
                salt: salt,
                path: path,
                root: root,
                tell: port.sendPort,
              ),
            )
            as Map<String, dynamic>;
  } catch (e) {
    throw _classify(e);
  } finally {
    await sub.cancel();
    port.close();
  }
  await _secureStorage.write(
    key: _kDbPassphrase,
    value: manifest['dbPassphrase'] as String,
  );
  final prefs = await SharedPreferences.getInstance();
  final prefsMap = manifest['prefs'] as Map<String, dynamic>? ?? {};
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
  // this device is where the identity lives now, whatever it was before
  await prefs.remove('moved.at');
  await _applyIdentitySecure(manifest['secure']);
  final onboardingDone = manifest['onboardingDone'] as String?;
  if (onboardingDone != null) {
    await const FlutterSecureStorage().write(
      key: 'onboarding_done',
      value: onboardingDone,
    );
  }
  engine.restoreIdentity(
    manifest['edPriv'] as String,
    manifest['xPriv'] as String,
  );
  dlog('backup: restored identity from a v2 file');
}
