// SPDX-License-Identifier: GPL-3.0-or-later
// dart side of the libsignal shim (native/kryfo_signal). every call is
// stateless: framed fields in, framed fields out, the output copied into
// dart and handed straight back to ks_free, which wipes it. no native
// handle outlives a call, so there is nothing for a finalizer to hold

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../native_libs.dart';

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
  // a kryfo frame not in its one encoding
  static const format = 11;
  // a key the body does not name as its signer
  static const signer = 12;
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
const kLsAbi = 4;

/// the libsignal and spqr sources the reviewed library is built from, as
/// Cargo.lock names them. a library that names others is not opened
const kLsLibsignal =
    'git+https://github.com/signalapp/libsignal'
    '?rev=387da3e29ac87c821aedc697aee77646a1c72fff'
    '#387da3e29ac87c821aedc697aee77646a1c72fff';
const kLsSpqr =
    'git+https://github.com/signalapp/SparsePostQuantumRatchet.git?tag=v1.5.3'
    '#fd320484dcec89004021e6fdc7481825f5f261fa';

/// what a library built from other sources than these is refused with
class LsBuildRefused extends StateError {
  LsBuildRefused(this.libsignal, this.spqr)
    : super('libkryfo_signal was built from other sources');
  final String libsignal;
  final String spqr;
}

/// [got] is the build these bindings take
void lsCheckBuild(({String libsignal, String spqr}) got) {
  if (got.libsignal == kLsLibsignal && got.spqr == kLsSpqr) return;
  throw LsBuildRefused(got.libsignal, got.spqr);
}

/// what a kryfo signature is made for. the shim holds the same list, signs
/// under no other, and signs only a whole body of the context's format that
/// names the signing key as its signer, so a signature for one never holds
/// for another
enum LsSigContext {
  invite('invite'),
  hello('hello'),
  heal('heal'),
  deviceList('device-list'),
  move('move');

  const LsSigContext(this.wire);
  final String wire;
}

/// the frames ks_parse reads
enum LsFormat {
  invite('invite'),
  hello('hello'),
  heal('heal'),
  deviceList('device-list'),
  deviceBundle('device-bundle'),
  move('move');

  const LsFormat(this.wire);
  final String wire;
}

/// KIN4 flag bits
const kLsInviteOneTime = 1;
const kLsInviteBundle = 2;
const kLsInviteOnion = 4;
const kLsInviteFace = 8;
const kLsInviteList = 16;

/// a bundle block of a KIN4, KHB1 or KDB1, with the bundle it builds
class LsBlock {
  const LsBlock({
    required this.registrationId,
    required this.deviceId,
    required this.key,
    required this.bundle,
  });
  final int registrationId;
  final int deviceId;
  // the device key it runs on; null when it runs on the frame's identity
  final Uint8List? key;
  // the same prekeys as ks_bundle_build checked them, for a session
  final LsBundle bundle;
}

class LsInvite {
  const LsInvite({
    required this.flags,
    required this.issued,
    required this.expires,
    required this.id,
    required this.identity,
    required this.firstContact,
    required this.onion,
    required this.face,
    required this.faceSignature,
    required this.deviceList,
    required this.answering,
    required this.signature,
    required this.block,
  });
  final int flags;
  // unix hours
  final int issued;
  final int expires;
  final Uint8List id;
  final Uint8List identity;
  // secp256k1 x-only
  final Uint8List firstContact;
  final Uint8List? onion;
  final Uint8List? face;
  final Uint8List? faceSignature;
  final LsDeviceList? deviceList;
  // the key whose private half answers its first contacts
  final Uint8List answering;
  final Uint8List signature;
  final LsBlock? block;

  bool get oneTime => flags & kLsInviteOneTime != 0;
}

class LsHello {
  const LsHello({
    required this.answers,
    required this.owner,
    required this.invite,
    required this.inviteBytes,
    required this.signature,
  });
  // the invite id answered, all zero for a v3 link
  final Uint8List answers;
  final Uint8List owner;
  // the sender's one-time invite; its identity is the sender
  final LsInvite invite;
  final Uint8List inviteBytes;
  final Uint8List signature;
}

class LsHeal {
  const LsHeal({
    required this.restored,
    required this.issued,
    required this.nonce,
    required this.identity,
    required this.peer,
    required this.since,
    required this.signer,
    required this.signature,
    required this.block,
  });
  final bool restored;
  final int issued;
  final Uint8List nonce;
  final Uint8List identity;
  final Uint8List peer;
  // unix hours, a whole day; zero unless restored
  final int since;
  // the sending device's key: the block's, else the identity
  final Uint8List signer;
  final Uint8List signature;
  final LsBlock block;
}

class LsDevice {
  const LsDevice(this.deviceId, this.key, this.registrationId, this.flags);
  final int deviceId;
  final Uint8List key;
  final int registrationId;
  final int flags;

