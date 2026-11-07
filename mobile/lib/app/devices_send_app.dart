// SPDX-License-Identifier: GPL-3.0-or-later
// the send loop of linked devices in the app (device_send.dart): a seal to
// a contact goes to every device of theirs and of mine, the phone's copy
// back to the caller. nothing here runs with the switch off

part of '../main.dart';

DeviceSend? _deviceSend;

/// the send loop, once the device state loaded; null with the switch off
DeviceSend? get deviceSend => _deviceSend;

@visibleForTesting
void deviceSendForTest(DeviceSend? s) => _deviceSend = s;

final _devSessions = <int, DeviceSessions>{};

@visibleForTesting
DeviceWire get engineDeviceWireForTest => _EngineDeviceWire();

class _EngineDeviceWire implements DeviceWire {
  // nothing of the everyday account leaves while the decoy is open, own
  // sync included: the copy waits in dev_out
  static bool get _held => _madeApp?.everydayHeld ?? false;

  @override
  Future<String> send(int ident, String arg, String cipher) async =>
      _held ? 'held' : engine.nostrSendDevice(ident, arg, cipher);
  @override
  Future<String> sendOpener(int ident, String arg, String cipher) async =>
      _held ? 'held' : engine.nostrSendDevice(ident, arg, cipher, opener: true);
}

// after the state loaded: the engine takes device-pair args from now on
void _bootDeviceSend(DeviceState ds) {
  final r = engine.devicePairsOn(true);
  if (r != 'ok') dlog('devices: pairs not on ($r)');
  _devSessions.clear();
  _deviceSend = DeviceSend(
    state: ds,
    db: live.open,
    sessions: (ident) async {
      final ss = await signalOfIdent(ident);
      final held = _devSessions[ident];
      if (held != null && identical(held.s, ss)) return held;
      return _devSessions[ident] = DeviceSessions(ss);
    },
    wire: _EngineDeviceWire(),
    listen: engine.deviceListenBg,
    door: _devDoor,
    hiddenRemovals: true,
    changed: (changes) {
      final a = _madeApp;
      if (a == null) return;
      unawaited(
        a._hiddenListsChanged(changes).catchError((Object e) {
          dlog('devices: hidden chats not told (${e.runtimeType})');
        }),
      );
    },
  );
  _bootDeviceReceive(ds, _deviceSend!);
}

// my identity [ident] and the contact [peer] as the send loop takes them,
// from their row [on] (the everyday container unless the open vault holds
// them); null for a contact with no identity key on its row
Future<({DevMe me, DevContact c})?> _devWhoOf(
  int ident,
  String peer,
  SignalSession ss, {
  HaloDb? on,
}) async {
  final db = await (on ?? live).open();
  final r = await db.query(
    'contacts',
    columns: ['ikey', 'caps'],
    where: 'halo_id = ? AND ident = ?',
    whereArgs: [peer, ident],
    limit: 1,
  );
  final ikey = r.isEmpty ? null : r.first['ikey'] as String?;
  if (ikey == null) return null;
  // the whole row: a file from before the column has none, and is a phone
  final id = await (await live.open()).query(
    'identities',
    where: 'id = ?',
    whereArgs: [ident],
    limit: 1,
  );
  final info = await ss.sessionInfo(peer);
  return (
    me: (
      ident: ident,
      identity: ss.identity.public,
      device: id.isEmpty ? 1 : (id.first['dev_id'] as int? ?? 1),
    ),
    c: (
      peer: peer,
      identity: ikey,
      devices: capsOfText(r.first['caps'] as String?).contains(kCapDevices),
      phoneClassic: info != null && (info.version < 4 || !info.pq),
    ),
  );
}

