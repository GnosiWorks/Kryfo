// SPDX-License-Identifier: GPL-3.0-or-later
// receiving from devices in the app (device_receive.dart): a line on a
// device pair is opened and admitted there before anything is shown, and a
// contact's phone's list and bundle words are taken from the frames it
// sends. the everyday side only: a hidden chat's device pairs are never
// heard, and nothing of a vault contact's is written here. nothing here
// runs with the switch off

part of '../main.dart';

DeviceReceive? _deviceReceive;

/// the receiving side of linked devices, once the device state loaded
DeviceReceive? get deviceReceive => _deviceReceive;

@visibleForTesting
void deviceReceiveForTest(DeviceReceive? r) => _deviceReceive = r;

class _EngineDeviceListen implements DeviceListen {
  @override
  void listen(int ident, String arg) => engine.deviceListenBg(ident, arg);
  @override
  void unlisten(int ident, String arg) => engine.deviceUnlistenBg(ident, arg);
  @override
  Future<String> seed(int ident, String arg, String seedHex) =>
      engine.pairSeed(ident, arg, seedHex);
}

// this device on my identity [ident]: the identity's key (ident_pub on a
// linked device) and this device's id on it
Future<DevMe?> _devMeOf(int ident) async {
  final db = await live.open();
  final r = await db.query(
    'identities',
    where: 'id = ? AND retired_at IS NULL',
    whereArgs: [ident],
    limit: 1,
  );
  if (r.isEmpty) return null;
  final pub = r.first['ident_pub'];
  final ss = await signalOfIdent(ident);
  return (
    ident: ident,
    identity: pub is List<int> ? Uint8List.fromList(pub) : ss.identity.public,
    device: r.first['dev_id'] as int? ?? 1,
  );
}

// a contact of my [ident] by their identity key: accepted, not blocked,
// and on the everyday side
Future<({DevMe me, DevContact c})?> _devContactByKey(
  int ident,
  String identity,
) async {
  final db = await live.open();
  final r = await db.query(
    'contacts',
    columns: ['halo_id'],
    where: 'ident = ? AND ikey = ? AND accepted = 1 AND blocked = 0',
    whereArgs: [ident, identity],
    limit: 1,
  );
  if (r.isEmpty) return null;
  final peer = r.first['halo_id'] as String;
  if (appState._routeOf(peer, null) != RouteTo.everyday) return null;
  final ss = await signalOfIdent(ident);
  return _devWhoOf(ident, peer, ss);
}

// a blocked contact of my [ident] by their identity key, on the everyday
// side: their devices' copies are opened, admitted and left to the block
Future<({DevMe me, DevContact c})?> _devBlockedByKey(
  int ident,
  String identity,
) async {
  final db = await live.open();
  final r = await db.query(
    'contacts',
    columns: ['halo_id'],
    where: 'ident = ? AND ikey = ? AND accepted = 1 AND blocked = 1',
    whereArgs: [ident, identity],
    limit: 1,
  );
  if (r.isEmpty) return null;
  final peer = r.first['halo_id'] as String;
  if (appState._routeOf(peer, null) != RouteTo.everyday) return null;
  final ss = await signalOfIdent(ident);
  return _devWhoOf(ident, peer, ss);
}

// a frame of mine to [c]'s phone alone, on the identity pair
Future<bool> _devPhoneSend(DevMe me, DevContact c, String frame) async {
  try {
    final p = _devicePushPhone(me.ident, c.peer);
    final cipher = await p.seal(frame, await p.measure(frame) ?? 0);
    final x = await peerXPubOf(c.peer);
    if (x == null) return false;
    return await engine.nostrSend(me.ident, x, cipher) == 'ok';
  } catch (e) {
    dlog('devices: a frame to a phone not sent (${e.runtimeType})');
    return false;
  }
}

// after the send loop: the receiving side, the device seeds the engine
// refused before pairs were on, and every device pair heard on
void _bootDeviceReceive(DeviceState ds, DeviceSend send) {
  _deviceReceive = DeviceReceive(
    state: ds,
    db: live.open,
    sessions: send.sessions,
    send: send,
    listener: _EngineDeviceListen(),
    open: deviceOpenAt,
    me: _devMeOf,
    contact: _devContactByKey,
    blockedChat: _devBlockedByKey,
    phone: _devPhoneSend,
    sign: (ident, body) async {
      final ss = await signalOfIdent(ident);
      return ss.lib.sign(ss.identity, LsSigContext.deviceList, body);
    },
    shown: (c) async {
      final went = await appState._applyDeviceCopy(c);
      if (AppState._shown(went)) appState.notifyListeners();
    },
  );
  unawaited(() async {
    try {
      await pushPairSeeds();
      await _deviceReceive?.listenAll();
    } catch (e) {
      dlog('devices: device pairs not heard (${e.runtimeType})');
    }
  }());
}

extension AppStateDevices on AppState {
  // a line on a device pair: opened and admitted in device_receive.dart;
  // what a contact's device wrote is filed as theirs. one that throws comes
  // again, and what it opened to is kept for that
  Future<void> _receiveDeviceCopy(
    ({String peer, String cipher}) m,
    String h,
    int epoch,
    void Function() arrived, {
    int? wrappedAt,
    Reached? reached,
  }) async {
    final r = _deviceReceive;
    // the state is not loaded yet: it comes again
    if (r == null) throw StateError('devices: not loaded');
    final before = _relayOpened[h];
    DevCopyIn? got;
    if (before != null) {
      got = (peer: before.id, frame: before.plain);
    } else {
      got = await r.receive(m.peer, m.cipher);
      if (got != null) _keepOpened(h, got.peer, got.frame, epoch);
    }
    if (got == null) {
      await live.markSeen(h);
      arrived();
      return;
    }
    final went = await _applyDeviceCopy(
      got,
      wrappedAt: wrappedAt,
      reached: reached,
    );
    await live.markSeen(h);
    _relayOpened.take(h);
    if (AppState._shown(went)) {
      notifyListeners();
      arrived();
    }
  }

  Future<RouteTo> _applyDeviceCopy(
    DevCopyIn c, {
    int? wrappedAt,
    Reached? reached,
  }) => _applyIncomingPayload(
    c.peer,
    unwrapMessage(c.frame),
    wire: c.frame,
    fromDevice: true,
    wrappedAt: wrappedAt,
    reached: reached,
  );

  // the device words of a frame from a contact's phone, taken under the
  // remote its open was admitted with. true when the frame says nothing
  // else: it is never shown
  Future<bool> _devPhoneFrames(String peer, String wire) async {
    if (!linkedDevicesOn) return false;
    final only = deviceWordsOnly(wire);
    final r = _deviceReceive;
    if (r == null || !hasDeviceWords(wire)) return only;
    try {
      final db = await live.open();
      final row = await db.query(
        'contacts',
        columns: ['ident', 'ikey'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      final ikey = row.isEmpty ? null : row.first['ikey'] as String?;
      final remote = ikey == null ? null : _phoneRemoteOf(peer, ikey);
      if (remote == null) return only;
      await r.takePhone(
        row.first['ident'] as int? ?? kMainIdent,
        ikey!,
        wire,
        remote,
      );
    } catch (e) {
      dlog('devices: a phone\'s device words not taken (${e.runtimeType})');
    }
    return only;
  }
}
