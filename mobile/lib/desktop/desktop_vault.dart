// SPDX-License-Identifier: GPL-3.0-or-later
// secure storage on desktop. everything the app keeps in secure storage
// (database keys, identity keys, settings) lives in one file sealed under a
// random data key, aes-256-gcm through the engine with a key of its own for
// every write. the data key is kept by the computer account (the system
// keyring, dpapi), or wrapped under a passphrase asked at every start:
// scrypt (n 2^17, r 8, p 1)
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
import 'system_seal.dart';

/// the shortest passphrase the desktop takes, in characters: as a backup
const kVaultMinLength = 12;

/// scrypt's cost: 128 MiB, about a third of a second on a desktop cpu and
/// under a second on a modest laptop
const kVaultLogN = 17;

const _magic = [0x4b, 0x52, 0x59, 0x56]; // KRYV
const _version = 4;

/// the file's size steps: how much is kept shows only to the nearest step
const kVaultBucket = 16 * 1024;
const _saltLen = 16;
const _freshLen = 32;
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

/// how the vault's data key is kept: under a passphrase, or by the
/// computer account
enum VaultLockKind { passphrase, system }

/// what [DesktopVault.openSealed] found
enum SealedOpen { opened, missing, unreachable, otherVersion }

// one way to the data key, as written in the file's head
class _Slot {
  const _Slot(this.kind, this.data);
  final int kind;
  final Uint8List data;
}

const _slotPass = 1;
const _slotSystem = 2;
const _idLen = 16;
const _slotFreshLen = 16;
const _dkLen = 32;
const _wrappedLen = _dkLen + 16;

// the head of a version 4 file, read without any key
class _Head {
  const _Head(this.id, this.slots, this.length);
  final Uint8List id;
  final List<_Slot> slots;
  final int length;
}