// signalSeal's fan-out: every copy of [framed] to [peer] and to my own
// devices, the phone's copy sealed by [phone] and handed back. null when
// the phone alone takes it: today's seal then, byte for byte
Future<String?> _deviceSeal(
  int ident,
  SignalSession ss,
  String peer,
  String framed,
  DevPhone phone,
) async {
  if (!linkedDevicesOn || isDevId(peer)) return null;
  // a hidden chat's go from the open vault's side, never while it is shut
  final home = _devHomeDb(peer);
  final send = home == null ? null : _devSendFor(peer);
  if (send == null) return null;
  // anything of the devices' that fails before the phone's copy is sealed
  // leaves that copy to today's seal: a device never stops the chat. what
  // the phone's own seal throws (a key held, an answer awaited) is the
  // chat's, as today
  var sealing = false;
  try {
    final who = await _devWhoOf(ident, peer, ss, on: home);
    if (who == null) return null;
    // my own devices get a copy only of a chat they share (devices_own_app)
    var own = false;
    try {
      own =
          identical(home, live) &&
          _ownSends &&
          await _ownChatShared((id: peer, group: false));
    } catch (e) {
      dlog('devices: no own copy (${e.runtimeType})');
    }
    final b = await send.burst(
      who.me,
      who.c,
      framed,
      ownCopy: own,
      phone: (
        measure: phone.measure,
        seal: (f, n) {
          sealing = true;
          return phone.seal(f, n);
        },
      ),
    );
    return b?.phone;
  } catch (e) {
    if (sealing) rethrow;
    dlog('devices: no copies for devices (${e.runtimeType})');
    return null;
  }
}

// a linked device's seal: every copy of [framed] to [peer]'s devices and
// my own, queued and handed out here. false when none could go: a contact
// this device holds no list of, an older Kryfo, a hidden chat
Future<bool> _deviceSealHere(
  int ident,
  SignalSession ss,
  String peer,
  String framed,
) async {
  if (!linkedDevicesOn || isDevId(peer)) return false;
  final send = _deviceSend;
  if (send == null || !identical(_devHomeDb(peer), live)) return false;
  try {
    final who = await _devWhoOf(ident, peer, ss);
    if (who == null || !who.c.devices) return false;
    final b = await send.burst(
      who.me,
      who.c,
      framed,
      force: true,
      ownCopy: _ownSends && await _ownChatShared((id: peer, group: false)),
      // a contact whose devices never wrote to this one is not reached
      mustReach: true,
    );
    return b != null && b.copies > 0;
  } catch (e) {
    dlog('devices: no copies from this device (${e.runtimeType})');
    return false;
  }
}

Future<bool> Function(String peer)? _reachesForTest;

@visibleForTesting
set deviceReachesForTest(Future<bool> Function(String peer)? f) =>
    _reachesForTest = f;

/// on a linked device, whether this device reaches [peer] itself: a device
/// of theirs holds a session with it. false sends from the phone
Future<bool> deviceReaches(String peer) async {
  if (!linkedDevicesOn || !linkedRole || isDevId(peer)) return false;
  final f = _reachesForTest;
  if (f != null) return f(peer);
  final send = _deviceSend;
  if (send == null || !identical(_devHomeDb(peer), live)) return false;
  try {
    final ident = identOfPeer(peer);
    final who = await _devWhoOf(ident, peer, await signalOfIdent(ident));
    if (who == null || !who.c.devices) return false;
    return await send.reaches(who.me, who.c);
  } catch (e) {
    dlog('devices: reach not read (${e.runtimeType})');
    return false;
  }
}

/// the copies owed to devices and the list pushes due, with the outbox:
/// the everyday side's, and the open vault's
Future<void> pumpDeviceSends() async {
  if (!linkedDevicesOn) return;
  await _pumpDevices(_deviceSend, live);
  final v = _vaultDevOf;
  if (v != null) await _pumpDevices(_vaultDevSend, v);
  await _madeApp?._pushHiddenRemovals();
  // lists a restore left: asked again until each phone sends its own, the
  // open vault's by its own side
  for (final r in [_deviceReceive, _vaultDevReceive]) {
    try {
      await r?.askStale();
    } catch (e) {
      dlog('devices: stale lists not asked (${e.runtimeType})');
    }
  }
}

