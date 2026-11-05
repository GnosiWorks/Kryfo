// SPDX-License-Identifier: GPL-3.0-or-later
// sessions with a contact's devices 2..127, and with this account's own
// other devices, next to the phone's (device 1) in the same store. each is
// built from that device's KDB1 and runs only on the key its identity's
// signed list names; every one is pqxdh with the pq ratchet. on a linked
// device the phones are such sessions too: it has no chat of its own from
// before. which devices get a copy and which may send is engine/devices'
// to say (Fanout, Admit)

import 'dart:convert';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'invites.dart' show bundleBlock;
import 'signal_ffi/kryfo_signal.dart';
import 'signal_session.dart';
import 'signal_stores.dart';
import 'wire_pad.dart';

/// the address the sessions with this account's own other devices are kept
/// under, beside the contacts' addresses
const kOwnDevices = '_own_devices_';

// the kyber keys an opener from a device may rest on
const _kDeviceKyberUses = {kUseSession, kUseHeal, kUsePool};

/// a device on a list other than the phone
bool isLinkedDevice(int device) => device >= 2 && device <= 127;

/// one copy of a message: its frame [plain] for [peer]'s [device] on [pin]
typedef DeviceCopy = ({String peer, int device, Uint8List pin, String plain});

/// a copy sealed ([wire], as [DeviceSessions.seal] gives it) or not
/// ([error]: WaitsForAnswer when that device waits for its answer)
typedef DeviceSealed = ({String? wire, Object? error});

/// what a device copy opened to, seen before anything of it is kept: the
/// remote identity and record libsignal answered, whether it was an opener
/// and the registration id it came under (the opener's own, else the
/// listed one). a throw refuses the copy
typedef DeviceAdmit =
    Future<void> Function(
      Uint8List remote,
      Uint8List record, {
      required bool opener,
      required int reg,
    });

/// a KDB1 or a session that does not match the device's list entry
class DeviceRefused implements Exception {
  const DeviceRefused(this.why);
  final String why;
  @override
  String toString() => 'DeviceRefused: $why';
}

class DeviceSessions {
  /// sessions in [s]'s store. on a phone ([linked] false) device 1 is
  /// SignalSession's own and refused here
  DeviceSessions(this.s, {this.linked = false, this.store});

  /// the identity's store: its keys, and the sessions unless [store]
  final SignalSession s;

  /// where the sessions are kept when not beside the identity's own: a
  /// hidden chat's contact's in the open vault. the identity's keys stay
  /// in [s]'s store
  final Database? store;

  /// the store is a linked device's: a contact's phone is a device here too
  final bool linked;

  bool _takes(int device) => isLinkedDevice(device) || (linked && device == 1);

  KryfoSignal get _lib => s.lib;
  final Map<String, Future<void>> _steps = {};

  int _now() => DateTime.now().millisecondsSinceEpoch;

  LsSessionStore _sessions([DatabaseExecutor? t]) => LsSessionStore(
    t ?? store ?? s.database,
    prefix: store == null ? s.tablePrefix : '',
    ident: s.ident,
  );

  // one queue per device, so copies to six devices do not wait on each other
  Future<T> _serial<T>(String peer, int device, Future<T> Function() job) {
    if (!_takes(device)) {
      return Future.error(
        DeviceRefused('device $device is not one for this store'),
      );
    }
    final k = '$peer/$device';
    final out = (_steps[k] ?? Future<void>.value()).then((_) => job());
    final tail = out.then<void>((_) {}, onError: (_) {});
    _steps[k] = tail;
    tail.whenComplete(() {
      if (identical(_steps[k], tail)) _steps.remove(k);
    });
    return out;
  }

  void _requirePq(Uint8List record) {
    final info = _lib.sessionInfo(record);
    if (info.version < 4 || !info.pq) {
      throw const ClassicRefused(
        'a device session that is not pqxdh with spqr',
      );
    }
  }

