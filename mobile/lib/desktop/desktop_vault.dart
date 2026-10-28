// SPDX-License-Identifier: GPL-3.0-or-later
// secure storage on desktop. there is no keystore: libsecret and dpapi hand
// a secret to any process of the same user. so everything the app keeps in
// secure storage (database keys, identity keys, settings) lives in one
// file sealed under a key made from a passphrase asked at every start:
// scrypt (n 2^17, r 8, p 1) to a key, an hmac of it with fresh bytes for
// every write, aes-256-gcm through the engine
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
import 'desktop_posix.dart' show syncFolder;

/// the shortest passphrase the desktop takes, in characters: as a backup
const kVaultMinLength = 12;

/// scrypt's cost: 128 MiB, about a third of a second on a desktop cpu and
/// under a second on a modest laptop
const kVaultLogN = 17;

const _magic = [0x4b, 0x52, 0x59, 0x56]; // KRYV
const _version = 3;

/// the file's size steps: how much is kept shows only to the nearest step
const kVaultBucket = 16 * 1024;
const _saltLen = 16;
const _freshLen = 32;
// magic, version, cost, salt, fresh bytes
const _head = 4 + 1 + 1 + _saltLen + _freshLen;
// the record type the seal binds
const _type = 0x56;

/// the cryptography, behind a seam so a test can run it on the host engine
abstract class VaultCrypto {
  /// 64 hex, or null when the engine refused
  Future<String?> keyOf(String passphrase, Uint8List salt, int logN);
  Uint8List seal(String keyHex, Uint8List plain);

  /// null when the key is wrong or a byte changed
  Uint8List? open(String keyHex, Uint8List sealed);
}

typedef _KeyC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Uint8>, Int32);
typedef _Key = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Uint8>, int);
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

