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
    // owed before anything is signed: a kill from here on leaves the
    // removal for the next start (removeUnused) to finish
    await markOwnDevicesOwed(d, went, why: why);
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
    // a device stays owed until every list that names it moved
    final open = <String>{};
    for (final e in byIdent.entries) {
      if (!await _unlist(d, e.key, e.value)) {
        open.addAll(e.value.map((r) => r.uid));
      }
    }
    final done = went.difference(open);
    if (done.isEmpty) return const [];
    await d.transaction((t) async {
      // a removal made here is known here; the others are told
      await markOwnDevicesGone(
        t,
        done,
        why: why,
        at: now,
        notice: why != kGoneRemoved,
      );
      for (final r in rows) {
        if (!done.contains(r.uid)) continue;
        await t.delete(
          'dev_asks',
          where: 'ident = ? AND device = ?',
          whereArgs: [r.ident, r.dev],
        );
      }
    });
    await readLinkNotices(d);
    removed?.call([...done], why);
    return [...done];
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
  // as its last word, my other devices get it until they answer, and the
  // contacts at once. the signed list is kept before it is used, so a
  // removal cut short goes on from where it was. true when nothing of it
  // is owed any more
  Future<bool> _unlist(Database d, int ident, List<OwnKeyRow> gone) async {
    final m = await me(ident);
    if (m == null || m.device != 1) return false;
    Map<String, dynamic> cur;
    try {
      cur = await state.call(d, 'current', {'ident': ident});
    } on DevRefused catch (e) {
      // no list of mine at all: nothing names them
      return e.why == 'not_listed';
    }
    List<OwnKeyRow> listedOf(Map<String, dynamic> cur) {
      final listed = {
        for (final e in (cur['devices'] as List? ?? const []))
          if (e is Map && e['id'] is int) e['id'] as int: e['key'],
      };
      return [
        for (final g in gone)
          if (listed[g.dev] == g.key) g,
      ];
    }

    var out = listedOf(cur);
    final owedKey = '$kRemoveOwedMeta$ident';
    final owed = _owedOf(await devMeta(d, owedKey));
    // a row the list does not name and no removal owed for it (a link
    // that failed before the list was kept): nothing to sign away
    if (out.isEmpty && owed == null) {
      await _drop(m, gone);
      return true;
    }
    // a list signed before and not kept yet goes first, the same bytes:
    // never a second list at its version
    if (owed != null && listVersionOf(owed.wire) > _versionOf(cur)) {
      await _sealAndKeep(d, m, ident, [
        for (final g in out)
          if (owed.ids.contains(g.dev)) g,
      ], owed.wire);
      cur = await state.call(d, 'current', {'ident': ident});
      out = listedOf(cur);
    }
    if (out.isNotEmpty) {
      final j = await state.call(d, 'own_remove', {
        'ident': ident,
        'held': [
          for (final g in out) {'id': g.dev},
        ],
      });
      final body = base64Decode(j['list'] as String);
      final sig = await sign(ident, body);
      final wire = Uint8List.fromList([...body, ...sig]);
      // kept before it is used: a kill from here on goes on with it
      await putDevMeta(
        d,
        owedKey,
        jsonEncode({
          'w': base64Encode(wire),
          'ids': [for (final g in out) g.dev],
        }),
      );
      await _sealAndKeep(d, m, ident, out, wire);
      cur = await state.call(d, 'current', {'ident': ident});
    }
    await _drop(m, gone);
    // my other devices drop them too, and show it: kept until each answers
    final mine = devHex(m.identity);
    final list = base64Decode(cur['list'] as String);
    final frame = _listFrame(list);
    for (final e in (cur['devices'] as List? ?? const [])) {
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
        receipt: true,
        keep: true,
      );
    }
    await send.listsChanged([
      (
        ident: ident,
        version: listVersionOf(list),
        added: const [],
        removed: true,
      ),
    ]);
    await dropDevMeta(d, owedKey);
    unawaited(send.pump());
    return true;
  }

  // [wire], my list without [out], as the last word to each of them that
  // has none sealed yet, while its session is still here; then kept
  Future<void> _sealAndKeep(
    Database d,
    DevMe m,
    int ident,
    List<OwnKeyRow> out,
    Uint8List wire,
  ) async {
    final frame = _listFrame(wire);
    for (final g in out) {
      if (await send.farewellHeld(ident, g.dev, g.key)) continue;
      await send.farewell(
        me: m,
        device: g.dev,
        pin: g.key,
        reg: g.reg,
        frame: frame,
      );
    }
    await state.ownMine(d, ident, wire);
  }

  static int _versionOf(Map<String, dynamic> cur) =>
      listVersionOf(base64Decode(cur['list'] as String));

  // the devices [gone] lose their sessions, pool, copies, seeds, held
  // openers and listens here
  Future<void> _drop(DevMe m, List<OwnKeyRow> gone) => recv.ownGone(
    m,
    devHex(m.identity),
    [for (final g in gone) (id: g.dev, key: g.key, reg: g.reg)],
  );

  String _listFrame(Uint8List wire) =>
      '$kEnvelopePrefix${jsonEncode({'u': 'dl:${listVersionOf(wire)}', 'dl': base64Encode(wire)})}';

  ({Uint8List wire, Set<int> ids})? _owedOf(String? v) {
    if (v == null) return null;
    try {
      final j = jsonDecode(v) as Map;
      return (
        wire: base64Decode(j['w'] as String),
        ids: {for (final i in j['ids'] as List) i as int},
      );
    } catch (_) {
      return null;
    }
  }

  // ---- the phone's own time online ----

  int? _lastTick;
  int? _lastQuiet;

  /// when the phone's clock last ticked, for the app's [relayContactSince]
  int? get lastTick => _lastTick;

  /// the phone was online from the last tick to now ([online] false: it was
  /// not, and nothing counts): each device's time since its last word grows
  /// by that, never by more than [kOnlineTickMost]. the uids past
  /// [kUnusedOnline] come back, for [removeUnused]. online means in touch
  /// with a relay, never a network alone ([relayContactSince])
  Future<List<String>> tick({required bool online}) async {
    final now = _clock();
    final step = _step(_lastTick, now, online);
    _lastTick = online ? now : null;
    if (!linkedDevicesOn || step == 0) return const [];
    final d = await db();
    await addOwnOnlineTime(d, step);
    return unusedNow(d);
  }

  /// when this linked device's quiet clock last ticked
  int? get lastQuiet => _lastQuiet;

  /// a linked device was in touch with a relay from the last tick to now
  /// ([online]) and heard nothing from its phone: its time without a word
  /// grows by that, at most [kOnlineTickMost] a tick. true once it reached
  /// [kUnusedOnline]: its phone holds it no more (a restore, or its last
  /// word lost), or it is gone, and the device ends
  Future<bool> quietTick({required bool online}) async {
    final now = _clock();
    final step = _step(_lastQuiet, now, online);
    _lastQuiet = online ? now : null;
    if (!linkedDevicesOn) return false;
    final d = await db();
    final quiet = await addOwnPhoneQuiet(d, step);
    return quiet >= kUnusedOnline.inMilliseconds;
  }

  static int _step(int? last, int now, bool online) {
    if (last == null || !online || now <= last) return 0;
    return (now - last).clamp(0, kOnlineTickMost.inMilliseconds);
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
  /// that said it unlinked itself meanwhile goes as that, and a removal
  /// cut short (a kill, a list that did not move) is finished for its why.
  /// run at every start and tick
  Future<List<String>> removeUnused() async {
    final d = await db();
    final due = await unusedNow(d);
    if (due.isEmpty) return const [];
    final why = await ownDevicesOwed(d, due);
    final by = <String, List<String>>{};
    for (final u in due) {
      (by[why[u] ?? kGoneUnused] ??= []).add(u);
    }
    return [for (final e in by.entries) ...await remove(e.value, why: e.key)];
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

/// whether the relays were in touch since [since] (a tick's start): [upAt]
/// the last time one answered. a network alone counts nothing
bool relayContactSince(int? upAt, int? since) =>
    upAt != null && (since == null || upAt >= since);

/// whether a relay answers lately, as the engine's transport rows say
bool relaysAnswer(List<dynamic>? relays) =>
    relays != null && relays.any((r) => r is Map && r['up'] == true);

/// the version a KDL2 wire names, after its magic and identity
int listVersionOf(Uint8List w) {
  if (w.length < 4 + 33 + 8) return 0;
  return ByteData.sublistView(w, 37, 45).getUint64(0);
}

/// a removal signed and not finished yet, per identity: the list and the
/// ids it removes, until every step after the sign went
const kRemoveOwedMeta = 'own_remove_owed:';

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
