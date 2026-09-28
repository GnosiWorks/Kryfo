// SPDX-License-Identifier: GPL-3.0-or-later
// full backup of identity, db, prefs and media, encrypted with a user
// passphrase by the engine (scrypt and aes-gcm). a v1 backup is one text
// blob; v2 is the streamed file below. one made with the hidden chats open
// carries them too, under vault/ names, with their key in the manifest.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'container.dart';
import 'lock_state.dart' show LockState, lockState;
import 'main.dart'
    show
        HaloDb,
        TwoArgFn,
        TwoArgFnDart,
        appState,
        live,
        session,
        sessionQuiet,
        engine,
        shredFile;
import 'router.dart' show scrubHidden;
import 'devchat/dev_chat.dart' show scrubDevAnon;
import 'dlog.dart';
import 'dart:typed_data';
import 'backup_stream.dart';
import 'dart:math';
import 'l10n/l10n.dart';

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

// the four things that can go wrong opening a backup, each in plain words
// rather than a code
enum RestoreFailure { wrongPassphrase, notABackup, newerVersion, damaged }

class RestoreError implements Exception {
  final RestoreFailure why;
  const RestoreError(this.why);
  String get line => switch (why) {
    RestoreFailure.wrongPassphrase => l10n.backupThatPassphraseDoesNot,
    RestoreFailure.notABackup => l10n.backupThatFileIsNot,
    RestoreFailure.newerVersion => l10n.backupThisBackupIsFrom,
    RestoreFailure.damaged => l10n.backupThisFileIsDamaged,
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

// what a backup holds, read before anything is touched. bytes and files are
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
  // how many chats and groups it holds hidden, null when it holds none that
  // come back here
  final int? hiddenChats;
  const BackupSummary({
    required this.when,
    required this.version,
    required this.haloId,
    required this.contacts,
    required this.messages,
    this.bytes = 0,
    this.files = 0,
    this.moved,
    this.hiddenChats,
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

  // db passphrase first: it must be in secure storage before the db opens
  final dbPassphrase = payload['dbPassphrase'] as String;
  await _secureStorage.write(key: _kDbPassphrase, value: dbPassphrase);

  final dbBytes = base64Decode(payload['db'] as String);
  final dbPath = p.join(docsDir.path, 'halo.db');
  await File(dbPath).writeAsBytes(dbBytes, flush: true);
  // hidden chats of the account just replaced go with it
  if (!sessionQuiet) {
    await landHidden(
      docsDir.path,
      null,
      const {},
      clearEntry: lockState.clearVault,
    );
  }

  final onionKeyB64 = payload['onionKey'] as String?;
  if (onionKeyB64 != null) {
    final onionBytes = base64Decode(onionKeyB64);
    await File(
      p.join(docsDir.path, 'onion.key'),
    ).writeAsBytes(onionBytes, flush: true);
  }

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

  final defaultStorage = const FlutterSecureStorage();
  final onboardingDone = payload['onboardingDone'] as String?;
  if (onboardingDone != null) {
    await defaultStorage.write(key: 'onboarding_done', value: onboardingDone);
  }

  // restoring the identity in the engine also rehydrates myId
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

// a file that carries hidden chats says 3, so an older Kryfo says it is from
// a newer one instead of leaving them behind
const kBackupVersion = 2;
const kBackupVersionHidden = 3;

// the hidden chats' files in a backup: their database and their folders
const kHiddenDir = 'vault';
const kHiddenDb = '$kHiddenDir/halo_v.db';

// the rest of a name under vault/, null for a name of the everyday side
String? hiddenPart(String name) => name.startsWith('$kHiddenDir/')
    ? name.substring(kHiddenDir.length + 1)
    : null;

// the key of the hidden chats a manifest carries, null when it carries none
String? hiddenKeyOf(Map<String, dynamic> m) {
  final v = m['vault'];
  if (v == null) return null;
  final k = v is Map ? v['key'] : null;
  if (k is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(k)) {
    throw const BackupDamaged('hidden chats key');
  }
  return k;
}

// a backup made in this session carries the hidden chats: they are open
bool get sessionBackupHasHidden => session.vault != null;

// what a backup holds: the hidden chats of its identity when they are open
// or a setup just hid them ([made]). one from a setup never moves, and a
// decoy never does
({bool hidden, bool made, bool move}) backupShape({
  required bool quiet,
  required bool open,
  required bool setup,
  required bool move,
}) => (
  hidden: open || setup,
  made: setup && !open,
  move: move && !setup && !quiet,
);

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

// a container's photos, voice notes, files and wallpapers as they are on
// disk, under the names a backup gives them: [under] then media/.. or
// wallpapers/..
Future<void> _addFolders(
  List<BackupFileEntry> files,
  Map<String, String> sources,
  String docs,
  String suffix, {
  String under = '',
}) async {
  for (final folder in ['media', 'wallpapers']) {
    final d = Directory(p.join(docs, '$folder$suffix'));
    if (!await d.exists()) continue;
    final found = <String, File>{};
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      found['$under$folder/${p.relative(e.path, from: d.path)}'] = e;
    }
    for (final name in found.keys.toList()..sort()) {
      if (!safeBackupName(name)) continue;
      final f = found[name]!;
      files.add(BackupFileEntry(name, await f.length()));
      sources[name] = f.path;
    }
  }
}

// what belongs to the identity but lives in secure storage, outside the
// database: the public handle and its line, which first-contact address is
// the live one, and where each contact takes first contact. without them a
// restored phone does not know its own handle and can listen on a different
// address than its published invite names.
const kIdentitySecureKeys = [
  'my_handle',
  'my_handle_bio',
  'my_handle_listed',
  'my_handle_name',
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

/// puts a handle back when a restore of the same identity removed it
Future<void> keepHandleIfDropped(String handle) async {
  const st = FlutterSecureStorage();
  final now = await st.read(key: 'my_handle');
  if (now == null || now.isEmpty) {
    await st.write(key: 'my_handle', value: handle);
  }
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

// what a backup reads besides the folders: the identity, and the databases
// while the vault holds still. the app's own, or stand-ins in the tests
class BackupSide {
  const BackupSide();

  ({String ed, String x, String id}) identity() =>
      (ed: engine.myEdPrivkey(), x: engine.myXPrivkey(), id: appState.myId);

  Future<T> still<T>(
    Future<T> Function(HaloDb? vault) work, {
    required bool made,
  }) => appState.backupStill(work, made: made);

  Future<void> copyEveryday(String to) => live.copyTo(to);

  // the hidden chats' database copied whole. its key
  Future<String> copyHidden(HaloDb vault, String to) => vault.copyWithKey(to);

  // the copy of halo.db made to carry nothing of hidden chats. who the list
  // named
  Future<Set<String>> scrub(String copy, String key) async {
    final db = await openDatabase(copy, password: key, singleInstance: false);
    try {
      final people = await scrubHidden(db);
      // every change in the file itself before it is read as bytes
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      return people;
    } finally {
      await db.close();
    }
  }

  // every copy of a container's database that leaves the phone: the name
  // an anonymous dev chat was made with stays behind. freed pages zeroed
  Future<void> scrubDev(String copy, String key) async {
    final db = await openDatabase(copy, password: key, singleInstance: false);
    try {
      await db.rawQuery('PRAGMA secure_delete = 1');
      await db.transaction(scrubDevAnon);
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      await db.close();
    }
  }
}

// the hidden chats a backup carries, taken while their vault holds still:
// their database copied whole under its own key, their folders where they
// lie, all under vault/. the key
Future<String> _carryHidden(
  BackupSide side,
  HaloDb vault,
  String stage,
  String docs,
  List<BackupFileEntry> files,
  Map<String, String> sources,
) async {
  final to = p.join(stage, kHiddenDb);
  await Directory(p.dirname(to)).create(recursive: true);
  final key = await side.copyHidden(vault, to);
  files.add(BackupFileEntry(kHiddenDb, await File(to).length()));
  sources[kHiddenDb] = to;
  await _addFolders(
    files,
    sources,
    docs,
    vault.container.suffix,
    under: '$kHiddenDir/',
  );
  return key;
}

// a backup put together before a byte of it is written: its manifest, and
// where each file it lists is read from
class BackupDraft {
  BackupDraft(this.manifest, this.sources);
  final Map<String, dynamic> manifest;
  final Map<String, String> sources;
}

/// the everyday identity's backup, put together in [stage]: halo.db copied
/// whole and every photo, voice note and file where it lies. with [hidden]
/// the hidden chats come too, copied in the same still moment with their
/// key: the open ones, or with [made] the ones a setup just hid. without,
/// the copy of halo.db carries nothing of them
Future<BackupDraft> draftBackup(
  String stage, {
  BackupSide side = const BackupSide(),
  bool move = false,
  bool hidden = false,
  bool made = false,
}) async {
  if (made && (move || !hidden)) {
    throw ArgumentError('a setup backup holds its hidden chats, never moves');
  }
  final docs = (await getApplicationDocumentsDirectory()).path;
  final id = side.identity();
  if (id.ed.isEmpty || id.x.isEmpty) throw BackupError('identity not loaded');
  final dbKey = await _secureStorage.read(key: _kDbPassphrase);
  if (dbKey == null) throw BackupError('db passphrase missing');
  final prefs = await SharedPreferences.getInstance();
  final prefsMap = <String, dynamic>{};
  for (final k in ['onboarding.complete']) {
    final v = prefs.get(k);
    if (v != null) prefsMap[k] = v;
  }
  final onboardingDone = await const FlutterSecureStorage().read(
    key: 'onboarding_done',
  );
  final secure = await _readIdentitySecure();
  final dbCopy = p.join(stage, 'halo.db');
  final folders = <BackupFileEntry>[];
  final sources = <String, String>{};
  final key = await side.still((vault) async {
    // a vault shut before this ran is not in the file, and the file is not
    // made: a backup that should hold hidden chats never comes out without
    if (hidden && vault == null) throw BackupError(l10n.backupHiddenGone);
    await side.copyEveryday(dbCopy);
    await _addFolders(folders, sources, docs, '');
    if (!hidden) return null;
    return _carryHidden(side, vault!, stage, docs, folders, sources);
  }, made: made);
  // no backup and no move carries an anonymous dev chat's made name
  await side.scrubDev(dbCopy, dbKey);
  if (!hidden) {
    final people = await side.scrub(dbCopy, dbKey);
    final fc = secure['peer_fc'];
    if (fc != null && people.isNotEmpty) {
      try {
        final m = Map<String, Object?>.from(jsonDecode(fc) as Map)
          ..removeWhere((k, _) => people.contains(k));
        secure['peer_fc'] = jsonEncode(m);
      } catch (_) {
        secure.remove('peer_fc');
      }
    }
  }
  final files = <BackupFileEntry>[];
  Future<void> add(String name, String from) async {
    final f = File(from);
    if (!await f.exists()) return;
    files.add(BackupFileEntry(name, await f.length()));
    sources[name] = from;
  }

  await add('halo.db', dbCopy);
  if (files.isEmpty) throw BackupError('db file not found');
  await add('onion.key', p.join(docs, 'onion.key'));
  files.addAll(folders);
  final manifest = <String, dynamic>{
    'v': hidden ? kBackupVersionHidden : kBackupVersion,
    'ts': DateTime.now().millisecondsSinceEpoch,
    'haloId': id.id,
    // whether the phone that made this retired itself. a copy to keep
    // says false, and the restore then warns that two phones on one
    // identity lose messages on both
    'moved': move,
    'edPriv': id.ed,
    'xPriv': id.x,
    'dbPassphrase': dbKey,
    'prefs': prefsMap,
    'secure': secure,
    'onboardingDone': onboardingDone,
    'chunk': kBackupChunk,
    'files': [for (final f in files) f.toJson()],
    if (hidden) 'vault': {'key': key},
  };
  return BackupDraft(manifest, sources);
}

/// writes a v2 backup to [outPath]. everything the phone holds: identity,
/// database, onion key, prefs, and every photo, voice note and file; with
/// the hidden chats open, or [withHiddenChats] from their setup, those too.
/// [onProgress] is told bytes done of bytes total.
Future<void> createBackupFile(
  String passphrase,
  String outPath, {
  bool move = false,
  bool withHiddenChats = false,
  void Function(int done, int total)? onProgress,
}) async {
  if (passphrase.length < 6) throw BackupError('passphrase too short');
  final stage = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'backup_stage'),
  );
  if (await stage.exists()) await stage.delete(recursive: true);
  await stage.create(recursive: true);
  try {
    final shape = backupShape(
      quiet: sessionQuiet,
      open: sessionBackupHasHidden,
      setup: withHiddenChats,
      move: move,
    );
    final draft = sessionQuiet
        ? await _draftQuiet(stage.path, hidden: shape.hidden, made: shape.made)
        : await draftBackup(
            stage.path,
            move: shape.move,
            hidden: shape.hidden,
            made: shape.made,
          );
    await _export(passphrase, outPath, draft, onProgress);
  } finally {
    try {
      await shredFile(p.join(stage.path, 'onion.key'));
    } catch (_) {}
    try {
      await stage.delete(recursive: true);
    } catch (_) {}
  }
}

Future<void> _export(
  String passphrase,
  String outPath,
  BackupDraft draft,
  void Function(int done, int total)? onProgress,
) async {
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
        root: '',
        manifest: draft.manifest,
        sources: draft.sources,
        tell: port.sendPort,
      ),
    );
    if (err is String && err.isNotEmpty) throw BackupError(err);
  } finally {
    await sub.cancel();
    port.close();
  }
}