String? _engineKey(String passphrase, Uint8List salt, int logN) {
  final fn = DynamicLibrary.process().lookupFunction<_KeyC, _Key>(
    'HaloVaultKey',
  );
  final pp = passphrase.toNativeUtf8();
  final ps = calloc<Uint8>(_saltLen);
  try {
    ps.asTypedList(_saltLen).setAll(0, salt);
    final r = engineTakeSecret(fn(pp, ps, logN));
    return r.startsWith('error') ? null : r;
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
  Future<String?> keyOf(String passphrase, Uint8List salt, int logN) =>
      Isolate.run(() => _engineKey(passphrase, salt, logN));

  static final _sealChunk = DynamicLibrary.process()
      .lookupFunction<_ChunkC, _Chunk>('HaloSealChunk');
  static final _openChunk = DynamicLibrary.process()
      .lookupFunction<_ChunkC, _Chunk>('HaloOpenChunk');

  Uint8List? _run(_Chunk call, String keyHex, Uint8List data) {
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
    final s = _run(_sealChunk, keyHex, plain);
    if (s == null || s.length != plain.length + 16) {
      throw StateError('seal failed');
    }
    return s;
  }

  @override
  Uint8List? open(String keyHex, Uint8List sealed) {
    if (sealed.length < 16) return null;
    return _run(_openChunk, keyHex, sealed);
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

/// [body] with its length in front and zeros after, so that [around] bytes
/// more make a whole number of steps
@visibleForTesting
Uint8List padded(List<int> body, int around) {
  final need = 4 + body.length + around;
  final total = (need + kVaultBucket - 1) ~/ kVaultBucket * kVaultBucket;
  final out = Uint8List(total - around);
  ByteData.sublistView(out).setUint32(0, body.length);
  out.setRange(4, 4 + body.length, body);
  return out;
}

/// what [padded] put in
@visibleForTesting
Uint8List unpadded(Uint8List p) {
  if (p.length < 4) throw const FormatException('short');
  final n = ByteData.sublistView(p).getUint32(0);
  if (4 + n > p.length) throw const FormatException('length');
  return Uint8List.sublistView(p, 4, 4 + n);
}

/// how the sealed bytes reach the disk, behind a seam so a test can make
/// a write fail as a full disk does
abstract class VaultDisk {
  /// [bytes] in place of [path], all or nothing, on the disk when it returns
  void replace(String path, Uint8List bytes);
}

/// a file written beside, flushed, renamed over, and its folder flushed so
/// the rename itself survives a cut
class RealVaultDisk implements VaultDisk {
  const RealVaultDisk();

  @override
  void replace(String path, Uint8List bytes) {
    final tmp = File('$path.new');
    try {
      final f = tmp.openSync(mode: FileMode.writeOnly);
      try {
        f.writeFromSync(bytes);
        f.flushSync();
      } finally {
        f.closeSync();
      }
      tmp.renameSync(path);
    } catch (_) {
      try {
        tmp.deleteSync();
      } catch (_) {}
      rethrow;
    }
    syncFolder(File(path).parent.path);
  }
}

// a change waiting for its write: seen by reads until it lands or fails
class _Change {
  _Change.put(this.key, this.value) : all = false;
  _Change.drop(this.key) : value = null, all = false;
  _Change.clear() : key = null, value = null, all = true;
  final String? key;
  final String? value;
  final bool all;

  void apply(Map<String, String> m) {
    if (all) {
      m.clear();
    } else if (value == null) {
      m.remove(key);
    } else {
      m[key!] = value!;
    }
  }
}

/// the sealed file and, once opened, what it holds
class DesktopVault {
  DesktopVault(
    this.path, {
    VaultCrypto? crypto,
    Random? random,
    VaultDisk? disk,
    this.logN = kVaultLogN,
  }) : _crypto = crypto ?? const EngineVaultCrypto(),
       _random = random ?? Random.secure(),
       _disk = disk ?? const RealVaultDisk();

  final String path;
  final int logN;
  final VaultCrypto _crypto;
  final Random _random;
  final VaultDisk _disk;

  Uint8List? _salt;
  int _cost = kVaultLogN;
  List<int>? _key;
  // what the file on disk holds
  Map<String, String>? _map;
  final _waiting = <_Change>[];
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
    final k = await _crypto.keyOf(passphrase, salt, logN);
    if (k == null) throw StateError('no key from the engine');
    _salt = salt;
    _cost = logN;
    _key = _unhex(k);
    _persist(const {});
    _map = {};
  }

  /// set by [open]: the file is none this version or an older one reads
  bool madeByOtherVersion = false;

  /// false for a wrong passphrase or a changed file. a file of an older
  /// version (1: no cost byte, scrypt 2^15; 2: no padding) opens and is
  /// written again as this one, at today's cost
  Future<bool> open(String passphrase) async {
    madeByOtherVersion = false;
    final raw = File(path).readAsBytesSync();
    if (raw.length < 5 || !listEquals(raw.sublist(0, 4), _magic)) {
      madeByOtherVersion = true;
      return false;
    }
    final version = raw[4];
    if (version < 1 || version > _version) {
      madeByOtherVersion = true;
      return false;
    }
    // where the salt starts and the head ends, by version
    final costAt = version >= 2 ? 5 : -1;
    final saltAt = version >= 2 ? 6 : 5;
    final head = saltAt + _saltLen + _freshLen;
    if (raw.length < head + 16) return false;
    final cost = costAt < 0 ? 15 : raw[costAt];
    final salt = Uint8List.fromList(raw.sublist(saltAt, saltAt + _saltLen));
    final fresh = raw.sublist(saltAt + _saltLen, head);
    final k = await _crypto.keyOf(passphrase, salt, cost);
    if (k == null) return false;
    final key = _unhex(k);
    final fileKey = _hex(Hmac(sha256, key).convert(fresh).bytes);
    final plain = _crypto.open(fileKey, Uint8List.fromList(raw.sublist(head)));
    if (plain == null) {
      key.fillRange(0, key.length, 0);
      return false;
    }
    final Object? m;
    try {
      m = jsonDecode(utf8.decode(version >= 3 ? unpadded(plain) : plain));
    } catch (_) {
      return false;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
    if (m is! Map) return false;
    _map = {
      for (final e in m.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
    if (version == _version && cost >= logN) {
      _salt = salt;
      _cost = cost;
      _key = key;
      return true;
    }
    // an older file: a new salt at today's cost, written as this version
    key.fillRange(0, key.length, 0);
    final newSalt = _bytes(_saltLen);
    final nk = await _crypto.keyOf(passphrase, newSalt, logN);
    if (nk == null) {
      _map = null;
      return false;
    }
    _salt = newSalt;
    _cost = logN;
    _key = _unhex(nk);
    _persist(_map!);
    return true;
  }

  /// the key goes from memory; the file stays
  void close() {
    final k = _key;
    if (k != null) k.fillRange(0, k.length, 0);
    _key = null;
    _map = null;
    _waiting.clear();
  }

  Map<String, String> get _held => _map ?? (throw const VaultLocked());

  // the file's state with every change still on its way
  Map<String, String> get _seen {
    final m = Map.of(_held);
    for (final c in _waiting) {
      c.apply(m);
    }
    return m;
  }

  String? read(String key) => _seen[key];
  Map<String, String> readAll() => _seen;
  bool containsKey(String key) => _seen.containsKey(key);

  Future<void> write(String key, String value) =>
      _queue(_Change.put(key, value));

  Future<void> delete(String key) => _queue(_Change.drop(key));

  Future<void> deleteAll() => _queue(_Change.clear());

  // one write at a time. a change shows in reads at once; one whose write
  // fails is taken back and its caller hears why, and the next write goes on
  Future<void> _queue(_Change c) {
    _held;
    _waiting.add(c);
    final done = _writes.catchError((_) {}).then((_) {
      try {
        final next = Map.of(_held);
        c.apply(next);
        _persist(next);
        _map = next;
      } finally {
        _waiting.remove(c);
      }
    });
    _writes = done;
    return done;
  }

  void _persist(Map<String, String> m) {
    final fresh = _bytes(_freshLen);
    final plain = padded(utf8.encode(jsonEncode(m)), _head + 16);
    final Uint8List sealed;
    try {
      sealed = _crypto.seal(_fileKey(fresh), plain);
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..addByte(_version)
      ..addByte(_cost)
      ..add(_salt!)
      ..add(fresh)
      ..add(sealed);
    _disk.replace(path, out.takeBytes());
  }

  /// the panic wipe: the file overwritten with random bytes and flushed
  /// before it goes. best effort: a journaling or copy-on-write disk, an
  /// ssd's remapping or a backup may still hold the old bytes
  void destroy() {
    close();
    for (final f in [File(path), File('$path.new')]) {
      try {
        final n = f.lengthSync();
        final r = f.openSync(mode: FileMode.writeOnlyAppend);
        try {
          r.setPositionSync(0);
          r.writeFromSync(_bytes(n));
          r.flushSync();
        } finally {
          r.closeSync();
        }
        f.deleteSync();
      } catch (_) {}
    }
    syncFolder(File(path).parent.path);
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
