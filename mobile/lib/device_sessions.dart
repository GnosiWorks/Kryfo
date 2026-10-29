// SPDX-License-Identifier: GPL-3.0-or-later
// sessions with a contact's devices 2..127, and with this account's own
// other devices, next to the phone's (device 1) in the same store. each is
// built from that device's KDB1 and runs only on the key its identity's
// signed list names; every one is pqxdh with the pq ratchet. on a linked
// device the phones are such sessions too: it has no chat of its own from
// before. which devices get a copy and which may send is engine/devices'
// to say (Fanout, Admit)

import 'dart:convert';
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

/// a device on a list other than the phone
bool isLinkedDevice(int device) => device >= 2 && device <= 127;

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
  DeviceSessions(this.s, {this.linked = false});

  /// the identity's store the sessions live in
  final SignalSession s;

  /// the store is a linked device's: a contact's phone is a device here too
  final bool linked;

  bool _takes(int device) => isLinkedDevice(device) || (linked && device == 1);

  KryfoSignal get _lib => s.lib;
  final Map<String, Future<void>> _steps = {};

  int _now() => DateTime.now().millisecondsSinceEpoch;

  LsSessionStore _sessions([DatabaseExecutor? t]) =>
      LsSessionStore(t ?? s.database, prefix: s.tablePrefix, ident: s.ident);

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
  /// parseDeviceBundle under the contact's identity), in place of any
  /// held. [pin] and [reg] are the device's list entry
  Future<void> build(
    String peer,
    int device,
    LsBlock block,
    Uint8List pin,
    int reg,
  ) => _serial(peer, device, () async {
    // the key the bundle runs on: the device's own, or the identity for a
    // phone
    if (block.deviceId != device ||
        block.registrationId != reg ||
        (block.key == null) != (device == 1) ||
        !_eq(block.bundle.identityKey, pin)) {
      throw const DeviceRefused('a bundle that is not the listed device');
    }
    final (record, their) = _lib.sessionFromBundle(
      s.identity,
      s.registrationId,
      null,
      block.bundle,
      _now(),
      pinned: pin,
    );
    _requirePq(record);
    if (!_eq(their, pin)) throw const LsError(LsError.untrusted);
    await _sessions().store(peer, record, device);
  });

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
  /// frame, the others get theirs
  Future<String> seal(String peer, int device, String plain, Uint8List pin) =>
      _serial(peer, device, () async {
        final record = await _sessions().load(peer, device);
        if (record == null) throw const LsError(LsError.noSession);
        final String padded;
        if (_trialType(record, pin) == kLsPreKey) {
          final o = padSealOpener(plain);
          if (o == null) throw WaitsForAnswer(peer);
          padded = o;
        } else {
          padded = padSeal(plain);
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
      });

  /// [body] of [type] from [peer]'s [device] opened, on the session held or
  /// on an opener built on this store's session prekeys. [pin] and [reg]
  /// are the device's list entry; an opener under another reg is refused.
  /// nothing is stored before it opens, and an opener opens once
  Future<Uint8List> open(
    String peer,
    int device,
    int type,
    Uint8List body,
    Uint8List pin, {
    required int reg,
  }) => _serial(peer, device, () async {
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
    await s.database.transaction((t) async {
      await _sessions(t).store(peer, o.record, device);
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

  /// a KDB1 of this store as [device] of its identity: its session signed
  /// prekey, a fresh one-time kyber prekey (gone once an opener on it opens,
  /// or after 16 days) and this store's key, which the list names. for a
  /// linked device's own store, whose key is its device key
  Future<Uint8List> makeBundle(int device) async {
    if (!isLinkedDevice(device)) {
      throw DeviceRefused('device $device is not a linked device');
    }
    final ids = await s.sessionPreKeysForUse();
    final kyberId = await s.makeHealKyber();
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
