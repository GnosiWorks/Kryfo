// SPDX-License-Identifier: GPL-3.0-or-later
// the heal (KHB1, identity v4 3.8): the one frame that builds a session
// outside a first contact. one side sends its phone's bundle with a
// one-time kyber made for this heal, signed by its identity; the other
// builds from it and answers inside the new session. what a heal leaves in
// a chat (its line, and a hold on a verified contact) and the nonces seen
// are kept here too
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'invites.dart' show bundleBlock, unixHours;
import 'signal_ffi/kryfo_signal.dart';
import 'signal_session.dart';
import 'devices/own_unlink.dart' show kRestoreListOwedMeta;

/// the wire's word for a heal, beside the json heal's 'bundle'
const kHealCtl = 'heal';

/// how old a heal may be (a wrap's life), and how far ahead of this clock
const kHealOldest = Duration(days: 15);
const kHealAhead = Duration(hours: 24);

/// how long a nonce is kept, from when it came: a heal is taken while it
/// is at most 15 days old and may be issued a day ahead, so 16 days and a
/// day more, with no hour at the edge where one is fresh and forgotten
const kHealNonceKeep = Duration(days: 17);

/// at most one rebuild per contact this often
const kHealRebuildGap = Duration(minutes: 10);

/// Q22 (a): a verified contact whose session a heal rebuilt is held until
/// the person looks. false keeps the line without the hold
const kHealHold = true;

/// Q20 (a): before a restore, the contacts in the file on an older Kryfo
/// are named and the person is asked to go on. false restores without it
const kRestoreWarnsOlder = true;

/// what a heal line says: they set Kryfo up again (a restore or a move),
/// or their phone started a new session (a repair)
const kHealLineRestored = 1;
const kHealLineRepair = 2;

/// set as a restore lands, with when its file was made (0 when unknown),
/// and cleared once the next start ran what follows a restore (8)
const kRestoreAfterPref = 'restore.after';

/// when this phone's last restore landed. what the relays still hold from
/// before it is refused: the nonces and the hellos seen went back to the
/// file's, and the restore sends its own heals
const kRestoreCutPref = 'restore.cut';

