// SPDX-License-Identifier: GPL-3.0-or-later
// my own devices as rows: the one place a device is added, and with it the
// notice that stays on every own device until the person opens it. the
// device lists contacts get carry neither names nor dates; these rows are
// only the owner's
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../key_number.dart' show keyNumberGroups;
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
  LinkFlow linkFlow(String code, LinkHistory history) {
    final l = link;
    if (l == null) throw StateError('this device does not link');
    return l(code, history);
  }

  @override
  Future<void> opened() => openLinkNotices(db);
}
