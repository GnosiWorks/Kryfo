// SPDX-License-Identifier: GPL-3.0-or-later
// my own devices as rows: the one place a device is added, and with it the
// notice that stays on every own device until the person opens it. the
// device lists contacts get carry neither names nor dates; these rows are
// only the owner's
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../key_number.dart' show keyNumberGroups;
import 'device_store.dart' show applyDevRows;
import 'link_flow.dart';
import 'own_devices.dart';

/// one key of a device of mine: its id and key on identity [ident]'s list
typedef OwnDeviceKey = ({int ident, int dev, String key, int reg});

/// a device linked that the person has not looked at yet
@immutable
class LinkNotice {
  const LinkNotice({required this.uid, required this.name, required this.at});
  final String uid;
  final String name;
  final DateTime at;
}

/// the notices not opened yet, for the home card; null until read
final linkNotices = ValueNotifier<List<LinkNotice>>(const []);

String newDeviceUid([Random? r]) {
  final rnd = r ?? Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// a device of mine, and its notice: never one without the other. inside
/// [db]'s transaction when it is one, so the two land together
Future<void> addOwnDevice(
  DatabaseExecutor db, {
  required String uid,
  required String name,
  required DeviceKind kind,
  required DateTime linkedAt,
  required List<OwnDeviceKey> keys,
  Uint8List? stream,
}) async {
  // a device key already on a device of mine is that device again: refused
  // with its notice, whatever uid it came under
  for (final k in keys) {
    final had = await db.rawQuery(
      'SELECT 1 FROM own_device_keys k JOIN own_devices d ON d.uid = k.uid '
      'WHERE k.ident = ? AND k.key = ? AND d.removed_at IS NULL LIMIT 1',
      [k.ident, k.key],
    );
    if (had.isNotEmpty) throw StateError('this device is linked already');
  }
  await db.insert('own_devices', {
    'uid': uid,
    'name': name,
    'kind': kind == DeviceKind.phone ? 'phone' : 'computer',
    'linked_at': linkedAt.millisecondsSinceEpoch,
    'notice': 1,
    'stream': ?stream,
  }, conflictAlgorithm: ConflictAlgorithm.abort);
  for (final k in keys) {
    await db.insert('own_device_keys', {
      'uid': uid,
      'ident': k.ident,
      'dev_id': k.dev,
      'key': k.key,
      'reg': k.reg,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// where a linked device keeps its history stream's key until the copy
const kLinkStreamMeta = 'link_stream';

/// a new device linked, written at once: identities row 0 names the
/// account it serves ([identity]) and its id there, the own list's rows the
/// engine gave, and the history stream's key. nothing of it before the
/// phone kept the device, so a link that fails leaves a fresh install
Future<void> joinedRows(
  Database db, {
  required Uint8List identity,
  required int device,
  required List<dynamic> rows,
  required Uint8List stream,
}) => db.transaction((tx) async {
  final n = await tx.update('identities', {
    'ident_pub': identity,
    'dev_id': device,
  }, where: 'id = 0');
  if (n != 1) throw StateError('no identity to link');
  await applyDevRows(tx, rows);
  await tx.insert('signal_meta', {
    'k': kLinkStreamMeta,
    'v': base64Encode(stream),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
});

/// whether this container is a linked device's
Future<bool> linkedRoleOf(DatabaseExecutor db) async {
  final r = await db.query(
    'identities',
    columns: ['ident_pub'],
    where: 'id = 0',
    limit: 1,
  );
  return r.isNotEmpty && r.first['ident_pub'] is List<int>;
}

/// the notices not opened yet, oldest first, read into [linkNotices]
Future<List<LinkNotice>> readLinkNotices(DatabaseExecutor db) async {
  final out = [
    for (final r in await db.query(
      'own_devices',
      columns: ['uid', 'name', 'linked_at'],
      where: 'notice = 1 AND removed_at IS NULL',
      orderBy: 'linked_at',
    ))
      LinkNotice(
        uid: r['uid'] as String,
        name: r['name'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(r['linked_at'] as int),
      ),
  ];
  linkNotices.value = out;
  return out;
}

/// the person opened the devices page: every notice has done its job
Future<void> openLinkNotices(DatabaseExecutor db) async {
  await db.update('own_devices', {'notice': 0}, where: 'notice = 1');
  linkNotices.value = const [];
}

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

/// my devices from the rows. on the phone it can link one more; on a
/// linked device the phone shows as one of them and linking is the phone's
class StoredOwnDevices implements OwnDevices {
  StoredOwnDevices({
    required this.db,
    required this.thisName,
    this.thisKind = DeviceKind.phone,
    this.phoneName,
    this.link,
    this.unlink,
  });

  final DatabaseExecutor db;
  final String thisName;
  final DeviceKind thisKind;

  /// set on a linked device: its phone's name in the list
  final String? phoneName;

  /// a link from a scanned code; null where this device cannot link
  final LinkFlow Function(String code, LinkHistory history)? link;

  /// taking a device off the list (the removal step); none yet
  final Future<void> Function(String uid)? unlink;

  @override
  Future<List<OwnDevice>> load() async {
    final keys = <String, String>{};
    for (final r in await db.query(
      'own_device_keys',
      columns: ['uid', 'key'],
      where: 'ident = 0',
    )) {
      keys[r['uid'] as String] = r['key'] as String;
    }
    return [
      OwnDevice(id: 'this', name: thisName, kind: thisKind, thisDevice: true),
      if (phoneName != null)
        OwnDevice(id: 'phone', name: phoneName!, kind: DeviceKind.phone),
      for (final r in await db.query(
        'own_devices',
        where: 'removed_at IS NULL',
        orderBy: 'linked_at',
      ))
        OwnDevice(
          id: r['uid'] as String,
          name: r['name'] as String,
          kind: r['kind'] == 'phone' ? DeviceKind.phone : DeviceKind.computer,
          linkedAt: DateTime.fromMillisecondsSinceEpoch(r['linked_at'] as int),
          code: switch (keys[r['uid']]) {
            final String k => keyNumberGroups(_unhex(k)) ?? const [],
            null => const [],
          },
        ),
    ];
  }

  @override
  Future<void> rename(String id, String name) => db.update(
    'own_devices',
    {'name': name},
    where: 'uid = ?',
    whereArgs: [id],
  );

  @override
  Future<void> remove(String id) async => unlink?.call(id);

  @override
  Future<void> removeOthers() async {
    final u = unlink;
    if (u == null) return;
    for (final d in await load()) {
      if (!d.thisDevice && !d.isPhone) await u(d.id);
    }
  }

  @override
  bool get canLink => link != null && phoneName == null;

  @override
  bool get linksHere => canLink;

  @override
  bool get linkedDevice => phoneName != null;

  @override
  LinkFlow linkFlow(String code, LinkHistory history) {
    final l = link;
    if (l == null) throw StateError('this device does not link');
    return l(code, history);
  }

  @override
  Future<void> opened() => openLinkNotices(db);
}
