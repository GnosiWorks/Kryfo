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

class _EngineDeviceWire implements DeviceWire {
  @override
  Future<String> send(int ident, String arg, String cipher) =>
      engine.nostrSendDevice(ident, arg, cipher);
  @override
  Future<String> sendOpener(int ident, String arg, String cipher) =>
      engine.nostrSendDevice(ident, arg, cipher, opener: true);
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
  );
  _bootDeviceReceive(ds, _deviceSend!);
}

// my identity [ident] and the contact [peer] as the send loop takes them;
// null for a contact with no identity key on its row
Future<({DevMe me, DevContact c})?> _devWhoOf(
  int ident,
  String peer,
  SignalSession ss,
) async {
  final db = await live.open();
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
  final id = await db.query(
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
  final send = _deviceSend;
  if (send == null || !linkedDevicesOn || isDevId(peer)) return null;
  // anything of the devices' that fails before the phone's copy is sealed
  // leaves that copy to today's seal: a device never stops the chat. what
  // the phone's own seal throws (a key held, an answer awaited) is the
  // chat's, as today
  var sealing = false;
  try {
    final who = await _devWhoOf(ident, peer, ss);
    if (who == null) return null;
    final b = await send.burst(
      who.me,
      who.c,
      framed,
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

/// the copies owed to devices and the list pushes due, with the outbox
Future<void> pumpDeviceSends() async {
  final send = _deviceSend;
  if (send == null || !linkedDevicesOn) return;
  try {
    await send.pump();
    await send.pushes(
      contact: (ident, identity) async {
        final db = await live.open();
        final r = await db.query(
          'contacts',
          columns: ['halo_id'],
          where: 'ident = ? AND ikey = ? AND accepted = 1 AND blocked = 0',
          whereArgs: [ident, identity],
          limit: 1,
        );
        if (r.isEmpty) return null;
        final ss = await signalOfIdent(ident);
        return _devWhoOf(ident, r.first['halo_id'] as String, ss);
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
  final send = _deviceSend;
  if (send == null || !linkedDevicesOn) return;
  try {
    final db = await live.open();
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
    await _deviceReceive?.askList(ident, ikey);
  } catch (e) {
    dlog('devices: list push not queued (${e.runtimeType})');
  }
}

// a contact goes (deleted, released, "not them"): the engine forgets their
// lists, quiet rows and proofs, and nothing more goes to their devices.
// read before their row goes. a later message from their phone adds them
// again, as a new contact's does
Future<void> _devForget(String haloId, {bool sessions = false}) async {
  final ds = _deviceState;
  if (ds == null || !linkedDevicesOn || isDevId(haloId)) return;
  try {
    final db = await live.open();
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
    await _deviceReceive?.forget(ident, ikey);
    try {
      await ds.call(db, 'forget', {'identity': ikey});
    } on DevRefused catch (e) {
      if (e.why != 'unknown') rethrow;
    }
    await _deviceSend?.forget(ident, ikey);
    // "not them": their devices' sessions go too, as their phone's does
    if (sessions) {
      final dss = DeviceSessions(await signalOfIdent(ident));
      for (final h in await dss.held(haloId)) {
        await dss.drop(haloId, h.device);
      }
    }
  } catch (e) {
    dlog('devices: a contact not forgotten (${e.runtimeType})');
  }
}
