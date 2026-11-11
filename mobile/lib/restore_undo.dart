// SPDX-License-Identifier: GPL-3.0-or-later
// what a restore must not undo. a timed copy the relays still hold from
// before it counts from then, never from a fresh clock (burnCameAt), and
// our own unsends and last edits go again to a contact whose restore
// brought back what we took back or changed since their backup
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'dlog.dart';
import 'heal.dart' show kRestoreCutPref;

/// when the last restore landed, by this clock: a timed copy from before it
/// counts from then at the latest, for as long as relays may hold such a
/// copy. the heal cut's own pref (heal.dart), which _livesHereNow writes and
/// keeps for good: read here, never removed here
const kRestoreLandedPref = kRestoreCutPref;
const kRestoreLandedKeep = Duration(days: 16);

/// [kRestoreLandedPref] as this start read it, null with no restore lately
int? restoreLandedAt;

/// when the last restore landed, while it is recent: null once it is
/// older than [kRestoreLandedKeep]. the pref itself stays
int? restoreLandedOf(SharedPreferences prefs, {int? nowMs}) {
  final at = prefs.getInt(kRestoreLandedPref);
  if (at == null) return null;
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  return now - at > kRestoreLandedKeep.inMilliseconds ? null : at;
}

/// the landing the outbox hold counts from, however old: while the
/// restore's mark is set a late retry holds only what the file brought
int? restoreHoldLanding(SharedPreferences prefs) =>
    prefs.getInt(kRestoreLandedPref);

/// our unsends and last edits are kept this long: a heal's since reaches
/// back 15 days, and a day more. no words are kept: an edit goes again with
/// the words our row holds then, and only while it is there
const kTakenKeep = Duration(days: 16);
const kTakenUnsend = 'unsend';
const kTakenEdit = 'edit';

/// the table, at every open: a 1:1 one by its person, a group's by its
/// group
Future<void> takenTables(DatabaseExecutor db) => db.execute('''
  CREATE TABLE IF NOT EXISTS taken_out (
    msg_uid TEXT NOT NULL,
    kind TEXT NOT NULL,
    peer_id TEXT,
    group_id TEXT,
    at INTEGER NOT NULL,
    PRIMARY KEY (msg_uid, kind)
  )
''');

/// the same at every open: made only when missing, so a second open writes
/// nothing
Future<void> takenTablesAtOpen(DatabaseExecutor db) async {
  final have = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    ['taken_out'],
  );
  if (have.isEmpty) {
    await takenTables(db);
    return;
  }
  // written only when there is one to go
  final cut = DateTime.now().millisecondsSinceEpoch - kTakenKeep.inMilliseconds;
  final old = await db.query(
    'taken_out',
    columns: ['msg_uid'],
    where: 'at < ?',
    whereArgs: [cut],
    limit: 1,
  );
  if (old.isNotEmpty) {
    await pruneTaken(db, nowMs: cut + kTakenKeep.inMilliseconds);
  }
}

/// those past the keep go: at every open and in every copy that leaves the
/// phone
Future<int> pruneTaken(DatabaseExecutor db, {int? nowMs}) => db.delete(
  'taken_out',
  where: 'at < ?',
  whereArgs: [
    (nowMs ?? DateTime.now().millisecondsSinceEpoch) -
        kTakenKeep.inMilliseconds,
  ],
);

/// gone with what they were of: an edit with its message ([uid]), all of a
/// chat with it ([peer] or [group]). a chat cleared keeps its take-backs
/// ([editsOnly]): they hold no words, and a restore there would bring
/// back what we took back
Future<void> dropTaken(
  DatabaseExecutor db, {
  String? uid,
  String? peer,
  String? group,
  bool editsOnly = false,
}) async {
  try {
    await _dropTaken(
      db,
      uid: uid,
      peer: peer,
      group: group,
      editsOnly: editsOnly,
    );
  } catch (e) {
    // a store with no such table (the developer chat's) keeps none
    dlog('restore: taken rows not dropped (${e.runtimeType})');
  }
}

Future<void> _dropTaken(
  DatabaseExecutor db, {
  String? uid,
  String? peer,
  String? group,
  bool editsOnly = false,
}) async {
  final kind = editsOnly ? ' AND kind = ?' : '';
  if (uid != null) {
    await db.delete(
      'taken_out',
      where: 'msg_uid = ? AND kind = ?',
      whereArgs: [uid, kTakenEdit],
    );
  }
  if (peer != null) {
    await db.delete(
      'taken_out',
      where: 'peer_id = ?$kind',
      whereArgs: [peer, if (editsOnly) kTakenEdit],
    );
  }
  if (group != null) {
    await db.delete(
      'taken_out',
      where: 'group_id = ?$kind',
      whereArgs: [group, if (editsOnly) kTakenEdit],
    );
  }
}

/// one of ours taken back ([kTakenUnsend]) or edited ([kTakenEdit]) at
/// [at], in [peer]'s chat or in [group]. a take-back leaves its edit
/// nothing to change. older ones go first
Future<void> noteTaken(
  DatabaseExecutor db,
  String uid,
  String kind, {
  String? peer,
  String? group,
  required int at,
}) async {
  await pruneTaken(db, nowMs: at);
  if (kind == kTakenUnsend) {
    await db.delete(
      'taken_out',
      where: 'msg_uid = ? AND kind = ?',
      whereArgs: [uid, kTakenEdit],
    );
  }
  await db.insert('taken_out', {
    'msg_uid': uid,
    'kind': kind,
    'peer_id': peer,
    'group_id': group,
    'at': at,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

typedef Taken = ({String uid, String kind, String? group, int at});

/// what [noteTaken] kept from [since] on: [peer]'s, or every group's when
/// null
Future<List<Taken>> takenSince(
  DatabaseExecutor db, {
  String? peer,
  required int since,
}) async {
  final rows = await db.query(
    'taken_out',
    where: peer == null
        ? 'group_id IS NOT NULL AND at >= ?'
        : 'peer_id = ? AND at >= ?',
    whereArgs: [?peer, since],
    orderBy: 'at ASC',
  );
  return [
    for (final r in rows)
      (
        uid: r['msg_uid'] as String,
        kind: r['kind'] as String,
        group: r['group_id'] as String?,
        at: r['at'] as int,
      ),
  ];
}
