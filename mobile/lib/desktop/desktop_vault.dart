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

import '../chunk_keys.dart';
import '../engine_strings.dart' show engineTakeSecretKey, freeSecret;
import 'desktop_posix.dart' show syncFolder;
import 'system_seal.dart';

/// in the vault while what the computer kept for it may still be there
const kVaultForgetOwed = 'kryfo.vault.forget';

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

/// the cryptography, behind a seam so a test can run it on the host engine.
/// keys are 32 bytes, never a string, so the vault can zero every copy it
/// holds once it is done with it
abstract class VaultCrypto {
  /// the key scrypt makes, or null when the engine refused. the caller
  /// zeroes it
  Future<Uint8List?> keyOf(String passphrase, Uint8List salt, int logN);
  Uint8List seal(Uint8List key, Uint8List plain);

  /// null when the key is wrong or a byte changed
  Uint8List? open(Uint8List key, Uint8List sealed);
}

typedef _KeyC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Uint8>, Int32);
typedef _Key = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Uint8>, int);

Uint8List? _engineKey(String passphrase, Uint8List salt, int logN) {
  final fn = DynamicLibrary.process().lookupFunction<_KeyC, _Key>(
    'HaloVaultKey',
  );
  final pp = passphrase.toNativeUtf8();
  final ps = calloc<Uint8>(_saltLen);
  try {
    ps.asTypedList(_saltLen).setAll(0, salt);
    return engineTakeSecretKey(fn(pp, ps, logN));
  } finally {
    freeSecret(pp);
    calloc.free(ps);
  }
}

/// the engine linked into the runner
class EngineVaultCrypto implements VaultCrypto {
  const EngineVaultCrypto();

  // scrypt takes a tenth of a second or so: never on the frame's thread.
  // the key comes back moved, not copied (Isolate.exit)
  @override
  Future<Uint8List?> keyOf(String passphrase, Uint8List salt, int logN) =>
      Isolate.run(() => _engineKey(passphrase, salt, logN));

  static final _keys = ChunkKeys(DynamicLibrary.process());

  // one seal or open: the key crosses as bytes, held by the engine for
  // this call alone
  Uint8List? _run(ChunkCall call, Uint8List key, Uint8List data) {
    if (key.length != 32) throw ArgumentError('key length');
    final h = _keys.take(key);
    if (h <= 0) return null;
    final cap = data.length + 16;
    final inp = calloc<Uint8>(cap), out = calloc<Uint8>(cap);
    try {
      inp.asTypedList(cap).setAll(0, data);
      final n = call(h, 0, _type, inp, data.length, out);
      if (n < 0 || n > cap) return null;
      return Uint8List.fromList(out.asTypedList(n));
    } finally {
      _keys.drop(h);
      inp.asTypedList(cap).fillRange(0, cap, 0);
      out.asTypedList(cap).fillRange(0, cap, 0);
      calloc.free(inp);
      calloc.free(out);
    }
  }

  @override
  Uint8List seal(Uint8List key, Uint8List plain) {
    final s = _run(_keys.seal, key, plain);
    if (s == null || s.length != plain.length + 16) {
      throw StateError('seal failed');
    }
    return s;
  }

