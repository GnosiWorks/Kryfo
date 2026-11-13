// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices in the app: the engine's state loaded at the start, and
// what the session layer tells it. nothing here runs with the switch off

part of '../main.dart';

DeviceState? _deviceState;

/// the engine's linked-devices state, once loaded; null with the switch
/// off or before the start loaded it
DeviceState? get deviceState => _deviceState;

/// my identities for the engine: each one's key (ident_pub on a linked
/// device, else the key of its x_priv), this device's key for it and its
/// id on the list, so the engine derives every address as this device
Future<List<DevMine>> devMineOf(DatabaseExecutor db, KryfoSignal lib) async {
  final out = <DevMine>[];
  for (final r in await db.query(
    'identities',
    columns: ['id', 'x_priv', 'ident_pub', 'dev_id'],
    where: 'retired_at IS NULL',
    orderBy: 'id',
  )) {
    final priv = r['x_priv'];
    if (priv is! List<int>) continue;
    final key = lib.identityFromPrivate(priv).public;
    final pub = r['ident_pub'];
    final linked = pub is List<int>;
    out.add((
      ident: r['id'] as int,
      identity: linked ? Uint8List.fromList(pub) : key,
      key: key,
      dev: linked ? (r['dev_id'] as int? ?? 1) : 1,
    ));
  }
  return out;
}

/// loads the state from the everyday container, after the signal store
/// opened. a failure leaves it unloaded: nothing device-related is sent
Future<void> bootDevices() async {
  if (!linkedDevicesOn) return;
  try {
    final db = await live.open();
    // a role not read leaves the one held: the engine's load below still
    // runs, so a link that failed never leaves it as the device it was to be
    try {
      await readLinkedRole(db);
    } catch (e) {
      dlog('devices: the role not read (${e.runtimeType})');
    }
    // a role the boot could not read before tor started
    if (linkedRole) unawaited(torAsLinked(at: 'load'));
    // a linked device past its end ends before anything of it runs: no
    // listens, no copies opened or shown
    final end = await _linkedPeek();
    final lib = signalSession.lib;
    final path = KryfoSignal.loadedFrom;
    if (path == null) throw StateError('the signal library has no path');
    final ds = DeviceState(DeviceEngine());
    await ds.load(db, await devMineOf(db, lib), shimPath: path);
    _deviceState = ds;
    if (end != null) {
      await _linkedEnds(end);
      return;
    }
    // a restored phone's first lists name it alone, before anything goes
    final restored = linkedRole
        ? const <({int ident, int version, List<int> added, bool removed})>[]
        : await restoredLists(db, ds, (ident, body) async {
            final ss = await signalOfIdent(ident);
            return ss.lib.sign(ss.identity, LsSigContext.deviceList, body);
          });
    _bootDeviceSend(ds);
    if (restored.isNotEmpty) await _deviceSend?.listsChanged(restored);
    if (ds.skipped > 0) dlog('devices: ${ds.skipped} rows did not load');
  } catch (e) {
    dlog('devices: not loaded (${e.runtimeType})');
  }
  // a linked device's own end is checked whatever else loaded
  try {
    await _linkedBoot();
  } catch (e) {
    dlog('devices: the lock state not checked (${e.runtimeType})');
  }
  // and its start check reads from here on
  _devicesBooted = true;
}

@visibleForTesting
void deviceStateForTest(DeviceState? ds) => _deviceState = ds;
