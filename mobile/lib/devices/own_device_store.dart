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

/// a device linked, or one that went, that the person has not looked at
/// yet. [why] is null for a device linked; else why it went
/// (own_unlink.dart's kGone words), [at] when
@immutable
class LinkNotice {
  const LinkNotice({
    required this.uid,
    required this.name,
    required this.at,
    this.why,
  });
  final String uid;
  final String name;
  final DateTime at;
  final String? why;
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
  String? hist,
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
    'hist': ?hist,
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

/// the history copy's place for device [uid] on the phone, with the
/// link's stream key while the copy is under way; null for none
Future<({Map<String, Object?> hist, Uint8List? stream})?> historyCopyOf(
  DatabaseExecutor db,
  String uid,
) async {
  final r = await db.query(
    'own_devices',
    columns: ['stream', 'hist'],
    where: 'uid = ? AND removed_at IS NULL',
    whereArgs: [uid],
  );
  if (r.isEmpty || r.first['hist'] is! String) return null;
  try {
    final h = jsonDecode(r.first['hist'] as String) as Map;
    final s = r.first['stream'];
    return (
      hist: h.cast<String, Object?>(),
      stream: s is List<int> ? Uint8List.fromList(s) : null,
    );
  } on FormatException {
    return null;
  }
}

/// the devices whose copy is still under way, for the start
Future<List<String>> historyCopiesOwed(DatabaseExecutor db) async => [
  for (final r in await db.query(
    'own_devices',
    columns: ['uid'],
    where: 'removed_at IS NULL AND stream IS NOT NULL AND hist IS NOT NULL',
  ))
    r['uid'] as String,
];

/// every device with a copy kept, under way or over, for the start: a
/// device removed since too, whose door answers that its copy ended
Future<List<({String uid, bool removed})>> historyCopiesKept(
  DatabaseExecutor db,
) async => [
  for (final r in await db.query(
    'own_devices',
    columns: ['uid', 'removed_at'],
    where: 'hist IS NOT NULL',
  ))
    (uid: r['uid'] as String, removed: r['removed_at'] != null),
];

/// the copy's place kept; [forget] lets the stream key go, the copy over.
/// a device removed meanwhile keeps what its removal wrote, unless
/// [removed] says this is that write
Future<void> keepHistoryCopy(
  DatabaseExecutor db,
  String uid,
  Map<String, Object?> hist, {
  bool forget = false,
  bool removed = false,
}) => db.update(
  'own_devices',
  {'hist': jsonEncode(hist), if (forget) 'stream': null},
  where: removed ? 'uid = ?' : 'uid = ? AND removed_at IS NULL',
  whereArgs: [uid],
);

/// the history place of device [uid], removed or not, for its end
Future<({Map<String, Object?> hist, Uint8List? stream})?> historyCopyAnyOf(
  DatabaseExecutor db,
  String uid,
) async {
  final r = await db.query(
    'own_devices',
    columns: ['stream', 'hist'],
    where: 'uid = ?',
    whereArgs: [uid],
  );
  if (r.isEmpty || r.first['hist'] is! String) return null;
  try {
    final h = jsonDecode(r.first['hist'] as String) as Map;
    final s = r.first['stream'];
    return (
      hist: h.cast<String, Object?>(),
      stream: s is List<int> ? Uint8List.fromList(s) : null,
    );
  } on FormatException {
    return null;
  }
}

/// devices [uids] went, for [why] at [at]: off the list here, their keys
/// with them. [notice] 2 says so on the home card until the devices page
/// is opened
Future<void> markOwnDevicesGone(
  DatabaseExecutor db,
  Iterable<String> uids, {
  required String why,
  required int at,
  required bool notice,
}) async {
  for (final uid in uids) {
    await db.update(
      'own_devices',
      {
        'removed_at': at,
        'gone_why': why,
        'stream': null,
        'notice': notice ? 2 : 0,
      },
      where: 'uid = ? AND removed_at IS NULL',
      whereArgs: [uid],
    );
    await db.delete('own_device_keys', where: 'uid = ?', whereArgs: [uid]);
  }
}

/// the devices of mine whose key on [ident] is one of [keys] ([dev] and its
/// key, as a list names them), not removed yet
Future<List<String>> ownDevicesWithKeys(
  DatabaseExecutor db,
  int ident,
  Iterable<({int id, String key})> keys,
) async {
  final out = <String>[];
  for (final k in keys) {
    for (final r in await db.rawQuery(
      'SELECT k.uid FROM own_device_keys k JOIN own_devices o ON '
      'o.uid = k.uid WHERE o.removed_at IS NULL AND k.ident = ? AND '
      'k.dev_id = ? AND k.key = ?',
      [ident, k.id, k.key],
    )) {
      out.add(r['uid'] as String);
    }
  }
  return out;
}

/// devices [uids] said they unlinked themselves while no removal could go:
/// the next tick on the everyday side removes them as that
Future<void> markOwnDevicesLeft(DatabaseExecutor db, List<String> uids) async {
  for (final uid in uids) {
    await db.update(
      'own_devices',
      {'gone_why': 'itself'},
      where: 'uid = ? AND removed_at IS NULL',
      whereArgs: [uid],
    );
  }
}

/// devices [uids] are being removed for [why]: owed until every step of
/// it went (own_unlink.dart), so a kill midway is finished at the next
/// start. one that said it unlinked itself keeps that
Future<void> markOwnDevicesOwed(
  DatabaseExecutor db,
  Iterable<String> uids, {
  required String why,
}) async {
  for (final uid in uids) {
    await db.rawUpdate(
      'UPDATE own_devices SET gone_why = COALESCE(gone_why, ?) '
      'WHERE uid = ? AND removed_at IS NULL',
      [why, uid],
    );
  }
}

/// why each of [uids] is owed a removal, for those that are
Future<Map<String, String>> ownDevicesOwed(
  DatabaseExecutor db,
  List<String> uids,
) async => {
  for (final r in await db.query(
    'own_devices',
    columns: ['uid', 'gone_why'],
    where:
        'removed_at IS NULL AND gone_why IS NOT NULL AND '
        'uid IN (${List.filled(uids.length, '?').join(',')})',
    whereArgs: uids,
  ))
    r['uid'] as String: r['gone_why'] as String,
};

/// a linked device: when it last heard its phone on their own session,
/// and its time in touch with a relay since (own_unlink.dart's clock)
const kPhoneHeardMeta = 'own_phone_heard';
const kPhoneQuietMeta = 'own_phone_quiet';

/// a linked device copies what it sends to my other devices only while
/// its phone was heard this recently: one whose list may have moved since
/// (a device removed meanwhile) sends to the phone alone until it hears
/// it again. the relays keep a wrap this long, and the phone sends its
/// list again every few days until it is answered
const kOwnPhoneFresh = Duration(days: 14);

/// a linked device heard its phone at [at]
Future<void> ownPhoneHeard(DatabaseExecutor db, int at) async {
  await putDevMeta(db, kPhoneHeardMeta, '$at');
  await putDevMeta(db, kPhoneQuietMeta, '0');
}

/// whether a linked device heard its phone within [kOwnPhoneFresh] of [now]
Future<bool> ownPhoneFresh(DatabaseExecutor db, int now) async {
  final at = int.tryParse(await devMeta(db, kPhoneHeardMeta) ?? '');
  return at != null && at <= now && now - at <= kOwnPhoneFresh.inMilliseconds;
}

/// a linked device was in touch with a relay [ms] more without a word from
/// its phone: the time so far
Future<int> addOwnPhoneQuiet(DatabaseExecutor db, int ms) async {
  final was = int.tryParse(await devMeta(db, kPhoneQuietMeta) ?? '') ?? 0;
  final now = was + ms;
  if (ms > 0) await putDevMeta(db, kPhoneQuietMeta, '$now');
  return now;
}

/// a value of the device state's own in signal_meta
Future<String?> devMeta(DatabaseExecutor db, String k) async {
  final r = await db.query(
    'signal_meta',
    columns: ['v'],
    where: 'k = ?',
    whereArgs: [k],
    limit: 1,
  );
  return r.isEmpty ? null : r.first['v'] as String?;
}

Future<void> putDevMeta(DatabaseExecutor db, String k, String v) => db.insert(
  'signal_meta',
  {'k': k, 'v': v},
  conflictAlgorithm: ConflictAlgorithm.replace,
);

Future<void> dropDevMeta(DatabaseExecutor db, String k) =>
    db.delete('signal_meta', where: 'k = ?', whereArgs: [k]);

/// the phone was online [ms] more: each device's time since its last word
/// grows by that
Future<void> addOwnOnlineTime(DatabaseExecutor db, int ms) => db.rawUpdate(
  'UPDATE own_devices SET heard_online_ms = heard_online_ms + ? '
  "WHERE removed_at IS NULL AND kind != 'phone'",
  [ms],
);

/// a device of mine said a person uses it: its time since starts again
Future<void> ownDeviceHeard(
  DatabaseExecutor db, {
  required int ident,
  required int dev,
  required String key,
  required int at,
}) => db.rawUpdate(
  'UPDATE own_devices SET heard_online_ms = 0, heard_at = ? WHERE uid IN '
  '(SELECT uid FROM own_device_keys WHERE ident = ? AND dev_id = ? '
  'AND key = ?) AND removed_at IS NULL',
  [at, ident, dev, key],
);

/// how long a device removed is kept on the page's rows once seen, so its
/// history copy can still answer that it ended
const kGoneRowKept = Duration(days: 31);

/// devices gone long ago, their notice seen, go for good
Future<void> pruneGoneDevices(DatabaseExecutor db, int now) => db.delete(
  'own_devices',
  where: 'removed_at IS NOT NULL AND removed_at < ? AND notice = 0',
  whereArgs: [now - kGoneRowKept.inMilliseconds],
);

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
  Uint8List? bind,
  String? onion,
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
  // the phone was just heard: the link came from it
  await ownPhoneHeard(tx, DateTime.now().millisecondsSinceEpoch);
  // where the history copy comes from, and the link it is bound to
  if (bind != null && onion != null) {
    await tx.insert('signal_meta', {
      'k': kLinkPlaceMeta,
      'v': jsonEncode({
        'onion': onion,
        'bind': _hex(bind),
        'identity': _hex(identity),
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
});

/// where a linked device keeps its phone's onion, the link's transcript and
/// the identity it serves, for the history copy
const kLinkPlaceMeta = 'link_place';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<String?> _meta(DatabaseExecutor db, String k) async {
  final r = await db.query(
    'signal_meta',
    columns: ['v'],
    where: 'k = ?',
    whereArgs: [k],
  );
  return r.isEmpty ? null : r.first['v'] as String?;
}

/// the linked device's place for its copy; null on a phone
Future<({String onion, String bind, String identity})?> linkPlaceOf(
  DatabaseExecutor db,
) async {
  final v = await _meta(db, kLinkPlaceMeta);
  if (v == null) return null;
  try {
    final j = jsonDecode(v) as Map;
    return (
      onion: j['onion'] as String,
      bind: j['bind'] as String,
      identity: j['identity'] as String,
    );
  } catch (_) {
    return null;
  }
}

/// the link's stream key, while the copy is under way
Future<Uint8List?> linkStreamOf(DatabaseExecutor db) async {
  final v = await _meta(db, kLinkStreamMeta);
  if (v == null) return null;
  try {
    return base64Decode(v);
  } on FormatException {
    return null;
  }
}

/// the copy is over: the link's stream key goes
Future<void> forgetLinkStream(DatabaseExecutor db) =>
    db.delete('signal_meta', where: 'k = ?', whereArgs: [kLinkStreamMeta]);

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

/// the mark device_receive.dart keeps for a device another copy of my
/// phone linked (a contact handed back a list naming it)
const kUnknownDeviceMark = 'alarm:unknown_device';
const _kUnknownDeviceSeen = 'seen:unknown_device';

/// the notices not opened yet, read into [linkNotices]: a device another
/// copy of my phone linked first, then the devices that went, then the
/// ones linked, oldest first in each
Future<List<LinkNotice>> readLinkNotices(DatabaseExecutor db) async {
  final out = [
    for (final r in await db.query(
      'dev_marks',
      columns: ['key', 'at'],
      where: 'kind = ?',
      whereArgs: [kUnknownDeviceMark],
      orderBy: 'at',
    ))
      LinkNotice(
        uid: 'unknown:${r['key']}',
        name: '',
        at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
        why: 'unknown',
      ),
    for (final r in await db.query(
      'own_devices',
      columns: ['uid', 'name', 'removed_at', 'gone_why'],
      where: 'notice = 2 AND removed_at IS NOT NULL',
      orderBy: 'removed_at',
    ))
      LinkNotice(
        uid: r['uid'] as String,
        name: r['name'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(r['removed_at'] as int),
        why: r['gone_why'] as String? ?? 'removed',
      ),
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
  await db.update('own_devices', {'notice': 0}, where: 'notice != 0');
  await db.update(
    'dev_marks',
    {'kind': _kUnknownDeviceSeen},
    where: 'kind = ?',
    whereArgs: [kUnknownDeviceMark],
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
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
    this.leave,
  });

  final DatabaseExecutor db;
  final String thisName;
  final DeviceKind thisKind;

  /// set on a linked device: its phone's name in the list
  final String? phoneName;

  /// a link from a scanned code; null where this device cannot link
  final LinkFlow Function(String code, LinkHistory history)? link;

  /// taking devices off the list (own_unlink.dart); null where this
  /// device removes none
  final Future<void> Function(List<String> uids)? unlink;

  /// a linked device unlinks itself: it tells its phone, then wipes
  final Future<void> Function()? leave;

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
          lastUsed: switch (r['heard_at']) {
            final int t when t > 0 => DateTime.fromMillisecondsSinceEpoch(t),
            _ => null,
          },
          // on the phone, counted in its own time online as the removal
          // counts it; a linked device does not count
          unlinksInDays: phoneName == null
              ? unlinksInDaysOf((r['heard_online_ms'] as num?)?.toInt() ?? 0)
              : null,
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
  Future<void> remove(String id) async => unlink?.call([id]);

  @override
  Future<void> removeOthers() async {
    final u = unlink;
    if (u == null) return;
    // one list without all of them
    await u([
      for (final d in await load())
        if (!d.thisDevice && !d.isPhone) d.id,
    ]);
  }

  @override
  bool get canLeave => leave != null && phoneName != null;

  @override
  Future<void> leaveHere() async => leave?.call();

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