/// a restore cuts every linked device off before the first seal (linked
/// step 7, D4 and B2): every device session (device 2 and up, mine and
/// contacts', all as old as the file), the device pairs' seeds, my devices'
/// rows and keys, their pool, copies, pushes, asks and marks go. a device in
/// the backup may have been removed since, so each is linked again. what
/// is kept: my own lists (the next start signs each above, naming the phone
/// alone: kRestoreListOwedMeta), the contacts' lists, proofs and pq marks,
/// which only ever make this phone stricter. the registration id stays
Future<void> restoreCutsLinkedDevices(DatabaseExecutor db) async {
  final have = {
    for (final r in await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ))
      r['name'] as String,
  };
  if (have.contains('sessions')) {
    await db.delete('sessions', where: 'device_id >= 2');
  }
  if (have.contains('pairs')) {
    await db.delete('pairs', where: 'their_device != 1 OR my_device != 1');
  }
  for (final t in const [
    'own_devices',
    'own_device_keys',
    'dev_quiet',
    'dev_pool',
    'dev_held_openers',
    'dev_pushes',
    'dev_out',
    'dev_openers',
    'dev_asks',
    'dev_marks',
    'dev_farewell',
    'own_told',
    'own_held',
  ]) {
    if (have.contains(t)) await db.delete(t);
  }
  if (!have.contains('dev_lists') || !have.contains('signal_meta')) return;
  final mine = await db.query(
    'dev_lists',
    columns: ['ident'],
    where: "owner = 'me'",
    limit: 1,
  );
  if (mine.isEmpty) return;
  await db.insert('signal_meta', {
    'k': kRestoreListOwedMeta,
    'v': '1',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// a heal to [peer] (their identity as [ss] holds it) from [ss]'s phone:
/// the session spk and a fresh one-time kyber, [since] in unix hours (a
/// whole UTC day) when it follows a restore
Future<Uint8List> makeHeal(
  SignalSession ss, {
  required List<int> peer,
  int? since,
  int? nowMs,
  Random? random,
}) async {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final restored = since != null;
  if (restored && (since < 0 || since % 24 != 0)) {
    throw ArgumentError.value(since, 'since', 'a whole day in unix hours');
  }
  final ids = await ss.sessionPreKeysForUse(now: now);
  final kyberId = await ss.makeHealKyber(now: now);
  final lib = ss.lib;
  final spk = lib.preKeyPublic(
    kLsSigned,
    (await ss.signedPreKeyStore.load(ids.signedId))!,
  );
  final kyber = lib.preKeyPublic(
    kLsKyber,
    (await ss.kyberPreKeyStore.load(kyberId))!,
  );
  final r = random ?? Random.secure();
  final body = BytesBuilder(copy: false)
    ..add(ascii.encode('KHB1'))
    ..addByte(1)
    ..addByte(restored ? 1 : 0)
    ..add(_u32(unixHours(now)))
    ..add([for (var i = 0; i < 16; i++) r.nextInt(256)])
    ..add(ss.identity.public)
    ..add(peer)
    ..add(_u32(since ?? 0))
    ..add(
      bundleBlock(registrationId: ss.registrationId, spk: spk, kyber: kyber),
    );
  final b = body.toBytes();
  final sig = lib.sign(ss.identity, LsSigContext.heal, b);
  return Uint8List.fromList([...b, ...sig]);
}

Uint8List _u32(int v) => Uint8List.fromList([
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
]);

/// a heal as the relay carries it: outside the session, beside the json
/// heal, which a 0.5.x reader is the only one to take
String healWire(List<int> khb1) =>
    jsonEncode({'halo_ctl': kHealCtl, 'b': base64Encode(khb1)});

/// the KHB1 a wire frame carries, null when it is none
Uint8List? healOfWire(String frame) {
  try {
    final j = jsonDecode(frame);
    if (j is! Map || j['halo_ctl'] != kHealCtl) return null;
    final b = j['b'];
    // a heal from a linked device is 1,937 bytes: room for a few more
    if (b is! String || b.length > 4096) return null;
    return base64Decode(b);
  } catch (_) {
    return null;
  }
}

/// why a heal is not taken
enum HealRefused {
  // its identity is not the one held for them
  notTheirs,
  // it names another identity of mine than theirs
  notMine,
  // signed by a linked device: its list is step 7's
  device,
  // older than a wrap lives, or too far ahead
  stale,
  // a nonce seen already
  replay,
  // issued before this phone's restore, or before the last heal taken from
  // them
  older,
}

/// 3.8's checks 2 to 4 on a parsed heal (1, 3's signature and 6 are the
/// relay's seal and the shim's parser). null when it is taken
HealRefused? checkHeal(
  LsHeal h, {
  required List<int> held,
  required List<int> mine,
  required int nowMs,
  int? restoredAt,
  int? lastIssued,
}) {
  if (!_eq(h.identity, held)) return HealRefused.notTheirs;
  if (!_eq(h.peer, mine)) return HealRefused.notMine;
  // the phone of every identity signs with the identity itself; a device
  // key on their list is taken once lists are (linked step 7)
  if (h.block.deviceId != 1 || !_eq(h.signer, h.identity)) {
    return HealRefused.device;
  }
  final now = unixHours(nowMs);
  if (h.issued < now - kHealOldest.inHours ||
      h.issued > now + kHealAhead.inHours) {
    return HealRefused.stale;
  }
  // in hours, as issued: one in the hour of the restore is taken
  if (restoredAt != null && h.issued < unixHours(restoredAt)) {
    return HealRefused.older;
  }
  if (lastIssued != null && h.issued < lastIssued) return HealRefused.older;
  return null;
}

/// the heal's since in ms, null when it follows no restore
int? healSinceMs(LsHeal h) => h.restored ? h.since * 3600000 : null;

/// [ms] as a heal's since: the UTC day it falls on, in unix hours
int healDayOf(int ms) => (ms ~/ 86400000) * 24;

/// the tables a heal keeps, made at every open: a file that took a later
/// version without them gets them too
Future<void> healTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS heal_lines (
      peer TEXT NOT NULL,
      at INTEGER NOT NULL,
      kind INTEGER NOT NULL,
      held INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS heal_lines_peer ON heal_lines (peer)',
  );
  // peer: whose heal it was, so the nonce moves with their chat
  await db.execute('''
    CREATE TABLE IF NOT EXISTS heal_nonces (
      ident INTEGER NOT NULL,
      nonce TEXT NOT NULL,
      at INTEGER NOT NULL,
      peer TEXT,
      PRIMARY KEY (ident, nonce)
    )
  ''');
}

// what a file made before them lacks: the nonce's peer, and the last heal
// taken on the contact's row (issued, in unix hours)
Future<void> _healColumns(DatabaseExecutor db) async {
  for (final (table, col, sql) in const [
    ('heal_nonces', 'peer', 'ALTER TABLE heal_nonces ADD COLUMN peer TEXT'),
    (
      'contacts',
      'heal_last',
      'ALTER TABLE contacts ADD COLUMN heal_last INTEGER',
    ),
  ]) {
    final cols = await db.rawQuery("PRAGMA table_info('$table')");
    if (cols.isEmpty || cols.any((c) => c['name'] == col)) continue;
    try {
      await db.execute(sql);
    } catch (e) {
      if (!'$e'.contains('duplicate column name')) rethrow;
    }
  }
}

/// the same, at every open, with the columns a file made before them
/// lacks: only what is missing is made, so a second open writes nothing
Future<void> healTablesAtOpen(DatabaseExecutor db) async {
  final have = {
    for (final r in await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name IN "
      "('heal_lines', 'heal_lines_peer', 'heal_nonces')",
    ))
      r['name'] as String,
  };
  if (have.length < 3) await healTables(db);
  await _healColumns(db);
}

