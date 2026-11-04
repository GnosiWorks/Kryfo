// SPDX-License-Identifier: GPL-3.0-or-later
// removing my own devices (linked devices step 7, job 9), on the phone: my
// list signed without them goes to every contact that reads lists at once,
// to my other devices, and as a last word to each device removed, which
// wipes on it. their sessions, keys, pool, copies, seeds, history copy and
// listens go here before anything else is sent. a device that sent no word
// of use for 30 days of this phone's own time online is removed the same
// way, and so is one that says it unlinked itself. nothing runs with the
// switch off, and none of it from the decoy (the app checks before)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../device_sessions.dart' show kOwnDevices;
import '../message_envelope.dart' show kEnvelopePrefix;
import 'device_receive.dart';
import 'device_send.dart';
import 'device_state.dart';
import 'own_device_store.dart';
import 'own_devices.dart' show kUnusedDays;

/// why a device of mine went, as own_devices.gone_why keeps it
const kGoneRemoved = 'removed';
const kGoneUnused = 'unused';
const kGoneItself = 'itself';
const kGoneUnknown = 'unknown';

/// a device's word of use missing this long in the phone's own time online
const kUnusedOnline = Duration(days: kUnusedDays);

/// how much one tick of the online clock may count at most: a phone asleep
/// or the app stopped between two ticks counts none of that gap
const kOnlineTickMost = Duration(minutes: 15);

/// a device of mine as its rows name it on one identity
typedef OwnKeyRow = ({String uid, int ident, int dev, String key, int reg});

class OwnUnlink {
  OwnUnlink({
    required this.state,
    required this.db,
    required this.send,
    required this.recv,
    required this.me,
    required this.sign,
    this.historyEnd,
    this.removed,
    bool Function()? allowed,
    int Function()? clock,
  }) : allowed = allowed ?? (() => true),
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// whether a removal may go now: the everyday side of the phone alone,
  /// never while the decoy or a quiet session is open. what was due waits
  /// for the next tick there
  final bool Function() allowed;

  final DeviceState state;

  /// the everyday container: my list, my devices' rows
  final Future<Database> Function() db;
  final DeviceSend send;
  final DeviceReceive recv;

  /// this device on my identity [ident]: only the phone removes
  final Future<DevMe?> Function(int ident) me;

  /// [body] signed by my identity [ident] (ks_sign, the device list context)
  final Future<Uint8List> Function(int ident, Uint8List body) sign;

  /// ends device [uid]'s history copy at once: the door says it ended, the
  /// stream key goes
  final Future<void> Function(String uid)? historyEnd;

  /// told once devices went, for what follows (the knock book, the notices)
  final void Function(List<String> uids, String why)? removed;

  final int Function() _clock;
  Future<void> _turn = Future.value();

