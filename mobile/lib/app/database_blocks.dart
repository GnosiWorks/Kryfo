// SPDX-License-Identifier: GPL-3.0-or-later
// blocks, and keys taken as not who they said

part of '../main.dart';

mixin _BlockRows {
  // what these rows take from the rest of HaloDb
  HaloContainer get container;
  Future<Database> open();
  Future<void> _scrubMedia(List<Map<String, Object?>> rows);
  Future<void> _unreadGo(DatabaseExecutor db, List<Map<String, Object?>> rows);
  Future<void> _dropFilesComingFrom(DatabaseExecutor t, String peerId);

  // "this isn't them": everything of [haloId] here goes in one go, what
  // they wrote in groups and their seats there too, and [keyHex], the key
  // the number was made from, is blocked. by the key alone: the same words
  // on another key are someone else, though none who writes first is given
  // them (name_tombs). a group they ran has no admin after. the files go
  // once it is done. the uids of what of theirs went, for the shade
  Future<List<String>> removeAndBlockKey(String haloId, String keyHex) async {
    final db = await open();
    final (rows, wallpaper) = await db.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: [..._kFileCols, ..._kUnreadCols, 'msg_uid', 'poll'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      final uids = [
        for (final r in rows)
          if (r['msg_uid'] case final String u) u,
      ];
      final polls = [
        for (final r in rows)
          if (r['poll'] != null)
            if (r['msg_uid'] case final String u) u,
      ];
      final c = await t.query(
        'contacts',
        columns: ['atmosphere'],
        where: 'halo_id = ?',
        whereArgs: [haloId],
        limit: 1,
      );
      final atmo = c.isEmpty ? null : c.first['atmosphere'] as String?;
      // what they left unread in a group goes from its count
      await _unreadGo(t, [
        for (final r in rows)
          if (r['group_id'] != null) r,
      ]);
      for (var i = 0; i < uids.length; i += 400) {
        final part = uids.sublist(i, min(i + 400, uids.length));
        final marks = List.filled(part.length, '?').join(', ');
        for (final (table, col) in const [
          ('reactions', 'msg_uid'),
          ('poll_votes', 'poll_uid'),
          ('pins_out', 'msg_uid'),
          ('edits_out', 'msg_uid'),
          ('opener_again', 'msg_uid'),
          ('frame_order', 'msg_uid'),
          ('notif_rings', 'msg_uid'),
          ('group_media_owed', 'msg_uid'),
        ]) {
          await t.delete(table, where: '$col IN ($marks)', whereArgs: part);
        }
      }
      await _dropFilesComingFrom(t, haloId);
      for (final (table, col) in const [
        ('reactions', 'reactor'),
        ('poll_votes', 'voter'),
        ('media_chunks', 'sender'),
        // their files coming in groups too: nothing of theirs stays
        ('file_fetches', 'sender'),
        ('frame_order', 'sender'),
        ('frames_out', 'peer_id'),
        ('pins_out', 'peer_id'),
        ('edits_out', 'peer_id'),
        ('held_onion', 'peer_id'),
        ('first_kept', 'peer'),
        ('gone_in', 'peer_id'),
        ('notif_tags', 'chat'),
        ('notif_rings', 'chat'),
        ('shield', 'halo_id'),
        ('vouches', 'halo_id'),
        ('vouches', 'voucher_id'),
        ('block_spans', 'peer_id'),
        ('blocked_drops', 'peer_id'),
        ('group_members', 'halo_id'),
        ('group_media_owed', 'member'),
        ('group_ctl_out', 'member'),
        ('group_resent', 'member'),
        ('support_chats', 'halo_id'),
        ('sessions', 'address'),
        ('peer_identities', 'address'),
        ('messages', 'peer_id'),
        ('contacts', 'halo_id'),
      ]) {
        await t.delete(table, where: '$col = ?', whereArgs: [haloId]);
      }
      // what of theirs went in groups, by group and sender (goneKey). the
      // delete marked their polls as just gone: nothing of them stays
      final inGroups = [
        for (final r in await t.query(
          'gone_in',
          columns: ['peer_id'],
          where: 'peer_id LIKE ?',
          whereArgs: ['group:%'],
        ))
          if (r['peer_id'] case final String k)
            if (k.substring(6).split(':').skip(1).join(':') == haloId) k,
      ];
      for (final (table, col, keys) in [
        ('gone_in', 'peer_id', inGroups),
        ('polls_gone', 'uid', polls),
      ]) {
        for (var i = 0; i < keys.length; i += 400) {
          final part = keys.sublist(i, min(i + 400, keys.length));
          await t.delete(
            table,
            where: '$col IN (${List.filled(part.length, '?').join(', ')})',
            whereArgs: part,
          );
        }
      }
      await t.update(
        'groups',
        {'admin_id': kAdminGone},
        where: 'admin_id = ?',
        whereArgs: [haloId],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await t.insert('blocked_keys', {
        'x': keyHex.trim().toLowerCase(),
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await t.insert('name_tombs', {
        'name': haloId,
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await oweTidy(t);
      return (rows, atmo);
    });
    await _scrubMedia(rows);
    // their chat's own photo, named for them in this container's folder
    if (wallpaper != null && wallpaper.startsWith('image:')) {
      final f = File(wallpaper.substring(6));
      final folder = await container.folder('wallpapers');
      if (p.isWithin(folder.path, f.path) && await f.exists()) {
        await shredFile(f.path);
      }
    }
    return [
      for (final r in rows)
        if (r['msg_uid'] case final String u) u,
    ];
  }

  // words "this isn't them" let go here: nobody who writes first gets them
  Future<bool> tombed(String name) async {
    final db = await open();
    final r = await db.query(
      'name_tombs',
      columns: ['name'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<List<({String name, int at})>> tombs() async {
    final db = await open();
    return [
      for (final r in await db.query('name_tombs'))
        (name: r['name'] as String, at: (r['at'] as num).toInt()),
    ];
  }

  // what another container blocked and let go, kept here as it goes
  Future<void> takeBlocks(
    List<({String x, int at})> keys,
    List<({String name, int at})> tombs,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      for (final k in keys) {
        await t.insert('blocked_keys', {
          'x': k.x,
          'at': k.at,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final n in tombs) {
        await t.insert('name_tombs', {
          'name': n.name,
          'at': n.at,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  // an add the person made takes the words again
  Future<void> clearTomb(String name) async {
    final db = await open();
    await db.delete('name_tombs', where: 'name = ?', whereArgs: [name]);
  }

  // someone let go in the other container: no seat in a group here, no
  // row that only held their key, and no admin in a group they ran. only
  // where the row here has [keyHex], or no key at all: the same words on
  // another key are someone else
  Future<void> dropSeats(String haloId, String keyHex) async {
    final db = await open();
    await db.transaction((t) async {
      final row = await t.query(
        'contacts',
        columns: ['xpub'],
        where: 'halo_id = ?',
        whereArgs: [haloId],
        limit: 1,
      );
      final x = row.isEmpty
          ? ''
          : ((row.first['xpub'] as String?) ?? '').trim().toLowerCase();
      if (x.isNotEmpty && x != keyHex.trim().toLowerCase()) return;
      for (final (table, col) in const [
        ('group_members', 'halo_id'),
        ('group_media_owed', 'member'),
        ('group_ctl_out', 'member'),
        ('group_resent', 'member'),
      ]) {
        await t.delete(table, where: '$col = ?', whereArgs: [haloId]);
      }
      await t.update(
        'groups',
        {'admin_id': kAdminGone},
        where: 'admin_id = ?',
        whereArgs: [haloId],
      );
      final own = await t.query(
        'messages',
        columns: ['id'],
        where: _kOneToOne,
        whereArgs: [haloId],
        limit: 1,
      );
      if (own.isEmpty) {
        await t.delete(
          'contacts',
          where: 'halo_id = ? AND accepted = ?',
          whereArgs: [haloId, 0],
        );
      }
    });
  }

  // a key blocked here by "this isn't them"
  Future<bool> keyBlocked(String keyHex) async {
    final db = await open();
    final r = await db.query(
      'blocked_keys',
      columns: ['x'],
      where: 'x = ?',
      whereArgs: [keyHex.trim().toLowerCase()],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  // the keys blocked here, the newest first
  Future<List<({String x, int at})>> blockedKeys() async {
    final db = await open();
    return [
      for (final r in await db.query('blocked_keys', orderBy: 'at DESC'))
        (x: r['x'] as String, at: (r['at'] as num).toInt()),
    ];
  }

  Future<void> unblockKey(String keyHex) async {
    final db = await open();
    await db.delete(
      'blocked_keys',
      where: 'x = ?',
      whereArgs: [keyHex.trim().toLowerCase()],
    );
  }

  // a block starts the clocks of what they sent that waits to be read, in
  // their chat and in groups, and drops what was queued for them. an
  // unblock leaves them counting. what of ours waits for them is not sent,
  // either way: an unblock sends nothing without a tap
  Future<void> setBlocked(String haloId, bool blocked) async {
    final db = await open();
    await db.transaction((t) async {
      await t.update(
        'contacts',
        {
          'blocked': blocked ? 1 : 0,
          // an unblock is no accept: what an accept owed them goes with it
          if (blocked) 'ack_owed': 0,
        },
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
      if (blocked) {
        await _lightFrom(t, haloId);
        await _dropQueuedTo(t, haloId);
      }
      await _holdBackTo(t, haloId);
      await _markSpan(t, haloId, blocked);
    });
  }

  // a block opens a span and an unblock closes it
  static Future<void> _markSpan(
    DatabaseExecutor t,
    String haloId,
    bool blocked,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final open = await t.query(
        'block_spans',
        columns: ['rowid AS rowid'],
        where: 'peer_id = ? AND to_at IS NULL',
        whereArgs: [haloId],
        limit: 1,
      );
      if (blocked && open.isEmpty) {
        await t.insert('block_spans', {'peer_id': haloId, 'from_at': now});
      } else if (!blocked && open.isNotEmpty) {
        await t.update(
          'block_spans',
          {'to_at': now},
          where: 'peer_id = ? AND to_at IS NULL',
          whereArgs: [haloId],
        );
      }
    } catch (e) {
      dlog('block span: $e');
    }
  }

  // every span of a block on [haloId], from and to, to null while it holds
  Future<List<(int, int?)>> blockSpansOf(String haloId) async {
    try {
      final db = await open();
      final r = await db.query(
        'block_spans',
        columns: ['from_at', 'to_at'],
        where: 'peer_id = ?',
        whereArgs: [haloId],
      );
      return [for (final x in r) (x['from_at'] as int, x['to_at'] as int?)];
    } catch (e) {
      dlog('block span: $e');
      return const [];
    }
  }

  // when the block on [haloId] that holds now began, or null without one
  Future<int?> blockedSince(String haloId) async {
    try {
      final db = await open();
      final r = await db.query(
        'block_spans',
        columns: ['from_at'],
        where: 'peer_id = ? AND to_at IS NULL',
        whereArgs: [haloId],
        limit: 1,
      );
      return r.isEmpty ? null : r.first['from_at'] as int?;
    } catch (e) {
      dlog('block span: $e');
      return null;
    }
  }

  // what came from someone while they were blocked, by uid. one that comes
  // again keeps its row a while longer, so a sender that retries for weeks
  // is still turned away
  int _dropsSweptAt = 0;
  Future<void> noteBlockedDrop(String haloId, String uid) async {
    try {
      final db = await open();
      _dropsSweptAt = await noteBlockedDropIn(
        db,
        haloId,
        uid,
        now: DateTime.now().millisecondsSinceEpoch,
        sweptAt: _dropsSweptAt,
      );
    } catch (e) {
      dlog('blocked drop: $e');
    }
  }

  Future<bool> droppedWhileBlocked(String haloId, String uid) async {
    try {
      final db = await open();
      if (!await droppedIn(db, haloId, uid)) return false;
      await noteBlockedDrop(haloId, uid);
      return true;
    } catch (e) {
      dlog('blocked drop: $e');
      return false;
    }
  }

  // [haloId] blocked elsewhere: their rows here that wait start counting
  Future<void> lightBurnsFrom(String haloId) async {
    final db = await open();
    await db.transaction((t) => _lightFrom(t, haloId));
  }

  static Future<void> _lightFrom(DatabaseExecutor t, String haloId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await t.query(
      'messages',
      columns: ['id', 'sent_at', 'burn_secs'],
      where: 'peer_id = ? AND $_kBurnIdle',
      whereArgs: [haloId],
    );
    for (final r in rows) {
      final sent = (r['sent_at'] as num?)?.toInt() ?? now;
      await _lightUnread(t, r, min(now, burnStartBy(sent, now)));
    }
  }

  // every blocked id, accepted or not. contacts() is accepted-only, so a
  // caller built on it never sees someone blocked while still a stranger.
  Future<Set<String>> blockedIds() async => _blockedIn(await open());

  // their rows, each with listen = 1 while its block is young enough to
  // be listened on (kBlockListenFor). without the spans none is
  Future<List<Map<String, Object?>>> blockedRows({required int now}) async {
    final db = await open();
    try {
      return await db.rawQuery(kBlockedRowsSql, [now - kBlockListenFor]);
    } catch (e) {
      dlog('blocked rows: $e');
      return db.rawQuery(
        'SELECT *, 0 AS listen FROM contacts WHERE blocked = 1',
      );
    }
  }

  // blocked, or never taken in: no one a restore asks to start afresh
  Future<Set<String>> unaskedIds() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'accepted = 0',
    );
    return {
      ...await _blockedIn(db),
      for (final r in rows) r['halo_id'] as String,
    };
  }

  Future<bool> isBlocked(String haloId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['blocked'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['blocked'] as int? ?? 0) == 1;
  }

  // a block here: our texts and files to them that have not gone are not
  // sent. a tap sends each again, nothing else does. a group's rows are
  // the group's
  static Future<void> _holdBackTo(DatabaseExecutor db, String peerId) async {
    for (final (where, args) in [
      ('group_id IS NULL', const <Object?>[]),
      ('group_id = ?', const <Object?>['']),
    ]) {
      try {
        await db.update(
          'messages',
          {'sent': kNotSent},
          where: 'peer_id = ? AND direction = ? AND sent = ? AND $where',
          whereArgs: [peerId, 'out', 0, ...args],
        );
      } catch (e) {
        dlog('block: rows not held back (${e.runtimeType})');
      }
    }
  }
}

// a timed row that came in and was never read: its clock waits
const _kBurnIdle =
    "direction = 'in' AND burn_secs IS NOT NULL AND burn_at IS NULL";

// a waiting row's clock started at [from] with nobody reading it: it
// counts down, and stays out of lists until read (burnWaitsRow)
Future<void> _lightUnread(
  DatabaseExecutor t,
  Map<String, Object?> r,
  int from,
) => t.update(
  'messages',
  {'burn_at': from + (r['burn_secs'] as num).toInt() * 1000, 'burn_unseen': 1},
  where: 'id = ? AND burn_at IS NULL',
  whereArgs: [r['id']],
);

Future<Set<String>> _blockedIn(DatabaseExecutor db) async {
  final rows = await db.query(
    'contacts',
    columns: ['halo_id'],
    where: 'blocked = 1',
  );
  return {for (final r in rows) r['halo_id'] as String};
}

// every blocked row, and whether its open span is listened on from after
// the argument: from its start, or from when a seeded one was made
const kBlockedRowsSql =
    'SELECT c.*, EXISTS (SELECT 1 FROM block_spans s WHERE '
    's.peer_id = c.halo_id AND s.to_at IS NULL AND '
    'COALESCE(s.listen_from, s.from_at) > ?) AS listen '
    'FROM contacts c WHERE c.blocked = 1';

// the stamp is the sender's clock, which may run behind this one. what
// they wrote in the last minutes before the unblock is let in, or a slow
// clock costs them what they sent once they were free to
const kUnblockGrace = 10 * 60 * 1000;

// a stamp further ahead of this clock than this is taken as now
const kStampAhead = 10 * 60 * 1000;

// whether a copy from someone not blocked now may be what a block of
// theirs held back. [ended]: their spans that ended, from and to.
// [reached]: when it reached the relay, or this phone, by this clock: a
// stored one between what the relay was known to have handed over and the
// subscribe, a live one as it came. one that reached it while a block
// held stays out whatever it says. one whose window runs past the unblock,
// or that no lane dates, is judged by its stamps as it was before the
// lanes said (stampHeld). one that reached it after is still kept out if
// their own two stamps say it was written while one held: the wrap time
// less when it was written is how long before it went it was written,
// whatever their clock reads; with no wrap time, its written stamp and the
// grace. nothing is noted by this: a copy sent again after the unblock
// comes live, and only the uids noted while the block held keep that out
bool heldBySpans(
  List<(int, int)> ended, {
  Reached? reached,
  required int came,
  int? now,
  int? written,
  int? wrapped,
}) {
  final at = now ?? DateTime.now().millisecondsSinceEpoch;
  if (reached == null) {
    return stampHeld(
      ended,
      written: written,
      wrapped: wrapped,
      came: came,
      now: at,
    );
  }
  final r = reached;
  for (final span in ended) {
    final (from, to) = span;
    if (r.until <= from) continue;
    if (r.until <= to) return true;
    if (r.from < to || wrapped == null) {
      if (stampHeld(
        [span],
        written: written,
        wrapped: wrapped,
        came: r.until,
        now: at,
      )) {
        return true;
      }
      continue;
    }
    final age = written != null && wrapped > written ? wrapped - written : 0;
    final wrote = r.until - age;
    if (wrote >= from && wrote < to) return true;
  }
  return false;
}

// the stamps alone: when it was written by their clock, never past the
// wrap, never far ahead of this clock, inside an ended span less how far
// behind ours their clock may run, no further than the copy took to come
bool stampHeld(
  List<(int, int)> ended, {
  int? written,
  int? wrapped,
  required int came,
  required int now,
}) {
  var at = written ?? wrapped;
  if (at == null || at <= 0) return false;
  if (wrapped != null && wrapped > 0 && wrapped < at) at = wrapped;
  if (at > now + kStampAhead) at = now;
  final slack = wrapped == null || wrapped <= 0
      ? kUnblockGrace
      : (came - wrapped).clamp(0, kUnblockGrace);
  for (final (from, to) in ended) {
    if (from <= at && to > at + slack) return true;
  }
  return false;
}

// how many dropped uids are kept per person, the newest
const kBlockedDropsKept = 2000;

// keeps [uid] as dropped from [haloId] at [now], their newest
// kBlockedDropsKept only, and at most once a day lets go of what has not
// come again in sixty days. when it last swept
Future<int> noteBlockedDropIn(
  DatabaseExecutor db,
  String haloId,
  String uid, {
  required int now,
  required int sweptAt,
}) async {
  await db.rawInsert(
    'INSERT OR REPLACE INTO blocked_drops (peer_id, uid, at) '
    'VALUES (?, ?, ?)',
    [haloId, uid, now],
  );
  await db.rawDelete(
    'DELETE FROM blocked_drops WHERE peer_id = ?1 AND rowid NOT IN '
    '(SELECT rowid FROM blocked_drops WHERE peer_id = ?1 '
    'ORDER BY at DESC, rowid DESC LIMIT ?2)',
    [haloId, kBlockedDropsKept],
  );
  if (now - sweptAt < 86400000) return sweptAt;
  await db.rawDelete('DELETE FROM blocked_drops WHERE at < ?', [
    now - 60 * 86400000,
  ]);
  return now;
}

// whether [uid] from [haloId] was dropped while they were blocked
Future<bool> droppedIn(DatabaseExecutor db, String haloId, String uid) async =>
    (await db.rawQuery(
      'SELECT 1 FROM blocked_drops WHERE peer_id = ? AND uid = ? LIMIT 1',
      [haloId, uid],
    )).isNotEmpty;

/// a group whose admin "this isn't them" took off this phone: it has none,
/// so no change to it is taken from anyone. never an id's shape
const kAdminGone = 'gone:admin';