/// when this phone's last restore landed, null when it never had one
Future<int?> restoredAt() async =>
    (await SharedPreferences.getInstance()).getInt(kRestoreCutPref);

/// the issued hour of the last heal taken from [peer], null with none
Future<int?> lastHealOf(DatabaseExecutor db, String peer) async {
  final r = await db.query(
    'contacts',
    columns: ['heal_last'],
    where: 'halo_id = ?',
    whereArgs: [peer],
    limit: 1,
  );
  return r.isEmpty ? null : (r.first['heal_last'] as num?)?.toInt();
}

/// [issued] kept on [peer]'s row, where a move takes it too. it only
/// moves on
Future<void> keepLastHeal(DatabaseExecutor db, String peer, int issued) async {
  final was = await lastHealOf(db, peer);
  if (was != null && was >= issued) return;
  await db.update(
    'contacts',
    {'heal_last': issued},
    where: 'halo_id = ?',
    whereArgs: [peer],
  );
}

/// [nonce] noted for [ident]: false when it was seen in the last 17 days.
/// older ones go first
Future<bool> noteHealNonce(
  DatabaseExecutor db,
  int ident,
  List<int> nonce, {
  required int nowMs,
  String? peer,
}) async {
  await db.delete(
    'heal_nonces',
    // gone once it is the whole keep old
    where: 'at < ?',
    whereArgs: [nowMs - kHealNonceKeep.inMilliseconds + 1],
  );
  final n = base64Encode(nonce);
  final seen = await db.query(
    'heal_nonces',
    columns: ['at'],
    where: 'ident = ? AND nonce = ?',
    whereArgs: [ident, n],
    limit: 1,
  );
  if (seen.isNotEmpty) return false;
  await db.insert('heal_nonces', {
    'ident': ident,
    'nonce': n,
    'at': nowMs,
    'peer': ?peer,
  });
  return true;
}