/// the sealed file and, once opened, what it holds. version 4: a random
/// data key seals the body; the head holds that key wrapped once, under a
/// passphrase or under a secret the computer account keeps
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

  // not secret: both are in the file's head. kept after close so a wipe
  // can still find what the system keeps
  Uint8List? _id;
  List<_Slot> _slots = const [];
  // the data key
  List<int>? _key;
  // what the file on disk holds
  Map<String, String>? _map;
  final _waiting = <_Change>[];
  Future<void> _writes = Future.value();

  bool get exists => File(path).existsSync();
  bool get isOpen => _map != null;

  /// what the file asks for, read from its head. null without a file. a
  /// file of an older or unknown version asks for a passphrase: [open]
  /// tells which
  VaultLockKind? get lockKind {
    final Uint8List raw;
    try {
      raw = File(path).readAsBytesSync();
    } catch (_) {
      return null;
    }
    final h = _headOf(raw);
    if (h == null) return VaultLockKind.passphrase;
    return h.slots.any((s) => s.kind == _slotPass) || h.slots.isEmpty
        ? VaultLockKind.passphrase
        : VaultLockKind.system;
  }

  /// open, and a passphrase is what opens it
  bool get hasPassphrase => _slots.any((s) => s.kind == _slotPass);

  Uint8List _bytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  static final _bodyLabel = utf8.encode('kryfo vault body');
  static final _slotLabel = utf8.encode('kryfo vault slot');

  // a key of its own for every write, bound to the whole head: a slot
  // swapped, added or dropped and the body no longer opens
  String _bodyKey(List<int> dk, List<int> head) =>
      _hex(Hmac(sha256, dk).convert([..._bodyLabel, ...head]).bytes);

  String _wrapKey(List<int> kek, List<int> fresh) =>
      _hex(Hmac(sha256, kek).convert([..._slotLabel, ...fresh]).bytes);

  Uint8List? _unwrap(List<int> kek, Uint8List fresh, Uint8List wrapped) {
    final dk = _crypto.open(_wrapKey(kek, fresh), wrapped);
    if (dk == null) return null;
    if (dk.length != _dkLen) {
      dk.fillRange(0, dk.length, 0);
      return null;
    }
    return dk;
  }

  _Slot _passSlot(List<int> kek, Uint8List salt, int cost, List<int> dk) {
    final fresh = _bytes(_slotFreshLen);
    final w = _crypto.seal(_wrapKey(kek, fresh), Uint8List.fromList(dk));
    return _Slot(
      _slotPass,
      Uint8List.fromList([cost, ...salt, ...fresh, ...w]),
    );
  }

  _Slot _systemSlot(SealedSecret s, List<int> sk, List<int> dk) {
    final fresh = _bytes(_slotFreshLen);
    final w = _crypto.seal(_wrapKey(sk, fresh), Uint8List.fromList(dk));
    return _Slot(
      _slotSystem,
      Uint8List.fromList([s.how, ...fresh, ...w, ...s.data]),
    );
  }

  // a passphrase to a key encryption key, at [cost]
  Future<List<int>?> _kek(String passphrase, Uint8List salt, int cost) async {
    final k = await _crypto.keyOf(passphrase, salt, cost);
    return k == null ? null : _unhex(k);
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }

  /// a new file under [passphrase]. never over one that is there
  Future<void> create(String passphrase) async {
    if (exists) throw StateError('a vault is already there');
    if (passphrase.runes.length < kVaultMinLength) {
      throw ArgumentError('passphrase too short');
    }
    final salt = _bytes(_saltLen);
    final kek = await _kek(passphrase, salt, logN);
    if (kek == null) throw StateError('no key from the engine');
    final dk = _bytes(_dkLen);
    final slot = _passSlot(kek, salt, logN, dk);
    kek.fillRange(0, kek.length, 0);
    _start(_bytes(_idLen), dk, [slot]);
  }

  /// a new file whose data key the computer account keeps. throws
  /// [SealError] when [seal] keeps nothing
  Future<void> createSealed(SystemSeal seal) async {
    if (exists) throw StateError('a vault is already there');
    final id = _bytes(_idLen);
    final sk = _bytes(_dkLen);
    final dk = _bytes(_dkLen);
    try {
      final kept = await seal.keep(id, sk);
      try {
        _start(id, dk, [_systemSlot(kept, sk, dk)]);
      } catch (_) {
        // no file to need it: the keyring keeps nothing of a vault not made
        try {
          await seal.forget(id, kept.how, kept.data);
        } catch (_) {}
        rethrow;
      }
    } finally {
      sk.fillRange(0, sk.length, 0);
    }
  }

  void _start(Uint8List id, Uint8List dk, List<_Slot> slots) {
    _id = id;
    _key = dk;
    try {
      _persist(const {}, slots);
    } catch (_) {
      _key = null;
      dk.fillRange(0, dk.length, 0);
      rethrow;
    }
    _slots = slots;
    _map = {};
  }

  /// set by [open]: the file is none this version or an older one reads
  bool madeByOtherVersion = false;

  // null: not a vault of this version. throws for a cut head
  _Head? _headOf(Uint8List raw) {
    if (raw.length < 5 || !listEquals(raw.sublist(0, 4), _magic)) return null;
    if (raw[4] != _version) return null;
    var at = 5;
    Uint8List take(int n) {
      if (at + n > raw.length) throw const FormatException('cut');
      final b = Uint8List.fromList(raw.sublist(at, at + n));
      at += n;
      return b;
    }

    try {
      final id = take(_idLen);
      final n = take(1)[0];
      final slots = <_Slot>[];
      for (var i = 0; i < n; i++) {
        final kind = take(1)[0];
        final len = ByteData.sublistView(take(2)).getUint16(0);
        slots.add(_Slot(kind, take(len)));
      }
      take(_freshLen);
      return _Head(id, slots, at);
    } on FormatException {
      return _Head(Uint8List(0), const [], -1);
    }
  }

  bool _openBody(Uint8List raw, _Head h, Uint8List dk) {
    final plain = _crypto.open(
      _bodyKey(dk, raw.sublist(0, h.length)),
      Uint8List.fromList(raw.sublist(h.length)),
    );
    if (plain == null) {
      dk.fillRange(0, dk.length, 0);
      return false;
    }
    final Object? m;
    try {
      m = jsonDecode(utf8.decode(unpadded(plain)));
    } catch (_) {
      dk.fillRange(0, dk.length, 0);
      return false;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
    if (m is! Map) {
      dk.fillRange(0, dk.length, 0);
      return false;
    }
    _id = h.id;
    _slots = h.slots;
    _key = dk;
    _map = _stringsOf(m);
    return true;
  }

  static Map<String, String> _stringsOf(Map m) => {
    for (final e in m.entries)
      if (e.key is String && e.value is String)
        e.key as String: e.value as String,
  };

  /// false for a wrong passphrase, a changed file or one the computer
  /// keeps. a file of an older version (1 to 3: sealed straight under the
  /// passphrase) opens and is written again as this one
  Future<bool> open(String passphrase) async {
    madeByOtherVersion = false;
    final raw = File(path).readAsBytesSync();
    if (raw.length >= 5 &&
        listEquals(raw.sublist(0, 4), _magic) &&
        raw[4] >= 1 &&
        raw[4] < _version) {
      return _openOlder(raw, passphrase);
    }
    final h = _headOf(raw);
    if (h == null) {
      madeByOtherVersion = true;
      return false;
    }
    if (h.length < 0) return false;
    for (final s in h.slots) {
      if (s.kind != _slotPass || s.data.length != 1 + _saltLen + 16 + 48) {
        continue;
      }
      final d = s.data;
      final kek = await _kek(
        passphrase,
        Uint8List.sublistView(d, 1, 1 + _saltLen),
        d[0],
      );
      if (kek == null) return false;
      final at = 1 + _saltLen;
      final dk = _unwrap(
        kek,
        Uint8List.sublistView(d, at, at + _slotFreshLen),
        Uint8List.sublistView(d, at + _slotFreshLen),
      );
      kek.fillRange(0, kek.length, 0);
      if (dk == null) return false;
      return _openBody(raw, h, dk);
    }
    return false;
  }

  /// opens with what the computer account keeps, asking nothing
  Future<SealedOpen> openSealed(SystemSeal seal) async {
    madeByOtherVersion = false;
    final raw = File(path).readAsBytesSync();
    final h = _headOf(raw);
    if (h == null) {
      madeByOtherVersion = true;
      return SealedOpen.otherVersion;
    }
    for (final s in h.slots) {
      final d = s.data;
      if (s.kind != _slotSystem || d.length < 1 + _slotFreshLen + _wrappedLen) {
        continue;
      }
      final Uint8List sk;
      try {
        sk = await seal.fetch(
          h.id,
          d[0],
          Uint8List.sublistView(d, 1 + _slotFreshLen + _wrappedLen),
        );
      } on SealError catch (e) {
        return e.why == SealFail.unreachable
            ? SealedOpen.unreachable
            : SealedOpen.missing;
      }
      final dk = _unwrap(
        sk,
        Uint8List.sublistView(d, 1, 1 + _slotFreshLen),
        Uint8List.sublistView(
          d,
          1 + _slotFreshLen,
          1 + _slotFreshLen + _wrappedLen,
        ),
      );
      sk.fillRange(0, sk.length, 0);
      // another secret under the same name: as good as none
      if (dk == null) return SealedOpen.missing;
      return _openBody(raw, h, dk) ? SealedOpen.opened : SealedOpen.missing;
    }
    return SealedOpen.missing;
  }

  // versions 1 (no cost byte, scrypt 2^15), 2 (no padding) and 3
  Future<bool> _openOlder(Uint8List raw, String passphrase) async {
    final version = raw[4];
    final costAt = version >= 2 ? 5 : -1;
    final saltAt = version >= 2 ? 6 : 5;
    final head = saltAt + _saltLen + _freshLen;
    if (raw.length < head + 16) return false;
    final cost = costAt < 0 ? 15 : raw[costAt];
    final salt = Uint8List.fromList(raw.sublist(saltAt, saltAt + _saltLen));
    final fresh = raw.sublist(saltAt + _saltLen, head);
    final key = await _kek(passphrase, salt, cost);
    if (key == null) return false;
    final fileKey = _hex(Hmac(sha256, key).convert(fresh).bytes);
    key.fillRange(0, key.length, 0);
    final plain = _crypto.open(fileKey, Uint8List.fromList(raw.sublist(head)));
    if (plain == null) return false;
    final Object? m;
    try {
      m = jsonDecode(utf8.decode(version >= 3 ? unpadded(plain) : plain));
    } catch (_) {
      return false;
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
    if (m is! Map) return false;
    // written again as this version: a new data key under a new salt at
    // today's cost
    final newSalt = _bytes(_saltLen);
    final kek = await _kek(passphrase, newSalt, logN);
    if (kek == null) return false;
    final dk = _bytes(_dkLen);
    final slot = _passSlot(kek, newSalt, logN, dk);
    kek.fillRange(0, kek.length, 0);
    _id = _bytes(_idLen);
    _key = dk;
    _map = _stringsOf(m);
    try {
      _persist(_map!, [slot]);
    } catch (_) {
      // not written as this version: nothing of it stays open in memory
      close();
      rethrow;
    }
    _slots = [slot];
    return true;
  }

  // the open vault's passphrase is [passphrase]
  Future<bool> _isPassphrase(String passphrase) async {
    final dk = _key;
    if (dk == null) throw const VaultLocked();
    for (final s in _slots) {
      if (s.kind != _slotPass) continue;
      final d = s.data;
      final kek = await _kek(
        passphrase,
        Uint8List.sublistView(d, 1, 1 + _saltLen),
        d[0],
      );
      if (kek == null) return false;
      final at = 1 + _saltLen;
      final got = _unwrap(
        kek,
        Uint8List.sublistView(d, at, at + _slotFreshLen),
        Uint8List.sublistView(d, at + _slotFreshLen),
      );
      kek.fillRange(0, kek.length, 0);
      if (got == null) return false;
      final same = _sameBytes(got, dk);
      got.fillRange(0, got.length, 0);
      return same;
    }
    return false;
  }

  /// from now on [passphrase] opens the vault, and only it, under a new
  /// data key. what the computer kept goes once the file no longer needs it
  Future<void> addPassphrase(String passphrase, {SystemSeal? seal}) async {
    if (passphrase.runes.length < kVaultMinLength) {
      throw ArgumentError('passphrase too short');
    }
    if (_key == null) throw const VaultLocked();
    final old = _slots;
    final salt = _bytes(_saltLen);
    final kek = await _kek(passphrase, salt, logN);
    if (kek == null) throw StateError('no key from the engine');
    try {
      await _rekey((dk) => [_passSlot(kek, salt, logN, dk)]);
    } finally {
      kek.fillRange(0, kek.length, 0);
    }
    if (seal != null) await _forget(seal, old);
  }

  /// false when [current] is not the passphrase
  Future<bool> changePassphrase(String current, String next) async {
    if (next.runes.length < kVaultMinLength) {
      throw ArgumentError('passphrase too short');
    }
    if (!await _isPassphrase(current)) return false;
    await addPassphrase(next);
    return true;
  }

  /// the computer account keeps the key from now on. false when [current]
  /// is not the passphrase; throws [SealError] when [seal] keeps nothing,
  /// and the passphrase then stays
  Future<bool> removePassphrase(String current, SystemSeal seal) async {
    if (!await _isPassphrase(current)) return false;
    if (_key == null) throw const VaultLocked();
    final sk = _bytes(_dkLen);
    try {
      final kept = await seal.keep(_id!, sk);
      await _rekey((dk) => [_systemSlot(kept, sk, dk)]);
    } finally {
      sk.fillRange(0, sk.length, 0);
    }
    return true;
  }

  /// what the computer kept for this vault goes. best effort
  Future<void> forgetSystem(SystemSeal seal) => _forget(seal, _slots);

  Future<void> _forget(SystemSeal seal, List<_Slot> slots) async {
    final id = _id;
    if (id == null) return;
    for (final s in slots) {
      final d = s.data;
      if (s.kind != _slotSystem || d.isEmpty) continue;
      try {
        await seal.forget(
          id,
          d[0],
          d.length < 1 + _slotFreshLen + _wrappedLen
              ? Uint8List(0)
              : Uint8List.sublistView(d, 1 + _slotFreshLen + _wrappedLen),
        );
      } catch (_) {}
    }
  }

  /// the key goes from memory; the file stays
  void close() {
    final k = _key;
    if (k != null) k.fillRange(0, k.length, 0);
    _key = null;
    // dart strings cannot be zeroed: the map is emptied and let go
    _map?.clear();
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
        _persist(next, _slots);
        _map = next;
      } finally {
        _waiting.remove(c);
      }
    });
    _writes = done;
    return done;
  }

  // a new head under a new data key, in the same line as the writes: an
  // older copy of the file, with what opened it, opens only itself. the
  // old key goes once the write landed; a failed write keeps it
  Future<void> _rekey(List<_Slot> Function(Uint8List dk) slots) {
    _held;
    final done = _writes.catchError((_) {}).then((_) {
      final dk = _bytes(_dkLen);
      final List<_Slot> next;
      try {
        next = slots(dk);
        _persist(Map.of(_held), next, dk);
      } catch (_) {
        dk.fillRange(0, dk.length, 0);
        rethrow;
      }
      final old = _key;
      _key = dk;
      _slots = next;
      if (old != null && !identical(old, dk)) old.fillRange(0, old.length, 0);
    });
    _writes = done;
    return done;
  }

  void _persist(Map<String, String> m, List<_Slot> slots, [List<int>? key]) {
    final dk = key ?? _key ?? (throw const VaultLocked());
    final head = BytesBuilder(copy: false)
      ..add(_magic)
      ..addByte(_version)
      ..add(_id!)
      ..addByte(slots.length);
    for (final s in slots) {
      head
        ..addByte(s.kind)
        ..addByte(s.data.length >> 8)
        ..addByte(s.data.length & 0xff)
        ..add(s.data);
    }
    head.add(_bytes(_freshLen));
    final h = head.takeBytes();
    final plain = padded(utf8.encode(jsonEncode(m)), h.length + 16);
    final Uint8List sealed;
    try {
      sealed = _crypto.seal(_bodyKey(dk, h), plain);
    } finally {
      plain.fillRange(0, plain.length, 0);
    }
    _disk.replace(path, Uint8List.fromList([...h, ...sealed]));
  }

  /// the panic wipe: the file overwritten with random bytes and flushed
  /// before it goes. best effort: a journaling or copy-on-write disk, an
  /// ssd's remapping or a backup may still hold the old bytes.
  /// [forgetSystem] after it takes what the computer kept
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