// a backup in a decoy session holds only the decoy, under the names an
// everyday install uses, so it restores anywhere as its own account, with
// its hidden chats as an everyday backup holds them. never a move, and
// nothing of the everyday container is read
Future<BackupDraft> _draftQuiet(
  String stage, {
  BackupSide side = const BackupSide(),
  bool hidden = false,
  bool made = false,
}) async {
  final c = session.container;
  final docs = await getApplicationDocumentsDirectory();
  final hiddenFiles = <BackupFileEntry>[];
  final sources = <String, String>{};
  final key = !hidden
      ? null
      : await side.still((vault) async {
          if (vault == null) throw BackupError(l10n.backupHiddenGone);
          return _carryHidden(
            side,
            vault,
            stage,
            docs.path,
            hiddenFiles,
            sources,
          );
        }, made: made);
  final raw = await session.primary.open();
  final saved = await session.primary.loadIdentity();
  final onion = await raw.query(
    'signal_meta',
    where: 'k = ?',
    whereArgs: ['onion_key'],
    limit: 1,
  );
  final dbKey = await _secureStorage.read(key: c.keyName!);
  if (saved == null || onion.isEmpty || dbKey == null) {
    throw BackupError('identity not loaded');
  }
  await session.primary.checkpoint();
  await File(await c.dbPath()).copy(p.join(stage, 'halo.db'));
  await side.scrubDev(p.join(stage, 'halo.db'), dbKey);
  await File(
    p.join(stage, 'onion.key'),
  ).writeAsBytes(_hex(onion.first['v'] as String), flush: true);
  for (final folder in ['media', 'wallpapers']) {
    final from = Directory(p.join(docs.path, '$folder${c.suffix}'));
    if (!await from.exists()) continue;
    await for (final e in from.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final rel = p.relative(e.path, from: from.path);
      final to = File(p.join(stage, folder, rel));
      await to.parent.create(recursive: true);
      await e.copy(to.path);
    }
  }
  final files = [...await _filesToCarry(Directory(stage)), ...hiddenFiles];
  final manifest = <String, dynamic>{
    'v': hidden ? kBackupVersionHidden : kBackupVersion,
    'ts': DateTime.now().millisecondsSinceEpoch,
    'haloId': appState.sessionId,
    'moved': false,
    'edPriv': saved['ed_priv'],
    'xPriv': saved['x_priv'],
    'dbPassphrase': dbKey,
    'prefs': <String, dynamic>{},
    'secure': <String, String>{},
    'onboardingDone': '1',
    'chunk': kBackupChunk,
    'files': [for (final f in files) f.toJson()],
    if (hidden) 'vault': {'key': key},
  };
  return BackupDraft(manifest, {
    for (final f in files) f.name: p.join(stage, f.name),
    ...sources,
  });
}

