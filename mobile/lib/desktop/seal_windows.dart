// SPDX-License-Identifier: GPL-3.0-or-later
// the vault's system secret on windows: dpapi under the user's account,
// and inside it a per-user tpm key's wrap when the platform crypto
// provider works. all through dart:ffi, no runner code
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'system_seal.dart';

/// a failed ncrypt call, with its status
class WinCryptError implements Exception {
  const WinCryptError(this.status);
  final int status;

  /// the tpm key is not there or no longer loads: gone for good. a cleared
  /// tpm keeps the key file but refuses to load it under its new root, with
  /// a TPM_E or TPM_20_E status. only the tpm's own wait, retry and lockout
  /// warnings and the tpm service (tbs) not answering may pass. unverified
  /// until a Clear TPM test on a pc
  bool get keyGone {
    final s = status & 0xffffffff;
    if (_gone.contains(s)) return true;
    if (s >> 16 != 0x8028) return false;
    // tpm 1.2 non-fatal (0x800) and tpm 2.0 warnings (0x900, format zero,
    // so bit 7 clear): busy, retry, lockout, self test, memory, nv rate
    final low = s & 0xfff;
    if (low >= 0x800 && low <= 0x87f || low >= 0x900 && low <= 0x97f) {
      return false;
    }
    // TBS_E: the tpm base service not running or not ready
    if (s >= 0x80284000 && s <= 0x80284fff) return false;
    return true;
  }

  @override
  String toString() => 'WinCryptError(0x${status.toRadixString(16)})';
}

// NTE_BAD_KEYSET, NTE_NOT_FOUND, NTE_NO_KEY, NTE_BAD_KEY, NTE_BAD_DATA:
// the key is not there, or its blob does not match what is
const _gone = {0x80090016, 0x80090011, 0x8009000D, 0x80090003, 0x80090005};

/// crypt32 and ncrypt's few calls, behind a seam for tests. every call
/// blocks; the tpm's key making can take seconds
abstract class WinCrypt {
  /// null when dpapi refused
  Uint8List? protect(Uint8List data, Uint8List entropy);

  /// null when the blob is not this account's, or was changed
  Uint8List? unprotect(Uint8List blob, Uint8List entropy);

  /// the platform crypto provider opens: there is a tpm to use
  bool tpmThere();

  /// a new key [name] (one there is replaced) and [secret] under it.
  /// throws [WinCryptError]
  Uint8List tpmWrap(String name, Uint8List secret);

  /// throws [WinCryptError]
  Uint8List tpmUnwrap(String name, Uint8List wrapped);

  /// the key [name] goes. true when there is none left
  bool tpmDelete(String name);
}

class WindowsSeal implements SystemSeal {
  WindowsSeal(this.api, {SealRunner? run}) : _run = run ?? offThread;

  final WinCrypt api;
  final SealRunner _run;

  @override
  SealPlace get place => SealPlace.windows;

  static String _name(Uint8List id) => 'Kryfo vault ${hexOf(id)}';
  static Uint8List _entropy(Uint8List id) =>
      Uint8List.fromList(utf8.encode('kryfo vault ${hexOf(id)}'));

  // dpapi is part of every windows account
  @override
  Future<bool> works() async => true;

  @override
  Future<SealedSecret> keep(Uint8List id, Uint8List secret) async {
    final api = this.api;
    // a copy of its own goes to the worker, zeroed there and here: the
    // caller's stays as it was
    final s = Uint8List.fromList(secret);
    try {
      return await _run(() {
        try {
          return _keep(api, id, s);
        } finally {
          s.fillRange(0, s.length, 0);
        }
      });
    } finally {
      s.fillRange(0, s.length, 0);
    }
  }

  static SealedSecret _keep(WinCrypt api, Uint8List id, Uint8List secret) {
    var how = SealHow.dpapi;
    var inner = secret;
    if (api.tpmThere()) {
      try {
        inner = api.tpmWrap(_name(id), secret);
        how = SealHow.tpm;
      } catch (_) {
        // a tpm that will not make or use a key: dpapi alone
        api.tpmDelete(_name(id));
      }
    }
    final blob = api.protect(inner, _entropy(id));
    if (blob == null) {
      if (how == SealHow.tpm) api.tpmDelete(_name(id));
      throw const SealError(SealFail.refused);
    }
    return SealedSecret(how, blob);
  }