  /// a session with [peer]'s [device] from its KDB1 [block] (read by
  /// parseDeviceBundle under the contact's identity). [pin] and [reg] are
  /// the device's list entry. a session held on [pin] stays as it is
  /// (false) unless [rebuild] (the slot said Rebuild); then it goes into the
  /// new record's archive, so what was sealed on it still opens. one held on
  /// another key is dropped, never archived under the new pin
  Future<bool> build(
    String peer,
    int device,
    LsBlock block,
    Uint8List pin,
    int reg, {
    bool rebuild = false,
  }) => _serial(peer, device, () async {
    // the key the bundle runs on: the device's own, or the identity for a
    // phone
    if (block.deviceId != device ||
        block.registrationId != reg ||
        (block.key == null) != (device == 1) ||
        !_eq(block.bundle.identityKey, pin)) {
      throw const DeviceRefused('a bundle that is not the listed device');
    }
    final held = await _sessions().load(peer, device);
    Uint8List? over;
    if (held != null && _onKey(held, pin)) {
      if (!rebuild) return false;
      over = held;
    }
    final (record, their) = _lib.sessionFromBundle(
      s.identity,
      s.registrationId,
      over,
      block.bundle,
      _now(),
      pinned: pin,
    );
    _requirePq(record);
    if (!_eq(their, pin)) throw const LsError(LsError.untrusted);
    await _sessions().store(peer, record, device);
    return true;
  });

  bool _onKey(Uint8List record, Uint8List pin) {
    try {
      final k = _lib.sessionInfo(record).remoteIdentity;
      return k != null && _eq(k, pin);
    } on LsError {
      return false;
    }
  }

  Future<bool> has(String peer, int device) =>
      _sessions().contains(peer, device);

  /// every device session held with [peer] and the key it runs on, for the
  /// engine's Stale
  Future<List<({int device, Uint8List key})>> held(String peer) async {
    final out = <({int device, Uint8List key})>[];
    for (final d in await _sessions().subDeviceSessions(peer)) {
      if (!_takes(d)) continue;
      final r = await _sessions().load(peer, d);
      Uint8List? k;
      try {
        k = r == null ? null : _lib.sessionInfo(r).remoteIdentity;
      } on LsError {
        k = null;
      }
      out.add((device: d, key: k ?? Uint8List(0)));
    }
    return out;
  }

  /// the session with [peer]'s [device] gone, as when the device left
  /// its list
  Future<void> drop(String peer, int device) =>
      _serial(peer, device, () => _sessions().delete(peer, device));

  /// whether [device] has answered: a seal now would be a plain message.
  /// a trial seal, kept nowhere
  Future<bool> answered(String peer, int device, Uint8List pin) =>
      _serial(peer, device, () async {
        final r = await _sessions().load(peer, device);
        if (r == null) return false;
        return _trialType(r, pin) == kLsWhisper;
      });

  int _trialType(Uint8List record, Uint8List pin) => _lib
      .encrypt(
        s.identity,
        s.registrationId,
        record,
        const [0],
        _now(),
        pinned: pin,
      )
      .type;

  /// [plain] sealed to [peer]'s [device], as the wire carries it: the type
  /// byte, then the message, in base64, filled as every seal is. an opener
  /// too big for its size throws WaitsForAnswer: that device skips this
  /// frame, the others get theirs. [size], a burst's, as sealAll fills
  Future<String> seal(
    String peer,
    int device,
    String plain,
    Uint8List pin, {
    int? size,
  }) => _serial(peer, device, () => _seal(peer, device, plain, pin, size));

  /// every copy of one message sealed, each filled to the largest copy's
  /// size, so the relay sees one size in the burst: an opener counts as the
  /// second seal size, where it lands. an opener in a burst at any other
  /// size waits for its device's answer, as a frame too big for an opener
  /// does. [size]: the least the burst takes, as the phone's copy measures
  /// (SignalSession.sealSize). a copy that fails keeps its error; the
  /// others go
  Future<List<DeviceSealed>> sealAll(
    List<DeviceCopy> copies, {
    int size = 0,
  }) async {
    final most = max(size, await burstSize(copies));
    return [
      for (final c in copies)
        await _serial(
          c.peer,
          c.device,
          () => _seal(c.peer, c.device, c.plain, c.pin, most),
        ).then<DeviceSealed>(
          (w) => (wire: w, error: null),
          onError: (Object e) => (wire: null, error: e),
        ),
    ];
  }

  /// the size the largest of [copies] seals to now, 0 when none can: what
  /// sealAll fills the burst to, measured with the phone's copy
  /// (SignalSession.sealSize) by a send that has one
  Future<int> burstSize(List<DeviceCopy> copies) async {
    var most = 0;
    for (final c in copies) {
      try {
        final n = await _serial(c.peer, c.device, () async {
          final record = await _sessions().load(c.peer, c.device);
          if (record == null) return null;
          if (_trialType(record, c.pin) != kLsPreKey) {
            return utf8Length(padSeal(c.plain));
          }
          return padSealOpener(c.plain) == null ? null : kSealSizes[1];
        });
        if (n != null && n > most) most = n;
      } on Object {
        // its seal says why
      }
    }
    return most;
  }