/// a draft for a decoy session, put together in [stage], as a backup there
/// makes it
@visibleForTesting
Future<BackupDraft> draftQuietBackup(
  String stage, {
  BackupSide side = const BackupSide(),
  bool hidden = false,
  bool made = false,
}) => _draftQuiet(stage, side: side, hidden: hidden, made: made);

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i + 1 < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

// what crosses into a worker isolate: plain values and a SendPort, nothing
// else. the job is a top-level function so the closure handed to Isolate.run
// captures this one object; an inline closure drags in its whole scope (the
// ReceivePort, a completer) and Isolate.run refuses it.
class _Job {
  final String passphrase;
  final Uint8List salt;
  final String path;
  final String root;
  final Map<String, dynamic>? manifest;
  // where each file of a backup being written is read from
  final Map<String, String>? sources;
  // the hidden chats' side: where a restore leaves their files, or where a
  // peek puts their database
  final String? hidden;
  final SendPort? tell;
  const _Job({
    required this.passphrase,
    required this.salt,
    required this.path,
    required this.root,
    this.manifest,
    this.sources,
    this.hidden,
    this.tell,
  });
}

Future<Object?> _runJob(Future<Object?> Function(_Job) job, _Job j) =>
    Isolate.run(() => job(j));

Future<Object?> _exportJob(_Job j) async {
  final lib = _engineLib();
  final key = _backupKey(lib, j.passphrase, j.salt);
  if (key == null) return l10n.backupCouldNotMakeThe;
  final cipher = _EngineCipher(lib, key, kBackupChunk);
  final sources = j.sources!;
  try {
    await writeBackup(
      outPath: j.path,
      salt: j.salt,
      cipher: cipher,
      manifest: j.manifest!,
      root: j.root,
      source: (n) => sources[n]!,
      onProgress: (a, b) => j.tell?.send([a, b]),
    );
  } finally {
    cipher.dispose();
  }
  return '';
}

