// SPDX-License-Identifier: GPL-3.0-or-later
// dart side of the libsignal shim (native/kryfo_signal). every call is
// stateless: framed fields in, framed fields out, the output copied into
// dart and handed straight back to ks_free, which wipes it. no native
// handle outlives a call, so there is nothing for a finalizer to hold

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _CallC =
    Int32 Function(
      Pointer<Uint8>,
      Size,
      Pointer<Pointer<Uint8>>,
      Pointer<Size>,
    );
typedef _Call =
    int Function(Pointer<Uint8>, int, Pointer<Pointer<Uint8>>, Pointer<Size>);
typedef _FreeC = Void Function(Pointer<Uint8>, Size);
typedef _Free = void Function(Pointer<Uint8>, int);

/// what a call failed with, as kryfo_signal.h numbers it
class LsError implements Exception {
  const LsError(this.code);
  final int code;

  static const args = 1;
  static const key = 2;
  static const signature = 3;
  static const message = 4;
  static const noSession = 5;
  static const duplicate = 6;
  static const untrusted = 7;
  static const noPreKey = 8;
  static const classic = 9;
  static const session = 10;
  static const panic = 98;
  static const internal = 99;

  @override
  String toString() => 'LsError($code)';
}

/// message types on the wire, the same numbers both libraries use
const kLsWhisper = 2;
const kLsPreKey = 3;

const kLsOneTime = 0;
const kLsSigned = 1;
const kLsKyber = 2;

/// the abi these bindings were written for
const kLsAbi = 1;

class LsIdentity {
  const LsIdentity(this.pair, this.public);
  // a serialized IdentityKeyPair: the private key is in here
  final Uint8List pair;
  // 33 bytes, 0x05 then the x25519 key
  final Uint8List public;
}

class LsPreKey {
  const LsPreKey(this.id, this.record, this.public, this.signature);
  final int id;
  final Uint8List record;
  final Uint8List public;
  // empty for a one-time key
  final Uint8List signature;
}

class LsBundle {
  const LsBundle({
    required this.registrationId,
    required this.deviceId,
    required this.preKeyId,
    required this.preKey,
    required this.signedPreKeyId,
    required this.signedPreKey,
    required this.signedPreKeySignature,
    required this.kyberPreKeyId,
    required this.kyberPreKey,
    required this.kyberPreKeySignature,
    required this.identityKey,
    required this.bytes,
  });
  final int registrationId;
  final int deviceId;
  final int? preKeyId;
  final Uint8List? preKey;
  final int signedPreKeyId;
  final Uint8List signedPreKey;
  final Uint8List signedPreKeySignature;
  final int kyberPreKeyId;
  final Uint8List kyberPreKey;
  final Uint8List kyberPreKeySignature;
  final Uint8List identityKey;
  // the checked bundle as the shim takes it back
  final Uint8List bytes;
}

class LsSealed {
  const LsSealed(this.type, this.message, this.record);
  final int type;
  final Uint8List message;
  final Uint8List record;
}

class LsPreKeyMessageInfo {
  const LsPreKeyMessageInfo({
    required this.version,
    required this.registrationId,
    required this.preKeyId,
    required this.signedPreKeyId,
    required this.kyberPreKeyId,
    required this.baseKey,
    required this.identityKey,
  });
  final int version;
  final int registrationId;
  final int? preKeyId;
  final int signedPreKeyId;
  final int? kyberPreKeyId;
  final Uint8List baseKey;
  final Uint8List identityKey;
}

class LsOpened {
  const LsOpened(
    this.plaintext,
    this.record,
    this.identityKey, {
    this.usedPreKey,
    this.usedKyberPreKey,
  });
  final Uint8List plaintext;
  final Uint8List record;
  final Uint8List identityKey;
  final int? usedPreKey;
  final int? usedKyberPreKey;
}

class LsState {
  const LsState(this.version, this.baseKey);
  final int version;
  final Uint8List baseKey;
}

class LsSessionInfo {
  const LsSessionInfo({
    required this.current,
    required this.pq,
    required this.remoteIdentity,
    required this.localRegistrationId,
    required this.remoteRegistrationId,
    required this.archived,
  });
  // null when the record holds no current state
  final LsState? current;
  // the post-quantum ratchet (spqr) runs on the current state
  final bool pq;
  final Uint8List? remoteIdentity;
  final int localRegistrationId;
  final int remoteRegistrationId;
  final List<LsState> archived;