/// one line in [peer]'s chat at [at], holding them when [held]
Future<void> addHealLine(
  DatabaseExecutor db,
  String peer, {
  required int at,
  required int kind,
  bool held = false,
}) => db.insert('heal_lines', {
  'peer': peer,
  'at': at,
  'kind': kind,
  'held': held ? 1 : 0,
});

/// [peer]'s lines, oldest first
Future<List<({int at, int kind})>> healLinesOf(
  DatabaseExecutor db,
  String peer,
) async {
  try {
    return [
      for (final r in await db.query(
        'heal_lines',
        columns: ['at', 'kind'],
        where: 'peer = ?',
        whereArgs: [peer],
        orderBy: 'at',
      ))
        (at: r['at'] as int, kind: r['kind'] as int),
    ];
  } catch (_) {
    // a database made before the table, as a test's rows are: none
    return const [];
  }
}

/// the line that holds [peer], null when none does
Future<int?> healHoldOf(DatabaseExecutor db, String peer) async {
  try {
    final r = await db.query(
      'heal_lines',
      columns: ['kind'],
      where: 'peer = ? AND held = 1',
      whereArgs: [peer],
      orderBy: 'at DESC',
      limit: 1,
    );
    return r.isEmpty ? null : r.first['kind'] as int;
  } catch (_) {
    return null;
  }
}

/// everyone a heal holds
Future<Set<String>> healHeldPeers(DatabaseExecutor db) async {
  try {
    return {
      for (final r in await db.query(
        'heal_lines',
        columns: ['peer'],
        where: 'held = 1',
        distinct: true,
      ))
        r['peer'] as String,
    };
  } catch (_) {
    return const {};
  }
}

/// the person looked: [peer] goes on
Future<void> dropHealHold(DatabaseExecutor db, String peer) async {
  try {
    await db.update(
      'heal_lines',
      {'held': 0},
      where: 'peer = ? AND held = 1',
      whereArgs: [peer],
    );
  } catch (_) {
    // no table, no hold
  }
}

/// the UTC day, in unix hours, of the last message from [peer] in [db],
/// [fallbackMs]'s day when there is none: a heal's since (8, R6)
Future<int> healSinceFor(
  DatabaseExecutor db,
  String peer, {
  required int fallbackMs,
}) async {
  final r = await db.query(
    'messages',
    columns: ['sent_at'],
    where: 'peer_id = ? AND direction = ? AND group_id IS NULL',
    whereArgs: [peer, 'in'],
    orderBy: 'sent_at DESC',
    limit: 1,
  );
  final t = r.isEmpty ? null : r.first['sent_at'] as int?;
  return healDayOf(t == null || t <= 0 ? fallbackMs : t);
}

/// a contact with no capability list from them ever: a 0.5.x phone, which
/// sends none, where every 0.6 frame carries one
bool olderKryfo(String? caps) => caps == null || caps.trim().isEmpty;

/// the accepted contacts of [db] on an older Kryfo, with their names: what
/// a restore pauses (Q20). [isDev] leaves the dev chat out. a database with
/// a caps column only
Future<List<({String id, String name})>> olderContacts(
  DatabaseExecutor db, {
  required bool Function(String id) isDev,
}) async {
  final rows = await db.query(
    'contacts',
    columns: ['halo_id', 'nickname', 'caps'],
    where: 'accepted = 1 AND blocked = 0',
  );
  return [
    for (final r in rows)
      if (!isDev(r['halo_id'] as String) && olderKryfo(r['caps'] as String?))
        (
          id: r['halo_id'] as String,
          name: switch (r['nickname']) {
            final String n when n.trim().isNotEmpty => n.trim(),
            _ => r['halo_id'] as String,
          },
        ),
  ];
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