// reads the manifest and streams halo.db to j.root (the peek path), and the
// hidden chats' database to j.hidden, so the caller can count what is inside
// without touching the phone's own files
Future<Object?> _inspectJob(_Job j) async {
  final lib = _engineLib();
  final key = _backupKey(lib, j.passphrase, j.salt);
  if (key == null) throw const BackupLocked();
  final cipher = _EngineCipher(lib, key, kBackupChunk);
  try {
    final m = await readBackupManifest(j.path, cipher);
    if (m['v'] is! int) throw const BackupDamaged('no version');
    if ((m['v'] as int) > kBackupVersionHidden) {
      throw const RestoreError(RestoreFailure.newerVersion);
    }
    if (m['dbPassphrase'] is! String || m['edPriv'] is! String) {
      throw const BackupDamaged('manifest secrets');
    }
    final hidden = hiddenKeyOf(m) == null ? null : j.hidden;
    await extractBackup(
      j.path,
      cipher,
      want: (n) => n == 'halo.db'
          ? j.root
          : n == kHiddenDb
          ? hidden
          : null,
    );
    return m;
  } finally {
    cipher.dispose();
  }
}

Future<Object?> _restoreJob(_Job j) async {
  final lib = _engineLib();
  final key = _backupKey(lib, j.passphrase, j.salt);
  if (key == null) throw const BackupLocked();
  final cipher = _EngineCipher(lib, key, kBackupChunk);
  try {
    return await unpackBackup(
      j.path,
      cipher,
      root: j.root,
      hidden: j.hidden,
      onProgress: (a, b) => j.tell?.send([a, b]),
    );
  } finally {
    cipher.dispose();
  }
}