  int get version => current?.version ?? 0;

  /// whether a state of this version and base key is held, current or not
  bool holds(int version, List<int> baseKey) => [
    ?current,
    ...archived,
  ].any((s) => s.version == version && _eq(s.baseKey, baseKey));
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// one field per entry; null and empty both go as an empty field
Uint8List _frame(List<Object?> fields) {
  final b = BytesBuilder(copy: false);
  void put(List<int> v) {
    final n = ByteData(4)..setUint32(0, v.length, Endian.little);
    b.add(n.buffer.asUint8List());
    b.add(v);
  }

  for (final f in fields) {
    switch (f) {
      case null:
        put(const []);
      case final List<int> v:
        put(v);
      case final _U64 v:
        put(
          (ByteData(8)..setUint64(0, v.v, Endian.little)).buffer.asUint8List(),
        );
      case final int v:
        put((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
      default:
        throw ArgumentError('field ${f.runtimeType}');
    }
  }
  return b.takeBytes();
}

class _U64 {
  const _U64(this.v);
  final int v;
}

List<Uint8List> _unframe(Uint8List b) {
  final out = <Uint8List>[];
  final d = ByteData.sublistView(b);
  var at = 0;
  while (at < b.length) {
    if (at + 4 > b.length) throw const LsError(LsError.internal);
    final n = d.getUint32(at, Endian.little);
    at += 4;
    if (at + n > b.length) throw const LsError(LsError.internal);
    out.add(b.sublist(at, at + n));
    at += n;
  }
  return out;
}

int _u32(Uint8List b) => ByteData.sublistView(b).getUint32(0, Endian.little);
int? _optU32(Uint8List b) => b.isEmpty ? null : _u32(b);
Uint8List? _opt(Uint8List b) => b.isEmpty ? null : b;

class KryfoSignal {
  KryfoSignal._(DynamicLibrary lib)
    : _free = lib.lookupFunction<_FreeC, _Free>('ks_free'),
      _abi = lib.lookupFunction<Uint32 Function(), int Function()>(
        'ks_abi_version',
      ),
      _fns = {
        'identity_generate': lib.lookupFunction<_CallC, _Call>(
          'ks_identity_generate',
        ),
        'identity_from_private': lib.lookupFunction<_CallC, _Call>(
          'ks_identity_from_private',
        ),
        'prekey_generate': lib.lookupFunction<_CallC, _Call>(
          'ks_prekey_generate',
        ),
        'signed_prekey_generate': lib.lookupFunction<_CallC, _Call>(
          'ks_signed_prekey_generate',
        ),
        'kyber_prekey_generate': lib.lookupFunction<_CallC, _Call>(
          'ks_kyber_prekey_generate',
        ),
        'prekey_public': lib.lookupFunction<_CallC, _Call>('ks_prekey_public'),
        'verify': lib.lookupFunction<_CallC, _Call>('ks_verify'),
        'bundle_build': lib.lookupFunction<_CallC, _Call>('ks_bundle_build'),
        'bundle_parse': lib.lookupFunction<_CallC, _Call>('ks_bundle_parse'),
        'session_from_bundle': lib.lookupFunction<_CallC, _Call>(
          'ks_session_from_bundle',
        ),
        'encrypt': lib.lookupFunction<_CallC, _Call>('ks_encrypt'),
        'prekey_message_info': lib.lookupFunction<_CallC, _Call>(
          'ks_prekey_message_info',
        ),
        'decrypt_prekey': lib.lookupFunction<_CallC, _Call>(
          'ks_decrypt_prekey',
        ),
        'decrypt_signal': lib.lookupFunction<_CallC, _Call>(
          'ks_decrypt_signal',
        ),
        'session_info': lib.lookupFunction<_CallC, _Call>('ks_session_info'),
        'session_promote': lib.lookupFunction<_CallC, _Call>(
          'ks_session_promote',
        ),
      } {
    if (_abi() != kLsAbi) {
      throw StateError(
        'kryfo_signal abi ${_abi()}, these bindings want $kLsAbi',
      );
    }
  }

  final _Free _free;
  final int Function() _abi;
  final Map<String, _Call> _fns;

  /// the env var the host tests name the library by
  static const envVar = 'KRYFO_SIGNAL_LIB';

  // where build-host.sh leaves it, from the app's directory
  static const _hostBuilt = 'native/kryfo_signal/target/release';

  /// the library at [path], else the env var's, else the platform's own
  /// name for it. throws when it does not load
  static KryfoSignal open([String? path]) {
    final p = path ?? Platform.environment[envVar];
    if (p != null && p.isNotEmpty) return KryfoSignal._(DynamicLibrary.open(p));
    if (Platform.isIOS) return KryfoSignal._(DynamicLibrary.process());
    if (Platform.isMacOS) {
      return KryfoSignal._(DynamicLibrary.open('libkryfo_signal.dylib'));
    }
    return KryfoSignal._(DynamicLibrary.open('libkryfo_signal.so'));
  }

  /// the library from the env var or next to the app's sources, as the host
  /// tests find it; null when there is none
  static KryfoSignal? forHostTests() {
    final candidates = [
      Platform.environment[envVar],
      '$_hostBuilt/libkryfo_signal.so',
      '$_hostBuilt/libkryfo_signal.dylib',
    ];
    for (final c in candidates) {
      if (c == null || c.isEmpty || !File(c).existsSync()) continue;
      return KryfoSignal._(DynamicLibrary.open(File(c).absolute.path));
    }
    return null;
  }

  List<Uint8List> _call(String name, List<Object?> fields) {
    final input = _frame(fields);
    final fn = _fns[name]!;
    return using((arena) {
      final inp = arena<Uint8>(input.isEmpty ? 1 : input.length);
      final view = inp.asTypedList(input.isEmpty ? 1 : input.length);
      view.setAll(0, input);
      final out = arena<Pointer<Uint8>>();
      final outLen = arena<Size>();
      try {
        final code = fn(inp, input.length, out, outLen);
        if (code != 0) throw LsError(code);
        final p = out.value;
        final n = outLen.value;
        final copy = Uint8List.fromList(p.asTypedList(n));
        _free(p, n);
        try {
          return _unframe(copy);
        } finally {
          copy.fillRange(0, copy.length, 0);
        }
      } finally {
        // the input carried keys
        view.fillRange(0, view.length, 0);
        input.fillRange(0, input.length, 0);
      }
    });
  }

  LsIdentity identityGenerate() {
    final o = _call('identity_generate', const []);
    return LsIdentity(o[0], o[1]);
  }

  /// the signal identity on an x25519 private key, as the app derives it
  LsIdentity identityFromPrivate(List<int> private32) {
    final o = _call('identity_from_private', [private32]);
    return LsIdentity(o[0], o[1]);
  }

  LsPreKey preKey(int id) {
    final o = _call('prekey_generate', [id]);
    return LsPreKey(id, o[0], o[1], Uint8List(0));
  }

  LsPreKey signedPreKey(LsIdentity me, int id, int nowMs) {
    final o = _call('signed_prekey_generate', [me.pair, id, _U64(nowMs)]);
    return LsPreKey(id, o[0], o[1], o[2]);
  }

  LsPreKey kyberPreKey(LsIdentity me, int id, int nowMs) {
    final o = _call('kyber_prekey_generate', [me.pair, id, _U64(nowMs)]);
    return LsPreKey(id, o[0], o[1], o[2]);
  }

  /// a stored record of [kind] (kLsOneTime, kLsSigned, kLsKyber) read back
  LsPreKey preKeyPublic(int kind, List<int> record) {
    final o = _call('prekey_public', [kind, record]);
    return LsPreKey(_u32(o[0]), Uint8List.fromList(record), o[1], o[2]);
  }

  bool verify(List<int> identityKey, List<int> message, List<int> signature) {
    try {
      _call('verify', [identityKey, message, signature]);
      return true;
    } on LsError catch (e) {
      if (e.code == LsError.signature || e.code == LsError.key) return false;
      rethrow;
    }
  }

  LsBundle bundleBuild({
    required int registrationId,
    int deviceId = 1,
    int? preKeyId,
    List<int>? preKey,
    required int signedPreKeyId,
    required List<int> signedPreKey,
    required List<int> signedPreKeySignature,
    int? kyberPreKeyId,
    List<int>? kyberPreKey,
    List<int>? kyberPreKeySignature,
    required List<int> identityKey,
  }) {
    final o = _call('bundle_build', [
      registrationId,
      deviceId,
      preKeyId,
      preKey,
      signedPreKeyId,
      signedPreKey,
      signedPreKeySignature,
      kyberPreKeyId,
      kyberPreKey,
      kyberPreKeySignature,
      identityKey,
    ]);
    return bundleParse(o[0]);
  }

  LsBundle bundleParse(List<int> bytes) {
    final o = _call('bundle_parse', [bytes]);
    return LsBundle(
      registrationId: _u32(o[0]),
      deviceId: _u32(o[1]),
      preKeyId: _optU32(o[2]),
      preKey: _opt(o[3]),
      signedPreKeyId: _u32(o[4]),
      signedPreKey: o[5],
      signedPreKeySignature: o[6],
      kyberPreKeyId: _u32(o[7]),
      kyberPreKey: o[8],
      kyberPreKeySignature: o[9],
      identityKey: o[10],
      bytes: Uint8List.fromList(bytes),
    );
  }

  /// a new session on [bundle], in front of [held]: the record and the
  /// identity it was built with
  (Uint8List record, Uint8List identity) sessionFromBundle(
    LsIdentity me,
    int registrationId,
    Uint8List? held,
    LsBundle bundle,
    int nowMs, {
    List<int>? pinned,
  }) {
    final o = _call('session_from_bundle', [
      me.pair,
      registrationId,
      held,
      bundle.bytes,
      _U64(nowMs),
      pinned,
    ]);
    return (o[0], o[1]);
  }

  LsSealed encrypt(
    LsIdentity me,
    int registrationId,
    Uint8List record,
    List<int> plaintext,
    int nowMs, {
    List<int>? pinned,
  }) {
    final o = _call('encrypt', [
      me.pair,
      registrationId,
      record,
      plaintext,
      _U64(nowMs),
      pinned,
    ]);
    return LsSealed(_u32(o[0]), o[1], o[2]);
  }

  LsPreKeyMessageInfo preKeyMessageInfo(List<int> message) {
    final o = _call('prekey_message_info', [message]);
    return LsPreKeyMessageInfo(
      version: _u32(o[0]),
      registrationId: _u32(o[1]),
      preKeyId: _optU32(o[2]),
      signedPreKeyId: _u32(o[3]),
      kyberPreKeyId: _optU32(o[4]),
      baseKey: o[5],
      identityKey: o[6],
    );
  }

  LsOpened decryptPreKey(
    LsIdentity me,
    int registrationId,
    Uint8List? held,
    List<int> message, {
    Uint8List? preKey,
    Uint8List? signedPreKey,
    Uint8List? kyberPreKey,
    List<int>? pinned,
  }) {
    final o = _call('decrypt_prekey', [
      me.pair,
      registrationId,
      held,
      message,
      preKey,
      signedPreKey,
      kyberPreKey,
      pinned,
    ]);
    return LsOpened(
      o[0],
      o[1],
      o[4],
      usedPreKey: _optU32(o[2]),
      usedKyberPreKey: _optU32(o[3]),
    );
  }

  LsOpened decryptSignal(
    LsIdentity me,
    int registrationId,
    Uint8List record,
    List<int> message, {
    List<int>? pinned,
  }) {
    final o = _call('decrypt_signal', [
      me.pair,
      registrationId,
      record,
      message,
      pinned,
    ]);
    return LsOpened(o[0], o[1], o[2]);
  }

  LsSessionInfo sessionInfo(List<int> record) {
    final o = _call('session_info', [record]);
    final n = _u32(o[7]);
    return LsSessionInfo(
      current: _u32(o[0]) == 1 ? LsState(_u32(o[1]), o[3]) : null,
      pq: _u32(o[2]) == 1,
      remoteIdentity: _opt(o[4]),
      localRegistrationId: _u32(o[5]),
      remoteRegistrationId: _u32(o[6]),
      archived: [
        for (var i = 0; i < n; i++) LsState(_u32(o[8 + 2 * i]), o[9 + 2 * i]),
      ],
    );
  }

  /// [held] with [newer]'s current state in front, each session once
  Uint8List sessionPromote(Uint8List held, Uint8List newer) =>
      _call('session_promote', [held, newer])[0];
}
