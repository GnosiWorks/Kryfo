// SPDX-License-Identifier: GPL-3.0-or-later
// what a restore must not undo. a timed copy the relays still hold from
// before it counts from then, never from a fresh clock (burnCameAt), and
// our own unsends and last edits go again to a contact whose restore
// brought back what we took back or changed since their backup
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// when the last restore landed, by this clock: a timed copy from before it
/// counts from then at the latest. kept while relays may hold such a copy,
/// then dropped
const kRestoreLandedPref = 'restore.landed';
const kRestoreLandedKeep = Duration(days: 16);

/// [kRestoreLandedPref] as this start read it, null with no restore lately
int? restoreLandedAt;

/// a restore lands now
Future<void> noteRestoreLanded({int? nowMs}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(
    kRestoreLandedPref,
    nowMs ?? DateTime.now().millisecondsSinceEpoch,
  );
}

/// when the last restore landed, while it is recent. an older one is
/// dropped
Future<int?> restoreLandedOf(SharedPreferences prefs, {int? nowMs}) async {
  final at = prefs.getInt(kRestoreLandedPref);
  if (at == null) return null;
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  if (now - at > kRestoreLandedKeep.inMilliseconds) {
    await prefs.remove(kRestoreLandedPref);
    return null;
  }
  return at;
}

/// our unsends and last edits are kept this long: a heal's since reaches
/// back 15 days, and a day more
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
    body TEXT NOT NULL DEFAULT '',
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
  if (have.isEmpty) await takenTables(db);
}

/// one of ours taken back ([kTakenUnsend]) or edited ([kTakenEdit], [body]
/// its words) at [at], in [peer]'s chat or in [group]. a take-back leaves
/// its edit nothing to change. older ones go first
Future<void> noteTaken(
  DatabaseExecutor db,
  String uid,
  String kind, {
  String? peer,
  String? group,
  String body = '',
  required int at,
}) async {
  await db.delete(
    'taken_out',
    where: 'at < ?',
    whereArgs: [at - kTakenKeep.inMilliseconds],
  );
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
    'body': body,
    'at': at,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

typedef Taken = ({String uid, String kind, String? group, String body, int at});

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
        body: r['body'] as String? ?? '',
        at: r['at'] as int,
      ),
  ];
}