/// streams every file into a staging folder under [root] and only then
/// moves them into place. the file is proved whole, end record and all,
/// before a single byte of the phone's own data is touched, so a backup cut
/// short halfway leaves the phone exactly as it was. the hidden chats'
/// files wait in [hidden] for landHidden, or without it are left out
Future<Map<String, dynamic>> unpackBackup(
  String path,
  ChunkCipher cipher, {
  required String root,
  String? hidden,
  void Function(int done, int total)? onProgress,
}) async {
  final stage = Directory(p.join(root, 'restore_stage'));
  final keep = hidden == null ? null : Directory(hidden);
  try {
    for (final d in [stage, ?keep]) {
      if (await d.exists()) await d.delete(recursive: true);
      await d.create(recursive: true);
    }
    final m = await readBackupManifest(path, cipher);
    if ((m['v'] as int? ?? 99) > kBackupVersionHidden) {
      throw const RestoreError(RestoreFailure.newerVersion);
    }
    hiddenKeyOf(m);
    await extractBackup(
      path,
      cipher,
      want: (n) {
        final h = hiddenPart(n);
        if (h == null) return p.join(stage.path, n);
        return keep == null ? null : p.join(keep.path, h);
      },
      onProgress: onProgress,
    );
    // whole. now, and only now, the phone's own files go
    for (final folder in ['media', 'wallpapers']) {
      final d = Directory(p.join(root, folder));
      if (await d.exists()) await d.delete(recursive: true);
    }
    // a rollback journal left by the open database would be replayed
    // over the restored one on the next open
    for (final side in ['halo.db-journal', 'halo.db-wal', 'halo.db-shm']) {
      final f = File(p.join(root, side));
      if (await f.exists()) await f.delete();
    }
    final files = [
      for (final f in m['files'] as List)
        BackupFileEntry.fromJson(f as Map<String, dynamic>),
    ];
    for (final f in files) {
      if (hiddenPart(f.name) != null) continue;
      final dest = File(p.join(root, f.name));
      await dest.parent.create(recursive: true);
      await File(p.join(stage.path, f.name)).rename(dest.path);
    }
    return m;
  } catch (_) {
    try {
      if (keep != null && await keep.exists()) {
        await keep.delete(recursive: true);
      }
    } catch (_) {}
    rethrow;
  } finally {
    try {
      if (await stage.exists()) await stage.delete(recursive: true);
    } catch (_) {}
  }
}