  // [size]: the burst's, null for the frame's own
  Future<String> _seal(
    String peer,
    int device,
    String plain,
    Uint8List pin,
    int? size,
  ) async {
    final record = await _sessions().load(peer, device);
    if (record == null) throw const LsError(LsError.noSession);
    final String padded;
    if (_trialType(record, pin) == kLsPreKey) {
      // in a burst only at the second size: a session rebuilt since the
      // burst was measured must not seal an opener into a smaller one
      final o = size != null && size != kSealSizes[1]
          ? null
          : padSealOpener(plain);
      if (o == null) throw WaitsForAnswer(peer);
      padded = o;
    } else {
      padded = size == null ? padSeal(plain) : padSealTo(plain, size);
    }
    final body = Uint8List.fromList(utf8.encode(padded));
    final LsSealed m;
    try {
      m = _lib.encrypt(
        s.identity,
        s.registrationId,
        record,
        body,
        _now(),
        pinned: pin,
      );
    } finally {
      body.fillRange(0, body.length, 0);
    }
    await _sessions().store(peer, m.record, device);
    return base64Encode([m.type, ...m.message]);
  }

  /// [body] of [type] from [peer]'s [device] opened, on the session held or
  /// on an opener built on this store's session prekeys. [pin] and [reg]
  /// are the device's list entry; an opener under another reg is refused.
  /// nothing is stored before it opens, and an opener opens once. [admit]
  /// sees what libsignal answered (the remote, the record, whether it was
  /// an opener and its reg) after it opened and before anything is stored:
  /// when it throws, the plaintext is wiped and nothing is kept, so a
  /// refused copy is never shown and an opener's keys stay unspent
  Future<Uint8List> open(
    String peer,
    int device,
    int type,
    Uint8List body,
    Uint8List pin, {
    required int reg,
    DeviceAdmit? admit,
  }) => _serial(peer, device, () async {
    Future<void> admitted(
      Uint8List remote,
      Uint8List record,
      Uint8List plain, {
      required bool opener,
      required int reg,
    }) async {
      if (admit == null) return;
      try {
        await admit(remote, record, opener: opener, reg: reg);
      } catch (_) {
        plain.fillRange(0, plain.length, 0);
        rethrow;
      }
    }

    final held = await _sessions().load(peer, device);
    if (type != kLsPreKey) {
      if (held == null) throw const LsError(LsError.noSession);
      final o = _lib.decryptSignal(
        s.identity,
        s.registrationId,
        held,
        body,
        pinned: pin,
      );
      if (!_eq(o.identityKey, pin)) throw const LsError(LsError.untrusted);
      await admitted(
        o.identityKey,
        o.record,
        o.plaintext,
        opener: false,
        reg: reg,
      );
      await _sessions().store(peer, o.record, device);
      return o.plaintext;
    }
    final info = _lib.preKeyMessageInfo(body);
    if (info.registrationId != reg) {
      throw const DeviceRefused('an opener under another registration id');
    }
    final kyberId = info.kyberPreKeyId;
    if (kyberId == null) {
      throw const ClassicRefused('an opener without the pq prekey');
    }
    final known =
        held != null &&
        _lib.sessionInfo(held).holds(info.version, info.baseKey);
    final print = _fingerprint(info, body);
    final kyber = s.kyberPreKeyStore;
    if (await kyber.wasRead(kyberId, print)) {
      throw const LsError(LsError.duplicate);
    }
    if (!known && await kyber.wasUsed(kyberId, info.baseKey)) {
      throw const LsError(LsError.duplicate);
    }
    // a device pair starts on a key made for sessions, a heal or the pool,
    // never on an invite's
    if (!known && !_kDeviceKyberUses.contains(await kyber.useOf(kyberId))) {
      throw const DeviceRefused('an opener on a key not made for devices');
    }
    final pk = info.preKeyId;
    final o = _lib.decryptPreKey(
      s.identity,
      s.registrationId,
      held,
      body,
      preKey: known || pk == null ? null : await s.preKeyStore.load(pk),
      signedPreKey: known
          ? null
          : await s.signedPreKeyStore.load(info.signedPreKeyId),
      kyberPreKey: known ? null : await kyber.load(kyberId),
      pinned: pin,
    );
    _requirePq(o.record);
    if (!_eq(o.identityKey, pin)) throw const LsError(LsError.untrusted);
    await admitted(
      o.identityKey,
      o.record,
      o.plaintext,
      opener: true,
      reg: info.registrationId,
    );
    // kept elsewhere: the session first, so a crash between leaves a key
    // unspent and the same opener opens on the session held
    final apart = store;
    if (apart != null) await _sessions(apart).store(peer, o.record, device);
    await s.database.transaction((t) async {
      if (apart == null) await _sessions(t).store(peer, o.record, device);
      final k = LsKyberPreKeyStore(t, prefix: s.tablePrefix, ident: s.ident);
      final usedPk = o.usedPreKey;
      if (usedPk != null) {
        await LsPreKeyStore(
          t,
          prefix: s.tablePrefix,
          ident: s.ident,
        ).remove(usedPk);
      }
      final usedK = o.usedKyberPreKey;
      if (usedK != null) {
        await k.markUsed(usedK, info.signedPreKeyId, info.baseKey);
      }
      await k.markRead(kyberId, print);
    });
    return o.plaintext;
  });

