// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices in the app: the engine's state loaded at the start, and
// what the session layer tells it. nothing here runs with the switch off

part of '../main.dart';

DeviceState? _deviceState;

/// the engine's linked-devices state, once loaded; null with the switch
/// off or before the start loaded it
DeviceState? get deviceState => _deviceState;

/// my identities for the engine: each one's key (ident_pub on a linked
/// device, else the key of its x_priv) and this device's key for it
Future<List<DevMine>> devMineOf(DatabaseExecutor db, KryfoSignal lib) async {
  final out = <DevMine>[];
  for (final r in await db.query(
    'identities',
    columns: ['id', 'x_priv', 'ident_pub'],
    where: 'retired_at IS NULL',
    orderBy: 'id',
  )) {
    final priv = r['x_priv'];
    if (priv is! List<int>) continue;
    final key = lib.identityFromPrivate(priv).public;
    final pub = r['ident_pub'];
    out.add((
      ident: r['id'] as int,
      identity: pub is List<int> ? Uint8List.fromList(pub) : key,
      key: key,
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
    final lib = signalSession.lib;
    final path = KryfoSignal.loadedFrom;
    if (path == null) throw StateError('the signal library has no path');
    final ds = DeviceState(DeviceEngine());
    await ds.load(db, await devMineOf(db, lib), shimPath: path);
    _deviceState = ds;
    if (ds.skipped > 0) dlog('devices: ${ds.skipped} rows did not load');
  } catch (e) {
    dlog('devices: not loaded (${e.runtimeType})');
  }
}

@visibleForTesting
void deviceStateForTest(DeviceState? ds) => _deviceState = ds;
