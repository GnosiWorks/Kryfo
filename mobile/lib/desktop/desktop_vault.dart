// SPDX-License-Identifier: GPL-3.0-or-later
// secure storage on desktop. there is no keystore: libsecret and dpapi hand
// a secret to any process of the same user. so everything the app keeps in
// secure storage (database keys, identity keys, settings) lives in one
// file sealed under a key made from a passphrase asked at every start:
// scrypt (n 2^15, r 8, p 1, the backups' cost) to a key, an hmac of it with
// fresh bytes for every write, aes-256-gcm through the engine
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

import '../engine_strings.dart' show engineTakeSecret, freeSecret;

/// the shortest passphrase the desktop takes, in characters: as a backup
const kVaultMinLength = 12;

const _magic = [0x4b, 0x52, 0x59, 0x56]; // KRYV
const _version = 1;
const _saltLen = 16;
const _freshLen = 32;
const _head = 4 + 1 + _saltLen + _freshLen;
// the record type the seal binds
const _type = 0x56;

/// the cryptography, behind a seam so a test can run it on the host engine
abstract class VaultCrypto {
  /// 64 hex, or null when the engine refused
  Future<String?> keyOf(String passphrase, Uint8List salt);
  Uint8List seal(String keyHex, Uint8List plain);

  /// null when the key is wrong or a byte changed
  Uint8List? open(String keyHex, Uint8List sealed);
}

typedef _KeyC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Uint8>);
typedef _ChunkC =
    Int32 Function(
      Pointer<Utf8>,
      Uint64,
      Uint8,
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
    );
typedef _Chunk =
    int Function(Pointer<Utf8>, int, int, Pointer<Uint8>, int, Pointer<Uint8>);

String? _engineKey(String passphrase, Uint8List salt) {
  final fn = DynamicLibrary.process().lookupFunction<_KeyC, _KeyC>(
    'HaloBackupKey',
  );
  final pp = passphrase.toNativeUtf8();
  final ps = calloc<Uint8>(_saltLen);
  try {
    ps.asTypedList(_saltLen).setAll(0, salt);
    final r = engineTakeSecret(fn(pp, ps));
    return r.startsWith('error:') ? null : r;
  } finally {
    freeSecret(pp);
    calloc.free(ps);
  }
}

/// the engine linked into the runner
class EngineVaultCrypto implements VaultCrypto {
  const EngineVaultCrypto();

  // scrypt takes a tenth of a second or so: never on the frame's thread
  @override
  Future<String?> keyOf(String passphrase, Uint8List salt) =>
      Isolate.run(() => _engineKey(passphrase, salt));

  Uint8List? _run(String fn, String keyHex, Uint8List data) {
    final call = DynamicLibrary.process().lookupFunction<_ChunkC, _Chunk>(fn);
    final k = keyHex.toNativeUtf8();
    final cap = data.length + 16;
    final inp = calloc<Uint8>(cap), out = calloc<Uint8>(cap);
    try {
      inp.asTypedList(cap).setAll(0, data);
      final n = call(k, 0, _type, inp, data.length, out);
      if (n < 0 || n > cap) return null;
      return Uint8List.fromList(out.asTypedList(n));
    } finally {
      inp.asTypedList(cap).fillRange(0, cap, 0);
      out.asTypedList(cap).fillRange(0, cap, 0);
      calloc.free(inp);
      calloc.free(out);
      freeSecret(k);
    }
  }

  @override
  Uint8List seal(String keyHex, Uint8List plain) {
    final s = _run('HaloSealChunk', keyHex, plain);
    if (s == null || s.length != plain.length + 16) {
      throw StateError('seal failed');
    }
    return s;
  }

  @override
  Uint8List? open(String keyHex, Uint8List sealed) {
    if (sealed.length < 16) return null;
    return _run('HaloOpenChunk', keyHex, sealed);
  }
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String h) => [
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
];

class VaultLocked implements Exception {
  const VaultLocked();
  @override
  String toString() => 'VaultLocked';
}