  bool get phone => flags & 1 != 0;
  bool get answers => flags & 2 != 0;
}

class LsDeviceList {
  const LsDeviceList(this.identity, this.version, this.signature, this.devices);
  final Uint8List identity;
  final int version;
  final Uint8List signature;
  final List<LsDevice> devices;
}

class LsMove {
  const LsMove(this.old, this.peer, this.fresh, this.inviteHash);
  final Uint8List old;
  final Uint8List peer;
  final Uint8List fresh;
  // sha256 of the new identity's KIN4
  final Uint8List inviteHash;
}

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
        // dart ints are signed: a negative one would go out as a huge u64
        if (v.v < 0) throw ArgumentError.value(v.v, 'u64');
        put(
          (ByteData(8)..setUint64(0, v.v, Endian.little)).buffer.asUint8List(),
        );
      case final int v:
        // setUint32 keeps the low bits of anything wider
        if (v < 0 || v > 0xffffffff) throw ArgumentError.value(v, 'u32');
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
// the shim hands out no u64 at or above 2^63, which dart would read as
// negative
int _u64(Uint8List b) {
  final v = ByteData.sublistView(b).getUint64(0, Endian.little);
  if (v < 0) throw const LsError(LsError.internal);
  return v;
}

int? _optU32(Uint8List b) => b.isEmpty ? null : _u32(b);
Uint8List? _opt(Uint8List b) => b.isEmpty ? null : b;

/// the library's abi checked against these bindings before anything else
/// is looked up, so a stale library fails here and says why
void lsCheckAbi(int? got) {
  if (got == kLsAbi) return;
  if (got == null || got < kLsAbi) {
    throw StateError(
      'the signal library is older than the app '
      '(abi ${got ?? 'none'}, the app wants $kLsAbi): rebuild it with '
      'native/kryfo_signal/build-android.sh',
    );
  }
  throw StateError(
    'the signal library is newer than the app (abi $got, the app wants $kLsAbi)',
  );
}

int? _abiOf(DynamicLibrary lib) {
  if (!lib.providesSymbol('ks_abi_version')) return null;
  return lib.lookupFunction<Uint32 Function(), int Function()>(
    'ks_abi_version',
  )();
}

class KryfoSignal {
  factory KryfoSignal._(DynamicLibrary lib) {
    lsCheckAbi(_abiOf(lib));
    final k = KryfoSignal._bound(lib);
    lsCheckBuild(k.buildInfo());
    return k;
  }