  @override
  Uint8List? open(Uint8List key, Uint8List sealed) {
    if (sealed.length < 16) return null;
    return _run(_keys.open, key, sealed);
  }
}

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
/// computer account. [otherVersion]: neither this version nor an older one
/// reads the file (a newer version, or a cut head)
enum VaultLockKind { passphrase, system, otherVersion }

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
  Uint8List? _key;
  // what the file on disk holds
  Map<String, String>? _map;
  final _waiting = <_Change>[];
  Future<void> _writes = Future.value();

  bool get exists => File(path).existsSync();
  bool get isOpen => _map != null;

  /// what the file asks for, read from its head. null without a file. an
  /// older version (1 to 3) asks for its passphrase
  VaultLockKind? get lockKind {
    final Uint8List raw;
    try {
      raw = File(path).readAsBytesSync();
    } catch (_) {
      return null;
    }
    if (_isOlder(raw)) return VaultLockKind.passphrase;
    final h = _headOf(raw);
    if (h == null || h.length < 0) return VaultLockKind.otherVersion;
    if (h.slots.any((s) => s.kind == _slotPass)) {
      return VaultLockKind.passphrase;
    }
    if (h.slots.any((s) => s.kind == _slotSystem)) return VaultLockKind.system;
    return VaultLockKind.otherVersion;
  }

  static bool _isOlder(Uint8List raw) =>
      raw.length >= 5 &&
      listEquals(raw.sublist(0, 4), _magic) &&
      raw[4] >= 1 &&
      raw[4] < _version;

  /// open, and a passphrase is what opens it
  bool get hasPassphrase => _slots.any((s) => s.kind == _slotPass);

  // filled in place: no other list ever holds them
  Uint8List _bytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  // an hmac's bytes as they come, for the caller to zero. the hmac's own
  // padded copies of its key sit inside package:crypto, out of reach
  static Uint8List _mac(List<int> key, List<int> data) {
    final b = Hmac(sha256, key).convert(data).bytes;
    return b is Uint8List ? b : Uint8List.fromList(b);
  }

  static final _bodyLabel = utf8.encode('kryfo vault body');
  static final _slotLabel = utf8.encode('kryfo vault slot');

  // a key of its own for every write, bound to the whole head: a slot
  // swapped, added or dropped and the body no longer opens
  Uint8List _bodyKey(List<int> dk, List<int> head) =>
      _mac(dk, [..._bodyLabel, ...head]);

  Uint8List _wrapKey(List<int> kek, List<int> fresh) =>
      _mac(kek, [..._slotLabel, ...fresh]);

  Uint8List? _unwrap(List<int> kek, Uint8List fresh, Uint8List wrapped) {
    final w = _wrapKey(kek, fresh);
    final Uint8List? dk;
    try {
      dk = _crypto.open(w, wrapped);
    } finally {
      w.fillRange(0, w.length, 0);
    }
    if (dk == null) return null;
    if (dk.length != _dkLen) {
      dk.fillRange(0, dk.length, 0);
      return null;
    }
    return dk;
  }

  // [dk] sealed as it is: no copy of it made
  Uint8List _wrapped(List<int> kek, Uint8List fresh, Uint8List dk) {
    final k = _wrapKey(kek, fresh);
    try {
      return _crypto.seal(k, dk);
    } finally {
      k.fillRange(0, k.length, 0);
    }
  }

  _Slot _passSlot(List<int> kek, Uint8List salt, int cost, Uint8List dk) {
    final fresh = _bytes(_slotFreshLen);
    final w = _wrapped(kek, fresh, dk);
    return _Slot(
      _slotPass,
      Uint8List.fromList([cost, ...salt, ...fresh, ...w]),
    );
  }

  _Slot _systemSlot(SealedSecret s, List<int> sk, Uint8List dk) {
    final fresh = _bytes(_slotFreshLen);
    final w = _wrapped(sk, fresh, dk);
    return _Slot(
      _slotSystem,
      Uint8List.fromList([s.how, ...fresh, ...w, ...s.data]),
    );
  }

  // a passphrase to a key encryption key, at [cost]
  Future<Uint8List?> _kek(String passphrase, Uint8List salt, int cost) =>
      _crypto.keyOf(passphrase, salt, cost);

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
          await seal.forget(id);
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
    final bk = _bodyKey(dk, raw.sublist(0, h.length));
    final Uint8List? plain;
    try {
      plain = _crypto.open(bk, Uint8List.fromList(raw.sublist(h.length)));
    } finally {
      bk.fillRange(0, bk.length, 0);
    }
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
  Future<bool> open(String passphrase, {SystemSeal? seal}) async {
    final ok = await _openPass(passphrase);
    if (ok && seal != null) forgetting = _forgetOwed(seal);
    return ok;
  }

  Future<bool> _openPass(String passphrase) async {
    madeByOtherVersion = false;
    final raw = File(path).readAsBytesSync();
    if (_isOlder(raw)) return _openOlder(raw, passphrase);
    final h = _headOf(raw);
    if (h == null || h.length < 0) {
      madeByOtherVersion = true;
      return false;
    }
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
    if (h == null || h.length < 0) {
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
    final fileKey = _mac(key, fresh);
    key.fillRange(0, key.length, 0);
    final Uint8List? plain;
    try {
      plain = _crypto.open(fileKey, Uint8List.fromList(raw.sublist(head)));
    } finally {
      fileKey.fillRange(0, fileKey.length, 0);
    }
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
      await _rekey(
        (dk) => [_passSlot(kek, salt, logN, dk)],
        // what the computer kept is owed a clear until one lands
        owe: old.any((s) => s.kind == _slotSystem),
      );
    } finally {
      kek.fillRange(0, kek.length, 0);
    }
    if (seal != null) await _forgetOwed(seal);
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

  /// [passphrase] opens the vault now. nothing changes
  Future<bool> isPassphrase(String passphrase) => _isPassphrase(passphrase);

  /// [passphrase] opens a slot [rehearseAdd] made: the same work as
  /// [isPassphrase], against a slot of a decoy's own
  Future<bool> checkSlot(Uint8List slot, String passphrase) async {
    if (slot.length != 1 + _saltLen + _slotFreshLen + _wrappedLen) {
      return false;
    }
    final kek = await _kek(
      passphrase,
      Uint8List.sublistView(slot, 1, 1 + _saltLen),
      slot[0],
    );
    if (kek == null) return false;
    const at = 1 + _saltLen;
    final got = _unwrap(
      kek,
      Uint8List.sublistView(slot, at, at + _slotFreshLen),
      Uint8List.sublistView(slot, at + _slotFreshLen),
    );
    kek.fillRange(0, kek.length, 0);
    if (got == null) return false;
    got.fillRange(0, got.length, 0);
    return true;
  }

  /// a decoy session's [addPassphrase]: the same scrypt, wrap, sealed file
  /// and system lookup, in the same line as the writes, with nothing
  /// written, kept or cleared. the slot it made comes back for the decoy
  /// to keep in its own note
  Future<Uint8List> rehearseAdd(String passphrase, {SystemSeal? seal}) async {
    if (passphrase.runes.length < kVaultMinLength) {
      throw ArgumentError('passphrase too short');
    }
    if (_key == null) throw const VaultLocked();
    final salt = _bytes(_saltLen);
    final kek = await _kek(passphrase, salt, logN);
    if (kek == null) throw StateError('no key from the engine');
    final dk = _bytes(_dkLen);
    try {
      final slot = _passSlot(kek, salt, logN, dk);
      await _rehearseWrite(dk, [slot]);
      final id = _id;
      if (seal != null && id != null) {
        await seal.rehearse(id, keep: false);
        // the real one writes again once the clear landed
        await _rehearseWrite(dk, [slot]);
      }
      return slot.data;
    } finally {
      kek.fillRange(0, kek.length, 0);
      dk.fillRange(0, dk.length, 0);
    }
  }

  /// a decoy session's [removePassphrase] once the passphrase checked out:
  /// the seal's work and a sealed file, nothing kept or written. throws
  /// [SealError] where the real one would
  Future<void> rehearseRemove(SystemSeal seal) async {
    final id = _id;
    if (_key == null || id == null) throw const VaultLocked();
    final sk = _bytes(_dkLen);
    final dk = _bytes(_dkLen);
    try {
      final kept = await seal.rehearse(id, keep: true);
      await _rehearseWrite(dk, [
        _systemSlot(
          kept ?? SealedSecret(SealHow.keyring, Uint8List(0)),
          sk,
          dk,
        ),
      ]);
    } finally {
      sk.fillRange(0, sk.length, 0);
      dk.fillRange(0, dk.length, 0);
    }
  }

  // the file a write would make, sealed and let go, in the line of writes
  Future<void> _rehearseWrite(Uint8List dk, List<_Slot> slots) {
    _held;
    final done = _writes.catchError((_) {}).then((_) {
      _fileOf(Map.of(_held), slots, dk);
    });
    _writes = done;
    return done;
  }

  /// what the computer kept for this vault goes, by the vault's id and
  /// whatever its file says. best effort; the panic wipe's
  Future<void> forgetSystem(SystemSeal seal) async {
    final id = _id;
    if (id == null) return;
    try {
      await seal.forget(id);
    } catch (_) {}
  }

  // a clear that did not land (a locked keyring, a timeout, a cut between
  // the write and the clear) is tried again at the next passphrase open,
  // until one does
  Future<void> _forgetOwed(SystemSeal seal) async {
    final id = _id;
    if (id == null || _map?[kVaultForgetOwed] == null) return;
    try {
      if (await seal.forget(id) && isOpen) await delete(kVaultForgetOwed);
    } catch (_) {}
  }

  /// the clear owed after [open], for tests to wait on
  @visibleForTesting
  Future<void> forgetting = Future.value();

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
  Future<void> _rekey(
    List<_Slot> Function(Uint8List dk) slots, {
    bool owe = false,
  }) {
    _held;
    final done = _writes.catchError((_) {}).then((_) {
      final dk = _bytes(_dkLen);
      final List<_Slot> next;
      final m = Map.of(_held);
      if (owe) m[kVaultForgetOwed] = '1';
      try {
        next = slots(dk);
        _persist(m, next, dk);
      } catch (_) {
        dk.fillRange(0, dk.length, 0);
        rethrow;
      }
      final old = _key;
      _key = dk;
      _slots = next;
      _map = m;
      if (old != null && !identical(old, dk)) old.fillRange(0, old.length, 0);
    });
    _writes = done;
    return done;
  }

  void _persist(Map<String, String> m, List<_Slot> slots, [Uint8List? key]) =>
      _disk.replace(path, _fileOf(m, slots, key));

  // the whole file for [m] under [slots], sealed in memory
  Uint8List _fileOf(
    Map<String, String> m,
    List<_Slot> slots, [
    Uint8List? key,
  ]) {
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
    final bk = _bodyKey(dk, h);
    final Uint8List sealed;
    try {
      sealed = _crypto.seal(bk, plain);
    } finally {
      bk.fillRange(0, bk.length, 0);
      plain.fillRange(0, plain.length, 0);
    }
    return Uint8List.fromList([...h, ...sealed]);
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