  @override
  Future<Uint8List> fetch(Uint8List id, int how, Uint8List data) async {
    if (how != SealHow.dpapi && how != SealHow.tpm) {
      throw const SealError(SealFail.missing);
    }
    final api = this.api;
    return _run(() {
      final inner = api.unprotect(data, _entropy(id));
      // another account, another computer, or a reset password
      if (inner == null) throw const SealError(SealFail.missing);
      if (how == SealHow.dpapi) {
        if (inner.length != 32) {
          inner.fillRange(0, inner.length, 0);
          throw const SealError(SealFail.missing);
        }
        return inner;
      }
      try {
        final s = api.tpmUnwrap(_name(id), inner);
        if (s.length != 32) {
          s.fillRange(0, s.length, 0);
          throw const SealError(SealFail.missing);
        }
        return s;
      } on WinCryptError catch (e) {
        // gone stays gone; a busy or locked out tpm may answer later
        throw SealError(e.keyGone ? SealFail.missing : SealFail.unreachable);
      } finally {
        inner.fillRange(0, inner.length, 0);
      }
    });
  }

  // the dpapi blob lives in the vault's file; only a tpm key stays behind.
  // opened silently, so nothing asks
  @override
  Future<bool> forget(Uint8List id) async {
    final api = this.api;
    final name = _name(id);
    // no platform crypto provider: no tpm key was ever made
    return _run(() => !api.tpmThere() || api.tpmDelete(name));
  }
}

final class _Blob extends Struct {
  @Uint32()
  external int size;
  external Pointer<Uint8> data;
}

final class _Oaep extends Struct {
  external Pointer<Utf16> alg;
  external Pointer<Uint8> label;
  @Uint32()
  external int labelSize;
}

typedef _ProtectC =
    Int32 Function(
      Pointer<_Blob>,
      Pointer<Utf16>,
      Pointer<_Blob>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_Blob>,
    );
typedef _Protect =
    int Function(
      Pointer<_Blob>,
      Pointer<Utf16>,
      Pointer<_Blob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_Blob>,
    );
typedef _UnprotectC =
    Int32 Function(
      Pointer<_Blob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_Blob>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_Blob>,
    );
typedef _Unprotect =
    int Function(
      Pointer<_Blob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_Blob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_Blob>,
    );
typedef _LocalFreeC = IntPtr Function(Pointer<Void>);
typedef _LocalFree = int Function(Pointer<Void>);
typedef _OpenProvC = Int32 Function(Pointer<IntPtr>, Pointer<Utf16>, Uint32);
typedef _OpenProv = int Function(Pointer<IntPtr>, Pointer<Utf16>, int);
typedef _CreateKeyC =
    Int32 Function(
      IntPtr,
      Pointer<IntPtr>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Uint32,
      Uint32,
    );
typedef _CreateKey =
    int Function(
      int,
      Pointer<IntPtr>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      int,
      int,
    );
typedef _OpenKeyC =
    Int32 Function(IntPtr, Pointer<IntPtr>, Pointer<Utf16>, Uint32, Uint32);
typedef _OpenKey = int Function(int, Pointer<IntPtr>, Pointer<Utf16>, int, int);
typedef _SetPropC =
    Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Uint8>, Uint32, Uint32);
typedef _SetProp = int Function(int, Pointer<Utf16>, Pointer<Uint8>, int, int);
typedef _HandleFlagsC = Int32 Function(IntPtr, Uint32);
typedef _HandleFlags = int Function(int, int);
typedef _FreeC = Int32 Function(IntPtr);
typedef _Free = int Function(int);
typedef _CryptC =
    Int32 Function(
      IntPtr,
      Pointer<Uint8>,
      Uint32,
      Pointer<Void>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Uint32,
    );
typedef _Crypt =
    int Function(
      int,
      Pointer<Uint8>,
      int,
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Uint32>,
      int,
    );

const _uiForbidden = 0x1;
const _overwrite = 0x80;
const _silent = 0x40;
const _padOaep = 0x4;
const _allowDecrypt = 0x1;
const _provider = 'Microsoft Platform Crypto Provider';

typedef _SysDirC = Uint32 Function(Pointer<Utf16>, Uint32);
typedef _SysDir = int Function(Pointer<Utf16>, int);