// the key of hidden chats just restored, until the person chooses their PIN
String? _restoredKey;

/// a restore brought hidden chats: they wait for a hidden chats PIN
bool get restoredHidden => _restoredKey != null;

/// the hidden chats a restore brought, under the PIN the person chose. false
/// when that PIN is in use
Future<bool> sealRestoredHidden(LockState lock, String pin) async {
  final key = _restoredKey;
  if (key == null) throw StateError('no hidden chats to seal');
  if (!await lock.setupVaultPin(pin, key)) return false;
  _restoredKey = null;
  return true;
}

@visibleForTesting
void forgetRestoredHidden() => _restoredKey = null;

/// what a restore does to hidden chats here: they belonged to the account
/// being replaced, so their entry goes first and then their files. hidden
/// chats in the backup take their place in [into], the vault of the
/// identity restored, waiting in [from] until then, and are held for the
/// new hidden chats PIN the person chooses at the end
Future<void> landHidden(
  String docs,
  String? from,
  Map<String, dynamic> manifest, {
  required Future<void> Function() clearEntry,
  HaloContainer into = HaloContainer.vault,
}) async {
  _restoredKey = null;
  try {
    await clearEntry();
    await into.wipeFiles();
    final key = hiddenKeyOf(manifest);
    if (key == null || from == null) return;
    if (!await File(p.join(from, 'halo_v.db')).exists()) return;
    final c = into;
    for (final f in manifest['files'] as List) {
      final rest = hiddenPart((f as Map<String, dynamic>)['name'] as String);
      if (rest == null) continue;
      final String dest;
      if (rest == 'halo_v.db') {
        dest = await c.dbPath();
      } else {
        final cut = rest.indexOf('/');
        final folder = cut <= 0 ? '' : rest.substring(0, cut);
        if (folder != 'media' && folder != 'wallpapers') continue;
        dest = p.join(docs, '$folder${c.suffix}', rest.substring(cut + 1));
      }
      await File(dest).parent.create(recursive: true);
      await File(p.join(from, rest)).rename(dest);
    }
    _restoredKey = key;
  } finally {
    try {
      if (from != null && await Directory(from).exists()) {
        await Directory(from).delete(recursive: true);
      }
    } catch (_) {}
  }
}