  // an opener by what its mac and keys cover, as SignalSession reads it
  Uint8List _fingerprint(LsPreKeyMessageInfo info, Uint8List body) {
    final outer = strictOpener(body);
    if (!_eq(outer.baseKey, info.baseKey) ||
        !_eq(outer.identity, info.identityKey)) {
      throw const LsError(LsError.message);
    }
    return Uint8List.fromList(
      sha256.convert([...outer.baseKey, ...outer.message]).bytes,
    );
  }

  /// a KDB1 of this store as [device] of its identity, for its phone's
  /// pool: its session signed prekey, a fresh one-time kyber prekey (gone
  /// once an opener on it opens, or kPoolKyberLife after it was made) and
  /// this store's key, which the list names. for a linked device's own
  /// store, whose key is its device key
  Future<Uint8List> makeBundle(int device, {int? now}) async {
    _linkedOnly(device);
    final ids = await s.sessionPreKeysForUse(now: now);
    return _kdb1(device, ids.signedId, await s.makePoolKyber(now: now));
  }

  /// the last resort KDB1 of this store as [device]: its session signed
  /// prekey and session kyber prekey. the phone hands it out when its pool
  /// has no one-time bundle left; it goes to the phone each time the
  /// session prekeys change (SignalSession.onSessionPreKeys)
  Future<Uint8List> lastResortBundle(int device, {int? now}) async {
    _linkedOnly(device);
    final ids = await s.sessionPreKeysForUse(now: now);
    return _kdb1(device, ids.signedId, ids.kyberId);
  }

  /// a KDB1 of this store as the phone (device 1, on its identity key):
  /// its session signed prekey and a fresh one-time kyber prekey from the
  /// pool's, so a contact's device can open to the phone. the phone's
  /// store only
  Future<Uint8List> phoneBundle({int? now}) async {
    if (linked) throw DeviceRefused('a linked device is not the phone');
    final ids = await s.sessionPreKeysForUse(now: now);
    final kyberId = await s.makePoolKyber(now: now);
    final spk = _lib.preKeyPublic(
      kLsSigned,
      (await s.signedPreKeyStore.load(ids.signedId))!,
    );
    final kyber = _lib.preKeyPublic(
      kLsKyber,
      (await s.kyberPreKeyStore.load(kyberId))!,
    );
    return Uint8List.fromList([
      ...ascii.encode('KDB1'),
      1,
      ...bundleBlock(registrationId: s.registrationId, spk: spk, kyber: kyber),
    ]);
  }

  void _linkedOnly(int device) {
    if (!isLinkedDevice(device)) {
      throw DeviceRefused('device $device is not a linked device');
    }
  }

  Future<Uint8List> _kdb1(int device, int signedId, int kyberId) async {
    final spk = _lib.preKeyPublic(
      kLsSigned,
      (await s.signedPreKeyStore.load(signedId))!,
    );
    final kyber = _lib.preKeyPublic(
      kLsKyber,
      (await s.kyberPreKeyStore.load(kyberId))!,
    );
    return Uint8List.fromList([
      ...ascii.encode('KDB1'),
      1,
      ...bundleBlock(
        registrationId: s.registrationId,
        spk: spk,
        kyber: kyber,
        deviceId: device,
        key: s.identity.public,
      ),
    ]);
  }
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