Future<void> _pumpDevices(DeviceSend? send, HaloDb home) async {
  if (send == null) return;
  try {
    await send.pump();
    await send.pushes(
      contact: (ident, identity) async {
        final db = await home.open();
        final r = await db.query(
          'contacts',
          columns: ['halo_id'],
          where: 'ident = ? AND ikey = ? AND accepted = 1 AND blocked = 0',
          whereArgs: [ident, identity],
          limit: 1,
        );
        if (r.isEmpty) return null;
        final ss = await signalOfIdent(ident);
        return _devWhoOf(ident, r.first['halo_id'] as String, ss, on: home);
      },
      phone: (me, c) => _devicePushPhone(me.ident, c.peer),
      send: (me, c, cipher) async {
        final x = await peerXPubOf(c.peer);
        if (x == null) return false;
        return await engine.nostrSend(me.ident, x, cipher) == 'ok';
      },
    );
  } catch (e) {
    dlog('devices: pump (${e.runtimeType})');
  }
}

// a contact's phone showed it reads lists: my list goes to them once
Future<void> _devicesShown(String peer) async {
  if (!linkedDevicesOn) return;
  final home = _devHomeDb(peer);
  final send = _devSendFor(peer);
  if (home == null || send == null) return;
  try {
    final db = await home.open();
    final r = await db.query(
      'contacts',
      columns: ['ident', 'ikey', 'caps'],
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    final ikey = r.isEmpty ? null : r.first['ikey'] as String?;
    if (ikey == null) return;
    // only to a phone that reads lists
    if (!capsOfText(r.first['caps'] as String?).contains(kCapDevices)) return;
    final ident = r.first['ident'] as int? ?? kMainIdent;
    await send.devicesShown(ident, ikey);
    // and theirs is asked for when none is held (they may have kept me
    // since before I deleted them)
    await _devReceiveFor(peer)?.askList(ident, ikey);
  } catch (e) {
    dlog('devices: list push not queued (${e.runtimeType})');
  }
}

// a contact just added or accepted (subscribePeer, fresh): one who reads
// lists gets mine at once, as one I deleted and added again may still
// hold an old one naming a device I removed since
@visibleForTesting
Future<void> devAddedForTest(String haloId) => _devAdded(haloId);

Future<void> _devAdded(String haloId) async {
  if (!linkedDevicesOn || sessionQuiet || isDevId(haloId)) return;
  await _devicesShown(haloId);
}

// a contact goes (deleted, released, "not them"): the engine forgets their
// lists, quiet rows and proofs, and nothing more goes to them or their
// devices, a list or a removal owed included. nothing is sent for the delete.
// read before their row goes. a later message from their phone adds them
// again, as a new contact's does
@visibleForTesting
Future<void> devForgetForTest(String haloId) => _devForget(haloId);

Future<void> _devForget(String haloId, {bool sessions = false}) async {
  final ds = _deviceState;
  if (ds == null || !linkedDevicesOn || isDevId(haloId)) return;
  // a hidden chat's from the open vault; nothing while it is shut
  final home = _devHomeDb(haloId);
  if (home == null) return;
  final vault = !identical(home, live);
  try {
    final db = await home.open();
    final r = await db.query(
      'contacts',
      columns: ['ident', 'ikey'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    final ikey = r.isEmpty ? null : r.first['ikey'] as String?;
    if (ikey == null) return;
    final ident = r.first['ident'] as int? ?? kMainIdent;
    // their device pairs are heard on no more (read before the list goes)
    await _devReceiveFor(haloId)?.forget(ident, ikey);
    try {
      await ds.call(db, 'forget', {'identity': ikey});
    } on DevRefused catch (e) {
      if (e.why != 'unknown') rethrow;
    }
    if (vault) _vaultDevPeers.remove(ikey);
    await _devSendFor(haloId)?.forget(ident, ikey);
    // "not them": their devices' sessions go too, as their phone's does
    if (sessions) {
      final dss = DeviceSessions(
        await signalOfIdent(ident),
        store: vault ? await home.open() : null,
      );
      for (final h in await dss.held(haloId)) {
        await dss.drop(haloId, h.device);
      }
    }
  } catch (e) {
    dlog('devices: a contact not forgotten (${e.runtimeType})');
  }
}