  KryfoSignal._bound(DynamicLibrary lib)
    : _free = lib.lookupFunction<_FreeC, _Free>('ks_free'),
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
        'sign': lib.lookupFunction<_CallC, _Call>('ks_sign'),
        'verify_ctx': lib.lookupFunction<_CallC, _Call>('ks_verify_ctx'),
        'build_info': lib.lookupFunction<_CallC, _Call>('ks_build_info'),
        'session_drop_below': lib.lookupFunction<_CallC, _Call>(
          'ks_session_drop_below',
        ),
        'parse': lib.lookupFunction<_CallC, _Call>('ks_parse'),
      };

  final _Free _free;
  final Map<String, _Call> _fns;

  static KryfoSignal? _shared;

  /// the platform's library, opened on first use. a failed open is not
  /// kept: the next call tries again and throws the same way
  static KryfoSignal get shared => _shared ??= open();

  /// the env var the host tests name the library by
  static const envVar = 'KRYFO_SIGNAL_LIB';

  // where build-host.sh leaves it, from the app's directory
  static const _hostBuilt = 'native/kryfo_signal/target/release';

  static const _product = bool.fromEnvironment('dart.vm.product');

  /// the library at [path], else the env var's, else (outside a release,
  /// on a desktop) the one build-host.sh left, else the platform's own name
  /// for it. throws when it does not load
  static KryfoSignal open([String? path]) {
    // kryfo.exe loaded it by full path from its own folder before dart ran
    // (runner/kryfo_win.cpp); a release takes no other
    if (Platform.isWindows && _product && path == null) return _beside();
    final p = path ?? Platform.environment[envVar];
    if (p != null && p.isNotEmpty) return _at(p);
    if (!_product && !Platform.isAndroid && !Platform.isIOS) {
      final host = forHostTests();
      if (host != null) return host;
    }
    if (Platform.isWindows) return _beside();
    if (Platform.isIOS) return KryfoSignal._(DynamicLibrary.process());
    if (Platform.isMacOS) return _at('libkryfo_signal.dylib');
    return _at('libkryfo_signal.so');
  }

  /// the name or path the library was last opened by, for the engine to
  /// open the same one (null before, and on ios where it is linked in)
  static String? get loadedFrom => _loadedFrom;
  static String? _loadedFrom;

  // kryfo.exe's folder, by full path: the engine opens the same file
  static KryfoSignal _beside() {
    final l = KryfoSignal._(besideExe(_windowsName));
    _loadedFrom = besidePath(_windowsName);
    return l;
  }

  static const _windowsName = 'kryfo_signal.dll';

  static KryfoSignal _at(String p) {
    final l = KryfoSignal._(DynamicLibrary.open(p));
    _loadedFrom = p;
    return l;
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
      return _at(File(c).absolute.path);
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

  /// libsignal's signature over a prekey's public key (33 or 1569 bytes)
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

  /// [record] without its archived states below [version], and how many
  /// went: a classic state left behind a post-quantum one still takes
  /// messages until it goes
  (Uint8List record, int dropped) sessionDropBelow(
    Uint8List record,
    int version,
  ) {
    final o = _call('session_drop_below', [record, version]);
    return (o[0], _u32(o[1]));
  }

  /// [me]'s signature over [message] for [context] (64 bytes). [message] is
  /// the body without its signature, and must name [me] as its signer
  Uint8List sign(LsIdentity me, LsSigContext context, List<int> message) =>
      _call('sign', [me.pair, utf8.encode(context.wire), message])[0];

  /// whether [signature] is [identityKey]'s over [message] for [context].
  /// a key or signature in any but its one encoding is false
  bool verifyCtx(
    List<int> identityKey,
    LsSigContext context,
    List<int> message,
    List<int> signature,
  ) {
    try {
      _call('verify_ctx', [
        identityKey,
        utf8.encode(context.wire),
        message,
        signature,
      ]);
      return true;
    } on LsError catch (e) {
      if (e.code == LsError.signature || e.code == LsError.key) return false;
      rethrow;
    }
  }

  List<Uint8List> _parse(LsFormat f, List<int> bytes, [List<int>? identity]) =>
      _call('parse', [utf8.encode(f.wire), bytes, identity]);

  // twelve fields from [at]; null when they are all empty
  LsBlock? _block(List<Uint8List> o, int at) {
    if (o[at].isEmpty) return null;
    return LsBlock(
      registrationId: _u32(o[at]),
      deviceId: _u32(o[at + 1]),
      key: _opt(o[at + 2]),
      bundle: bundleParse(o[at + 11]),
    );
  }

  /// a KIN4, every check done (LsError.format, LsError.signature)
  LsInvite parseInvite(List<int> bytes) {
    final o = _parse(LsFormat.invite, bytes);
    final list = _opt(o[9]);
    return LsInvite(
      flags: _u32(o[0]),
      issued: _u32(o[1]),
      expires: _u32(o[2]),
      id: o[3],
      identity: o[4],
      firstContact: o[5],
      onion: _opt(o[6]),
      face: _opt(o[7]),
      faceSignature: _opt(o[8]),
      deviceList: list == null ? null : parseDeviceList(list),
      answering: o[10],
      signature: o[11],
      block: _block(o, 12),
    );
  }

  /// a KHL1, the invite inside it checked too
  LsHello parseHello(List<int> bytes) {
    final o = _parse(LsFormat.hello, bytes);
    return LsHello(
      answers: o[0],
      owner: o[1],
      invite: parseInvite(o[2]),
      inviteBytes: o[2],
      signature: o[4],
    );
  }

  /// a KHB1
  LsHeal parseHeal(List<int> bytes) {
    final o = _parse(LsFormat.heal, bytes);
    return LsHeal(
      restored: _u32(o[0]) == 1,
      issued: _u32(o[1]),
      nonce: o[2],
      identity: o[3],
      peer: o[4],
      since: _u32(o[5]),
      signer: o[6],
      signature: o[7],
      block: _block(o, 8)!,
    );
  }

  /// a KDL2
  LsDeviceList parseDeviceList(List<int> bytes) {
    final o = _parse(LsFormat.deviceList, bytes);
    final n = _u32(o[3]);
    return LsDeviceList(o[0], _u64(o[1]), o[2], [
      for (var i = 0; i < n; i++)
        LsDevice(
          _u32(o[4 + 4 * i]),
          o[5 + 4 * i],
          _u32(o[6 + 4 * i]),
          _u32(o[7 + 4 * i]),
        ),
    ]);
  }

  /// a KDB1 of [identity]'s device; it has no signature of its own, the
  /// session it came in vouches for it
  LsBlock parseDeviceBundle(List<int> bytes, List<int> identity) {
    final o = _parse(LsFormat.deviceBundle, bytes, identity);
    return _block(o, 1)!;
  }

  /// a move body
  LsMove parseMove(List<int> bytes) {
    final o = _parse(LsFormat.move, bytes);
    return LsMove(o[0], o[1], o[2], o[3]);
  }

  /// the libsignal and spqr sources the library was built from, as its
  /// Cargo.lock names them
  ({String libsignal, String spqr}) buildInfo() {
    final o = _call('build_info', const []);
    return (libsignal: utf8.decode(o[0]), spqr: utf8.decode(o[1]));
  }
}