/// the sealed file and, once opened, what it holds
class DesktopVault {
  DesktopVault(this.path, {VaultCrypto? crypto, Random? random})
    : _crypto = crypto ?? const EngineVaultCrypto(),
      _random = random ?? Random.secure();

  final String path;
  final VaultCrypto _crypto;
  final Random _random;

  Uint8List? _salt;
  List<int>? _key;
  Map<String, String>? _map;
  Future<void> _writes = Future.value();

  bool get exists => File(path).existsSync();
  bool get isOpen => _map != null;

  Uint8List _bytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  // a key of its own for every write, so no two seals share key and nonce
  String _fileKey(List<int> fresh) =>
      _hex(Hmac(sha256, _key!).convert(fresh).bytes);

  /// a new file under [passphrase]. never over one that is there
  Future<void> create(String passphrase) async {
    if (exists) throw StateError('a vault is already there');
    if (passphrase.runes.length < kVaultMinLength) {
      throw ArgumentError('passphrase too short');
    }
    final salt = _bytes(_saltLen);
    final k = await _crypto.keyOf(passphrase, salt);
    if (k == null) throw StateError('no key from the engine');
    _salt = salt;
    _key = _unhex(k);
    _map = {};
    await _persist();
  }

  /// false for a wrong passphrase or a changed file
  Future<bool> open(String passphrase) async {
    final raw = File(path).readAsBytesSync();
    if (raw.length < _head + 16 ||
        !listEquals(raw.sublist(0, 4), _magic) ||
        raw[4] != _version) {
      return false;
    }
    final salt = Uint8List.fromList(raw.sublist(5, 5 + _saltLen));
    final fresh = raw.sublist(5 + _saltLen, _head);
    final k = await _crypto.keyOf(passphrase, salt);
    if (k == null) return false;
    final key = _unhex(k);
    final fileKey = _hex(Hmac(sha256, key).convert(fresh).bytes);
    final plain = _crypto.open(fileKey, Uint8List.fromList(raw.sublist(_head)));
    if (plain == null) return false;
    final Object? m;
    try {
      m = jsonDecode(utf8.decode(plain));
    } catch (_) {
      return false;
    }
    if (m is! Map) return false;
    _salt = salt;
    _key = key;
    _map = {
      for (final e in m.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
    return true;
  }

  /// the key goes from memory; the file stays
  void close() {
    final k = _key;
    if (k != null) k.fillRange(0, k.length, 0);
    _key = null;
    _map = null;
  }

  Map<String, String> get _held => _map ?? (throw const VaultLocked());

  String? read(String key) => _held[key];
  Map<String, String> readAll() => Map.of(_held);
  bool containsKey(String key) => _held.containsKey(key);

  Future<void> write(String key, String value) {
    _held[key] = value;
    return _queue();
  }

  Future<void> delete(String key) {
    if (_held.remove(key) == null) return _writes;
    return _queue();
  }

  Future<void> deleteAll() {
    _held.clear();
    return _queue();
  }

  // one write at a time, each with what is held when it runs
  Future<void> _queue() => _writes = _writes.then((_) => _persist());

  Future<void> _persist() async {
    final fresh = _bytes(_freshLen);
    final sealed = _crypto.seal(
      _fileKey(fresh),
      Uint8List.fromList(utf8.encode(jsonEncode(_held))),
    );
    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..addByte(_version)
      ..add(_salt!)
      ..add(fresh)
      ..add(sealed);
    // a new file renamed over the old: a cut never leaves half a vault
    final tmp = File('$path.new');
    final f = tmp.openSync(mode: FileMode.writeOnly);
    try {
      f.writeFromSync(out.takeBytes());
      f.flushSync();
    } finally {
      f.closeSync();
    }
    tmp.renameSync(path);
  }
}

/// flutter_secure_storage's calls, answered by the vault
class VaultStorage extends FlutterSecureStoragePlatform {
  VaultStorage(this.vault);
  final DesktopVault vault;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) => vault.write(key, value);

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => vault.read(key);

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => vault.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) => vault.delete(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => vault.readAll();

  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      vault.deleteAll();
}