// a restore in a decoy session lands on the decoy's names. the onion key
// waits in onion_d.key for the next start. no engine call: the engine
// carries the everyday identity
Future<void> _landInDecoy(
  String from,
  String docs,
  Map<String, dynamic> manifest,
) async {
  final c = HaloContainer.decoy;
  await session.primary.close();
  final dbPath = await c.dbPath();
  for (final f in [dbPath, '$dbPath-wal', '$dbPath-shm', '$dbPath-journal']) {
    try {
      await File(f).delete();
    } catch (_) {}
  }
  for (final folder in ['media', 'wallpapers']) {
    final d = Directory(p.join(docs, '$folder${c.suffix}'));
    if (await d.exists()) await d.delete(recursive: true);
  }
  for (final f in manifest['files'] as List) {
    final name = (f as Map<String, dynamic>)['name'] as String;
    // hidden chats landed in the decoy's vault already
    if (hiddenPart(name) != null) continue;
    final src = File(p.join(from, name));
    final String dest;
    if (name == 'halo.db') {
      dest = dbPath;
    } else if (name == 'onion.key') {
      dest = p.join(docs, 'onion${c.suffix}.key');
    } else {
      final slash = name.indexOf('/');
      dest = p.join(
        docs,
        '${name.substring(0, slash)}${c.suffix}',
        name.substring(slash + 1),
      );
    }
    await File(dest).parent.create(recursive: true);
    await src.rename(dest);
  }
  await _secureStorage.write(
    key: c.keyName!,
    value: manifest['dbPassphrase'] as String,
  );
  try {
    await Directory(from).delete(recursive: true);
  } catch (_) {}
  dlog('backup: restored into the decoy');
}

RestoreError _classify(Object e) {
  if (e is RestoreError) return e;
  if (e is BackupLocked) {
    return const RestoreError(RestoreFailure.wrongPassphrase);
  }
  return const RestoreError(RestoreFailure.damaged);
}

// how many chats and groups a hidden chats database holds
Future<int> _countHidden(String path, String key) async {
  final db = await openDatabase(path, password: "x'$key'", readOnly: true);
  try {
    final c = await db.rawQuery(
      'SELECT COUNT(*) c FROM contacts WHERE accepted = 1',
    );
    final g = await db.rawQuery('SELECT COUNT(*) c FROM groups');
    return ((c.first['c'] as int?) ?? 0) + ((g.first['c'] as int?) ?? 0);
  } finally {
    await db.close();
  }
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
  final peekHidden = p.join(dir.path, 'restore_peek_v.db');
  Map<String, dynamic> manifest;
  try {
    manifest =
        await _runJob(
              _inspectJob,
              _Job(
                passphrase: passphrase,
                salt: salt,
                path: path,
                root: peek,
                hidden: peekHidden,
              ),
            )
            as Map<String, dynamic>;
  } catch (e) {
    await shredFile(peek);
    await shredFile(peekHidden);
    throw _classify(e);
  }
  var contacts = 0;
  var messages = 0;
  int? hiddenChats;
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
    final key = hiddenKeyOf(manifest);
    if (key != null) hiddenChats = await _countHidden(peekHidden, key);
  } catch (_) {
    throw const RestoreError(RestoreFailure.damaged);
  } finally {
    await shredFile(peek);
    await shredFile(peekHidden);
  }
  final files = [
    for (final f in manifest['files'] as List)
      if (BackupFileEntry.fromJson(f as Map<String, dynamic>) case final e
          when e.name != kHiddenDb)
        e,
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
    hiddenChats: hiddenChats,
  );
}

/// brings a v2 file in. the files land under docs exactly where they came
/// from, then the secrets and prefs go where the app reads them. hidden
/// chats in it wait for their new PIN (restoredHidden). the app is expected
/// to exit afterwards and boot from what was written.
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
  // in a decoy session everything lands in the decoy's container, and the
  // everyday one is not touched
  final quiet = sessionQuiet;
  final root = quiet
      ? p.join((await getApplicationSupportDirectory()).path, 'restore_d')
      : docs.path;
  if (quiet) await Directory(root).create(recursive: true);
  final hidden = p.join(docs.path, 'restore_hidden');
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
                hidden: hidden,
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
  // the lock clears the vault entry of the session's own identity
  await landHidden(
    docs.path,
    hidden,
    manifest,
    clearEntry: lockState.clearVault,
    into: quiet ? HaloContainer.decoyVault : HaloContainer.vault,
  );
  if (quiet) return _landInDecoy(root, docs.path, manifest);
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