  /// the devices [uids] removed, for [why]: the uids that went
  Future<List<String>> remove(List<String> uids, {required String why}) {
    final run = _turn.then((_) => _remove(uids, why));
    _turn = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<List<String>> _remove(List<String> uids, String why) async {
    if (!linkedDevicesOn || uids.isEmpty || !allowed()) return const [];
    final d = await db();
    final rows = await _keysOf(d, uids);
    final went = <String>{for (final r in rows) r.uid};
    if (went.isEmpty) return const [];
    // the history copy ends first: a device wrongly linked gets no more of
    // it from the moment it goes
    for (final uid in went) {
      try {
        await historyEnd?.call(uid);
      } catch (_) {
        // the copy's own end words are its business; the removal goes on
      }
    }
    final byIdent = <int, List<OwnKeyRow>>{};
    for (final r in rows) {
      (byIdent[r.ident] ??= []).add(r);
    }
    final now = _clock();
    for (final e in byIdent.entries) {
      await _unlist(d, e.key, e.value);
    }
    await d.transaction((t) async {
      // a removal made here is known here; the others are told
      await markOwnDevicesGone(
        t,
        went,
        why: why,
        at: now,
        notice: why != kGoneRemoved,
      );
      for (final r in rows) {
        await t.delete(
          'dev_asks',
          where: 'ident = ? AND device = ?',
          whereArgs: [r.ident, r.dev],
        );
      }
    });
    await readLinkNotices(d);
    removed?.call([...went], why);
    return [...went];
  }

  // the rows of [uids] still on my devices, a key per identity
  Future<List<OwnKeyRow>> _keysOf(Database d, List<String> uids) async => [
    for (final r in await d.rawQuery(
      'SELECT k.uid, k.ident, k.dev_id, k.key, k.reg FROM own_device_keys k '
      'JOIN own_devices o ON o.uid = k.uid WHERE o.removed_at IS NULL AND '
      'k.uid IN (${List.filled(uids.length, '?').join(',')}) AND k.dev_id > 1',
      uids,
    ))
      (
        uid: r['uid'] as String,
        ident: r['ident'] as int,
        dev: r['dev_id'] as int,
        key: r['key'] as String,
        reg: (r['reg'] as num?)?.toInt() ?? 0,
      ),
  ];

  // my list of [ident] without [gone], signed and taken: the devices it no
  // longer names lose their sessions and all else here, each gets the list
  // as its last word, my other devices get it, and the contacts at once
  Future<void> _unlist(Database d, int ident, List<OwnKeyRow> gone) async {
    final m = await me(ident);
    if (m == null || m.device != 1) return;
    final Map<String, dynamic> cur;
    try {
      cur = await state.call(d, 'current', {'ident': ident});
    } on DevRefused {
      return;
    }
    final listed = {
      for (final e in (cur['devices'] as List? ?? const []))
        if (e is Map && e['id'] is int) e['id'] as int: e['key'],
    };
    // a row whose key the list does not name (a link that failed before
    // the list was kept) has nothing to sign away
    final out = [
      for (final g in gone)
        if (listed[g.dev] == g.key) g,
    ];
    if (out.isEmpty) return;
    final j = await state.call(d, 'own_remove', {
      'ident': ident,
      'held': [
        for (final g in out) {'id': g.dev},
      ],
    });
    final body = base64Decode(j['list'] as String);
    final sig = await sign(ident, body);
    final wire = Uint8List.fromList([...body, ...sig]);
    final list = base64Encode(wire);
    final frame =
        '$kEnvelopePrefix${jsonEncode({'u': 'dl:${listVersionOf(wire)}', 'dl': list})}';
    // the last word, sealed while each session is still here
    for (final g in out) {
      await send.farewell(
        me: m,
        device: g.dev,
        pin: g.key,
        reg: g.reg,
        frame: frame,
      );
    }
    final set = await state.ownMine(d, ident, wire);
    final mine = devHex(m.identity);
    await recv.ownGone(m, mine, [
      for (final e in (set['gone'] as List? ?? const []))
        if (e is Map && e['id'] is int)
          (
            id: e['id'] as int,
            key: e['key'] as String,
            reg: (e['reg'] as num?)?.toInt() ?? 0,
          ),
    ]);
    // my other devices drop them too, and show it
    final left = await state.call(d, 'current', {'ident': ident});
    for (final e in (left['devices'] as List? ?? const [])) {
      if (e is! Map || e['id'] is! int || e['id'] == 1) continue;
      await send.toOne(
        ident: ident,
        identity: mine,
        device: e['id'] as int,
        addr: kOwnDevices,
        pin: e['key'] as String,
        reg: (e['reg'] as num?)?.toInt() ?? 0,
        frame: frame,
        own: true,
      );
    }
    await send.listsChanged([
      (
        ident: ident,
        version: listVersionOf(wire),
        added: const [],
        removed: true,
      ),
    ]);
    unawaited(send.pump());
  }

  // ---- the phone's own time online ----

  int? _lastTick;

  /// the phone was online from the last tick to now ([online] false: it was
  /// not, and nothing counts): each device's time since its last word grows
  /// by that, never by more than [kOnlineTickMost]. the uids past
  /// [kUnusedOnline] come back, for [removeUnused]
  Future<List<String>> tick({required bool online}) async {
    final now = _clock();
    final last = _lastTick;
    _lastTick = online ? now : null;
    if (!linkedDevicesOn || last == null || !online || now <= last) {
      return const [];
    }
    final step = (now - last).clamp(0, kOnlineTickMost.inMilliseconds);
    final d = await db();
    await addOwnOnlineTime(d, step);
    return unusedNow(d);
  }

  /// the devices past [kUnusedOnline] of the phone's own time online, and
  /// those that said they unlinked while no removal could go
  Future<List<String>> unusedNow(DatabaseExecutor d) async => [
    for (final r in await d.query(
      'own_devices',
      columns: ['uid'],
      where:
          "removed_at IS NULL AND kind != 'phone' AND "
          '(heard_online_ms >= ? OR gone_why IS NOT NULL)',
      whereArgs: [kUnusedOnline.inMilliseconds],
    ))
      r['uid'] as String,
  ];

  /// the unused devices removed, with the notice on every own device; one
  /// that said it unlinked itself meanwhile goes as that
  Future<List<String>> removeUnused() async {
    final d = await db();
    final due = await unusedNow(d);
    if (due.isEmpty) return const [];
    final itself = await ownDevicesLeft(d, due);
    return [
      ...await remove(itself, why: kGoneItself),
      ...await remove([
        for (final u in due)
          if (!itself.contains(u)) u,
      ], why: kGoneUnused),
    ];
  }

  /// my own [device] of [ident] said it unlinked itself (and wiped): it is
  /// removed as one the person removed, and the person is told
  Future<List<String>> left(int ident, int device, String key) async {
    final uids = await ownDevicesWithKeys(await db(), ident, [
      (id: device, key: key),
    ]);
    if (uids.isEmpty) return const [];
    // the decoy or a quiet session open: kept for the next tick there
    if (!allowed()) {
      await markOwnDevicesLeft(await db(), uids);
      return const [];
    }
    return remove(uids, why: kGoneItself);
  }
}

/// the version a KDL2 wire names, after its magic and identity
int listVersionOf(Uint8List w) {
  if (w.length < 4 + 33 + 8) return 0;
  return ByteData.sublistView(w, 37, 45).getUint64(0);
}

/// what a restore cut leaves for the next start (heal.dart): each own list
/// signed again, the phone alone on it
const kRestoreListOwedMeta = 'own_restore_owed';

/// the first lists a restored phone signs, once, before anything is sent:
/// the phone alone on each, above any version the backup's phone signed
/// since. the changes come back for the contacts' pushes
Future<List<({int ident, int version, List<int> added, bool removed})>>
restoredLists(
  Database db,
  DeviceState state,
  Future<Uint8List> Function(int ident, Uint8List body) sign,
) async {
  final owed = await db.query(
    'signal_meta',
    where: 'k = ?',
    whereArgs: [kRestoreListOwedMeta],
  );
  if (owed.isEmpty) return const [];
  final out = <({int ident, int version, List<int> added, bool removed})>[];
  for (final r in await db.query(
    'dev_lists',
    columns: ['ident'],
    where: "owner = 'me'",
  )) {
    final ident = r['ident'] as int;
    final Map<String, dynamic> j;
    try {
      j = await state.call(db, 'own_restored', {'ident': ident});
    } on DevRefused {
      // a linked device's: its phone signs
      continue;
    }
    if (j['outcome'] != 'restored') continue;
    final body = base64Decode(j['list'] as String);
    final wire = Uint8List.fromList([...body, ...await sign(ident, body)]);
    await state.ownMine(db, ident, wire);
    out.add((
      ident: ident,
      version: listVersionOf(wire),
      added: const [],
      removed: true,
    ));
  }
  await db.delete(
    'signal_meta',
    where: 'k = ?',
    whereArgs: [kRestoreListOwedMeta],
  );
  return out;
}
