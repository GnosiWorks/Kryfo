// SPDX-License-Identifier: GPL-3.0-or-later
// what went here, so a late own copy of it stays out (own_sync.dart). a
// row is a chat (ownChatName) and a uid: a message deleted, taken back,
// burned or cleared here or on another device of mine, held here or not
// yet. one row per chat under kOwnGoneAll says that everything of the
// chat written up to 'upto' went (a clear, a chat deleted). a uid row with
// 'upto' is a message my other device burns then and this one lacks
import 'package:sqflite_sqlcipher/sqflite.dart';

/// how long a row keeps a late copy out: a copy is sent again for 7 days
/// (kDeviceCopyKept), each send waits on a relay up to 14 (kFarewellKept),
/// and a day for clocks. counted from when the row was written, which is
/// never before the copy was made
const kOwnGoneFor = Duration(days: 22);

/// the uid of a chat's row for everything written up to its 'upto'
const kOwnGoneAll = '*';

Future<void> _prune(DatabaseExecutor db, int now) => db.delete(
  'own_gone',
  where: 'at < ?',
  whereArgs: [now - kOwnGoneFor.inMilliseconds],
);

/// [uids] of [chat] went
Future<void> ownGoneNote(
  DatabaseExecutor db,
  String chat,
  Iterable<String> uids, {
  required int now,
}) async {
  await _prune(db, now);
  final b = db.batch();
  for (final u in uids) {
    if (u.isEmpty || u == kOwnGoneAll) continue;
    b.insert('own_gone', {
      'chat': chat,
      'uid': u,
      'at': now,
      'upto': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await b.commit(noResult: true);
}

/// [uid] of [chat] burns at [burnAt] on my other device; one gone already
/// stays gone, and the earlier burn wins
Future<void> ownGoneBurns(
  DatabaseExecutor db,
  String chat,
  String uid,
  int burnAt, {
  required int now,
}) async {
  if (uid.isEmpty || uid == kOwnGoneAll) return;
  await _prune(db, now);
  final r = await db.query(
    'own_gone',
    columns: ['upto'],
    where: 'chat = ? AND uid = ?',
    whereArgs: [chat, uid],
    limit: 1,
  );
  if (r.isNotEmpty) {
    final was = r.first['upto'] as int?;
    if (was == null || was <= burnAt) return;
  }
  await db.insert('own_gone', {
    'chat': chat,
    'uid': uid,
    'at': now,
    'upto': burnAt,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// everything of [chat] written up to [upto] went. [ends]: the chat itself
/// went, so its uid rows go and this one row stands for them
Future<void> ownGoneUpTo(
  DatabaseExecutor db,
  String chat,
  int upto, {
  required int now,
  bool ends = false,
}) async {
  await _prune(db, now);
  if (ends) {
    await db.delete(
      'own_gone',
      where: 'chat = ? AND uid != ?',
      whereArgs: [chat, kOwnGoneAll],
    );
  }
  final r = await db.query(
    'own_gone',
    columns: ['upto'],
    where: 'chat = ? AND uid = ?',
    whereArgs: [chat, kOwnGoneAll],
    limit: 1,
  );
  final was = r.isEmpty ? null : r.first['upto'] as int?;
  await db.insert('own_gone', {
    'chat': chat,
    'uid': kOwnGoneAll,
    'at': now,
    'upto': was != null && was > upto ? was : upto,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// what of [uids] in [chat] went: gone, or the earliest time one burns on
/// my other device. [written] when the frame says when it was (a copy of
/// mine) or my phone says when it took it (a contact's frame passed on);
/// null for a contact's own frame, which a chat's row never stands for
Future<({bool gone, int? burnAt})> ownGoneOf(
  DatabaseExecutor db,
  String chat,
  Iterable<String> uids, {
  int? written,
  required int now,
}) async {
  const none = (gone: false, burnAt: null);
  final ids = [
    for (final u in uids)
      if (u.isNotEmpty && u != kOwnGoneAll) u,
  ];
  if (ids.isEmpty && written == null) return none;
  final List<Map<String, Object?>> rows;
  try {
    rows = await db.query(
      'own_gone',
      columns: ['uid', 'upto'],
      where:
          'chat = ? AND at >= ? AND uid IN '
          '(${List.filled(ids.length + 1, '?').join(', ')})',
      whereArgs: [chat, now - kOwnGoneFor.inMilliseconds, kOwnGoneAll, ...ids],
    );
  } catch (_) {
    // a database without the device tables keeps nothing out
    return none;
  }
  int? burnAt;
  for (final r in rows) {
    final upto = r['upto'] as int?;
    if (r['uid'] == kOwnGoneAll) {
      if (written != null && upto != null && written <= upto) {
        return (gone: true, burnAt: null);
      }
      continue;
    }
    if (upto == null || upto <= now) return (gone: true, burnAt: null);
    if (burnAt == null || upto < burnAt) burnAt = upto;
  }
  return (gone: false, burnAt: burnAt);
}

/// the rows of [chat]
Future<void> ownGoneDropChat(DatabaseExecutor db, String chat) =>
    db.delete('own_gone', where: 'chat = ?', whereArgs: [chat]);

/// every row, once no device of mine is linked: none can send a copy
Future<void> ownGoneDropIfAlone(DatabaseExecutor db) async {
  final r = await db.rawQuery(
    'SELECT 1 FROM own_devices WHERE removed_at IS NULL LIMIT 1',
  );
  if (r.isEmpty) await db.delete('own_gone');
}
