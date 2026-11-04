// SPDX-License-Identifier: GPL-3.0-or-later
// receiving from devices in the app (device_receive.dart): a line on a
// device pair is opened and admitted there before anything is shown, and a
// contact's phone's list and bundle words are taken from the frames it
// sends. a hidden chat's go to the open vault's side, and are sealed for
// it while it is shut (devices_vault_app.dart). nothing here runs with the
// switch off

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
      // a hidden chat's device pairs, as the vault's cards name them
      final app = _madeApp;
      if (app != null && app._router.loaded) await app._listenHiddenDevices();
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
    // the state is not loaded yet: it comes again
    if (_deviceReceive == null) throw StateError('devices: not loaded');
    await _afterClose();
    // a hidden chat's contact: the open vault's side opens it, a shut one
    // takes it sealed as it came
    // a chat on the move: its rows land on their side first
    if (_moveDone != null) {
      final who =
          await _devHiddenOfTag(m.peer) ?? await _devEverydayOfTag(m.peer);
      if (who != null) await _afterMove(who, null);
    }
    final hidden = await _devHiddenOfTag(m.peer);
    final DeviceReceive? r;
    if (hidden != null) {
      final to = _routeOf(hidden, null);
      if (to == RouteTo.dropped) {
        await live.markSeen(h);
        arrived();
        return;
      }
      if (to == RouteTo.sealed && _relayOpened[h] == null) {
        await _sealDeviceLine(
          hidden,
          m.peer,
          m.cipher,
          wrappedAt: wrappedAt,
          reached: reached,
        );
        await live.markSeen(h);
        arrived();
        return;
      }
      r = _vaultDevReceive;
      // the vault's side is not running yet: it comes again
      if (r == null) throw StateError('devices: the vault\'s not loaded');
    } else {
      r = _deviceReceive;
    }
    final at = hidden;
    if (at != null) _arriving[at] = (_arriving[at] ?? 0) + 1;
    final before = _relayOpened[h];
    DevCopyIn? got;
    try {
      if (before != null) {
        got = (peer: before.id, frame: before.plain);
      } else {
        got = await r!.receive(m.peer, m.cipher);
        if (got != null) _keepOpened(h, got.peer, got.frame, epoch);
      }
    } finally {
      if (at != null) {
        final n = (_arriving[at] ?? 1) - 1;
        n > 0 ? _arriving[at] = n : _arriving.remove(at);
      }
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

  // the everyday contact a device-pair tag names, by their row
  Future<String?> _devEverydayOfTag(String tag) async {
    final t = deviceTagOf(tag);
    if (t == null) return null;
    final r = await (await live.open()).query(
      'contacts',
      columns: ['halo_id'],
      where: 'ikey = ? AND accepted = 1',
      whereArgs: ['05${t.peerX}'],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['halo_id'] as String;
  }

  // the hidden chat's contact a device-pair tag names: by the open vault's
  // rows, or by the cards while it is shut. null for anyone else
  Future<String?> _devHiddenOfTag(String tag) async {
    final t = deviceTagOf(tag);
    if (t == null) return null;
    final identity = '05${t.peerX}';
    final v = _openVault;
    if (v != null) {
      final r = await (await v.open()).query(
        'contacts',
        columns: ['halo_id'],
        where: 'ikey = ? AND accepted = 1',
        whereArgs: [identity],
        limit: 1,
      );
      if (r.isNotEmpty) return r.first['halo_id'] as String;
    }
    final c = _router.hiddenByIdentity(identity);
    return c != null && _devHidden(c) ? c : null;
  }

  // the device words of a frame from a contact's phone, taken where their
  // device state is ([home]) under the remote its open was admitted with,
  // or, opened from the seal, the one their phone's session runs on. true
  // when the frame says nothing else: it is never shown
  Future<bool> _devPhoneFrames(
    String peer,
    String wire, {
    HaloDb? home,
    bool unsealed = false,
  }) async {
    if (!linkedDevicesOn) return false;
    final only = deviceWordsOnly(wire);
    final at = home ?? live;
    final r = identical(at, live)
        ? _deviceReceive
        : identical(at, _vaultDevOf)
        ? _vaultDevReceive
        : null;
    if (r == null || !hasDeviceWords(wire)) return only;
    try {
      final db = await at.open();
      final row = await db.query(
        'contacts',
        columns: ['ident', 'ikey'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      final ikey = row.isEmpty ? null : row.first['ikey'] as String?;
      final remote = ikey == null
          ? null
          : unsealed
          ? await _heldPhoneRemote(peer, ikey)
          : _phoneRemoteOf(peer, ikey);
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