/// [name] in [systemDir]: a dll opened by its full path, never found in the
/// app's folder first
@visibleForTesting
String systemDll(String systemDir, String name) {
  if (systemDir.isEmpty) throw StateError('no system folder');
  final sep = systemDir.endsWith(r'\') ? '' : r'\';
  return '$systemDir$sep$name';
}

// windows' system32, as GetSystemDirectoryW gives it. kernel32 is a known
// dll, always the system's own whatever the search order
String _systemDir() {
  final fn = DynamicLibrary.open(
    'kernel32.dll',
  ).lookupFunction<_SysDirC, _SysDir>('GetSystemDirectoryW');
  const cap = 520;
  final buf = calloc<Uint16>(cap);
  try {
    final n = fn(buf.cast(), cap);
    if (n == 0 || n >= cap) return '';
    return buf.cast<Utf16>().toDartString(length: n);
  } finally {
    calloc.free(buf);
  }
}

/// dpapi and the tpm through crypt32.dll and ncrypt.dll, both opened by
/// their full path in system32
class FfiWinCrypt implements WinCrypt {
  const FfiWinCrypt();

  static DynamicLibrary _dll(String name) => DynamicLibrary.open(
    name == 'kernel32.dll' ? name : systemDll(_systemDir(), name),
  );

  Uint8List? _dpapi(bool seal, Uint8List data, Uint8List entropy) {
    final crypt = _dll('crypt32.dll');
    final localFree = _dll(
      'kernel32.dll',
    ).lookupFunction<_LocalFreeC, _LocalFree>('LocalFree');
    final inB = calloc<_Blob>(), entB = calloc<_Blob>(), outB = calloc<_Blob>();
    final inP = calloc<Uint8>(data.length + 1);
    final entP = calloc<Uint8>(entropy.length + 1);
    try {
      inP.asTypedList(data.length).setAll(0, data);
      entP.asTypedList(entropy.length).setAll(0, entropy);
      inB.ref
        ..size = data.length
        ..data = inP;
      entB.ref
        ..size = entropy.length
        ..data = entP;
      final ok = seal
          ? crypt.lookupFunction<_ProtectC, _Protect>('CryptProtectData')(
              inB,
              nullptr,
              entB,
              nullptr,
              nullptr,
              _uiForbidden,
              outB,
            )
          : crypt.lookupFunction<_UnprotectC, _Unprotect>('CryptUnprotectData')(
              inB,
              nullptr,
              entB,
              nullptr,
              nullptr,
              _uiForbidden,
              outB,
            );
      if (ok == 0 || outB.ref.data == nullptr) return null;
      final n = outB.ref.size;
      final out = Uint8List.fromList(outB.ref.data.asTypedList(n));
      outB.ref.data.asTypedList(n).fillRange(0, n, 0);
      localFree(outB.ref.data.cast());
      return out;
    } finally {
      inP.asTypedList(data.length).fillRange(0, data.length, 0);
      calloc.free(inP);
      calloc.free(entP);
      calloc.free(inB);
      calloc.free(entB);
      calloc.free(outB);
    }
  }

  @override
  Uint8List? protect(Uint8List data, Uint8List entropy) =>
      _dpapi(true, data, entropy);

  @override
  Uint8List? unprotect(Uint8List blob, Uint8List entropy) =>
      _dpapi(false, blob, entropy);

  // ncrypt with an open provider, freed after
  T _withProvider<T>(T Function(DynamicLibrary n, int prov) f) {
    final n = _dll('ncrypt.dll');
    final h = calloc<IntPtr>();
    final name = _provider.toNativeUtf16();
    try {
      final st = n.lookupFunction<_OpenProvC, _OpenProv>(
        'NCryptOpenStorageProvider',
      )(h, name, 0);
      if (st != 0) throw WinCryptError(st & 0xffffffff);
      try {
        return f(n, h.value);
      } finally {
        n.lookupFunction<_FreeC, _Free>('NCryptFreeObject')(h.value);
      }
    } finally {
      calloc.free(h);
      calloc.free(name);
    }
  }

  @override
  bool tpmThere() {
    try {
      return _withProvider((_, _) => true);
    } catch (_) {
      return false;
    }
  }

  // [f] with the key [name] opened, freed after
  T _withKey<T>(String name, T Function(DynamicLibrary n, int key) f) =>
      _withProvider((n, prov) {
        final k = calloc<IntPtr>();
        final kn = name.toNativeUtf16();
        try {
          final st = n.lookupFunction<_OpenKeyC, _OpenKey>('NCryptOpenKey')(
            prov,
            k,
            kn,
            0,
            _silent,
          );
          if (st != 0) throw WinCryptError(st & 0xffffffff);
          try {
            return f(n, k.value);
          } finally {
            n.lookupFunction<_FreeC, _Free>('NCryptFreeObject')(k.value);
          }
        } finally {
          calloc.free(k);
          calloc.free(kn);
        }
      });

  // oaep with sha-1: what every platform crypto provider takes
  Uint8List _crypt(DynamicLibrary n, int key, bool enc, Uint8List data) {
    // each by its own name: the binding scan reads names, not variables
    final fn = enc
        ? n.lookupFunction<_CryptC, _Crypt>('NCryptEncrypt')
        : n.lookupFunction<_CryptC, _Crypt>('NCryptDecrypt');
    final pad = calloc<_Oaep>();
    final alg = 'SHA1'.toNativeUtf16();
    final inP = calloc<Uint8>(data.length);
    const cap = 512;
    final outP = calloc<Uint8>(cap);
    final got = calloc<Uint32>();
    try {
      pad.ref
        ..alg = alg
        ..label = nullptr
        ..labelSize = 0;
      inP.asTypedList(data.length).setAll(0, data);
      final st = fn(
        key,
        inP,
        data.length,
        pad.cast(),
        outP,
        cap,
        got,
        _padOaep | _silent,
      );
      if (st != 0) throw WinCryptError(st & 0xffffffff);
      return Uint8List.fromList(outP.asTypedList(got.value));
    } finally {
      inP.asTypedList(data.length).fillRange(0, data.length, 0);
      outP.asTypedList(cap).fillRange(0, cap, 0);
      calloc.free(inP);
      calloc.free(outP);
      calloc.free(got);
      calloc.free(pad);
      calloc.free(alg);
    }
  }

  void _setDword(DynamicLibrary n, int key, String prop, int v) {
    final p = prop.toNativeUtf16();
    final b = calloc<Uint32>()..value = v;
    try {
      final st = n.lookupFunction<_SetPropC, _SetProp>('NCryptSetProperty')(
        key,
        p,
        b.cast(),
        4,
        _silent,
      );
      if (st != 0) throw WinCryptError(st & 0xffffffff);
    } finally {
      calloc.free(p);
      calloc.free(b);
    }
  }

  @override
  Uint8List tpmWrap(String name, Uint8List secret) {
    _withProvider((n, prov) {
      final k = calloc<IntPtr>();
      final alg = 'RSA'.toNativeUtf16();
      final kn = name.toNativeUtf16();
      try {
        var st = n.lookupFunction<_CreateKeyC, _CreateKey>(
          'NCryptCreatePersistedKey',
        )(prov, k, alg, kn, 0, _overwrite);
        if (st != 0) throw WinCryptError(st & 0xffffffff);
        try {
          _setDword(n, k.value, 'Length', 2048);
          _setDword(n, k.value, 'Key Usage', _allowDecrypt);
          st = n.lookupFunction<_HandleFlagsC, _HandleFlags>(
            'NCryptFinalizeKey',
          )(k.value, _silent);
          if (st != 0) throw WinCryptError(st & 0xffffffff);
        } finally {
          n.lookupFunction<_FreeC, _Free>('NCryptFreeObject')(k.value);
        }
      } finally {
        calloc.free(k);
        calloc.free(alg);
        calloc.free(kn);
      }
    });
    return _withKey(name, (n, key) => _crypt(n, key, true, secret));
  }

  @override
  Uint8List tpmUnwrap(String name, Uint8List wrapped) =>
      _withKey(name, (n, key) => _crypt(n, key, false, wrapped));

  @override
  bool tpmDelete(String name) {
    try {
      return _withProvider((n, prov) {
        final k = calloc<IntPtr>();
        final kn = name.toNativeUtf16();
        try {
          final st = n.lookupFunction<_OpenKeyC, _OpenKey>('NCryptOpenKey')(
            prov,
            k,
            kn,
            0,
            _silent,
          );
          if (st != 0) return WinCryptError(st & 0xffffffff).keyGone;
          // frees the handle too
          return n.lookupFunction<_HandleFlagsC, _HandleFlags>(
                'NCryptDeleteKey',
              )(k.value, _silent) ==
              0;
        } finally {
          calloc.free(k);
          calloc.free(kn);
        }
      });
    } catch (_) {
      return false;
    }
  }
}
