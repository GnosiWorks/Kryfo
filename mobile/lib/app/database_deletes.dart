// SPDX-License-Identifier: GPL-3.0-or-later
// rows going: deletes, timed messages and what went

part of '../main.dart';

mixin _DeleteRows {
  // what these rows take from the rest of HaloDb
  HaloContainer get container;
  Future<Database> open();
  bool get isOpen;
  set _unfinished(Map<String, ({int bytes, int at})>? value);
  Future<List<({String chat, bool group})>> spentDraftsIn(
    DatabaseExecutor db,
    int now,
  );

  // the files go too, not just the rows. zeros first, then unlink, so a raw
  // read of the flash finds nothing either.
  Future<void> _scrubMedia(List<Map<String, Object?>> rows) async {
    for (final r in rows) {
      for (final k in const ['media_path', 'file_path']) {
        final mp = r[k] as String?;
        if (mp != null && mp.isNotEmpty) await shredFile(mp);
      }
    }
  }

  /// the files in this container's media folder that no message names,
  /// last written before [before]: what a delete left behind. a file is
  /// matched by its name in the folder, so rows written under another
  /// path to the same folder still hold theirs. folders are left alone
  Future<List<File>> unnamedMedia({required DateTime before}) async {
    final db = await open();
    final named = <String>{};
    for (final col in _kFileCols) {
      for (final r in await db.query(
        'messages',
        columns: [col],
        where: '$col IS NOT NULL',
      )) {
        final v = r[col];
        if (v is String && v.isNotEmpty) named.add(p.basename(v));
      }
    }
    final dir = await container.mediaDir();
    final out = <File>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || named.contains(p.basename(e.path))) continue;
      if ((await e.lastModified()).isBefore(before)) out.add(e);
    }
    return out;
  }

  // every 1:1 row of one chat that is not a person's, the notes to self:
  // their files and reactions go with them. how many went
  Future<int> deleteAllOf(String chatId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kOneToOne,
      whereArgs: [chatId],
    );
    await db.transaction((t) async {
      for (final r in rows) {
        final uid = r['msg_uid'] as String?;
        if (uid != null) {
          await t.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        }
      }
      await _noteGone(t, rows);
      await t.delete('messages', where: _kOneToOne, whereArgs: [chatId]);
    });
    await _scrubMedia(rows);
    return rows.length;
  }

  // [from] takes only that sender's rows of the uid, never a twin's
  Future<void> deleteMessage(String msgUid, {String? from}) async {
    final db = await open();
    final only = from == null ? '' : " AND direction = 'in' AND peer_id = ?";
    final args = [msgUid, if (from != null) from];
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: 'msg_uid = ?$only',
      whereArgs: args,
    );
    await _unreadGo(db, media);
    await _noteGone(db, media);
    await db.delete('messages', where: 'msg_uid = ?$only', whereArgs: args);
    // what hangs off the uid goes with its last row
    final left = await db.query(
      'messages',
      columns: ['id'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (left.isEmpty) {
      await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [msgUid]);
      await db.delete(
        'group_media_owed',
        where: 'msg_uid = ?',
        whereArgs: [msgUid],
      );
    }
    await _scrubMedia(media);
  }

  /// [msgUid] came in from [peer] and burned or was deleted here lately
  Future<bool> goneFrom(String peer, String msgUid) async {
    final db = await open();
    final r = await db.query(
      'gone_in',
      columns: ['at'],
      where: 'msg_uid = ? AND peer_id = ?',
      whereArgs: [msgUid, peer],
      limit: 1,
    );
    if (r.isEmpty) return false;
    final at = (r.first['at'] as num).toInt();
    return DateTime.now().millisecondsSinceEpoch - at <
        HaloDb.kGoneFor.inMilliseconds;
  }

  // rows that came in and go before they were read take their unread mark
  // with them. the unread ones are the newest that many that came in
  Future<void> _unreadGo(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows,
  ) async {
    final gone = <(String, bool), Set<int>>{};
    for (final r in rows) {
      final id = r['id'];
      if (r['direction'] != 'in' || id is! int) continue;
      final g = r['group_id'] as String?;
      final peer = r['peer_id'] as String?;
      final chat = g != null ? (g, true) : (peer, false);
      if (chat.$1 == null) continue;
      (gone[(chat.$1!, chat.$2)] ??= {}).add(id);
    }
    for (final MapEntry(key: (chat, group), value: ids) in gone.entries) {
      final table = group ? 'groups' : 'contacts';
      final key = group ? 'group_id = ?' : 'halo_id = ?';
      final c = await db.query(
        table,
        columns: ['unread'],
        where: key,
        whereArgs: [chat],
        limit: 1,
      );
      final unread = c.isEmpty ? 0 : (c.first['unread'] as int? ?? 0);
      if (unread <= 0) continue;
      final newest = await db.query(
        'messages',
        columns: ['id'],
        where: group
            ? "group_id = ? AND direction = 'in'"
            : "$_kOneToOne AND direction = 'in'",
        whereArgs: [chat],
        orderBy: 'id DESC',
        limit: unread,
      );
      final n = newest.where((r) => ids.contains(r['id'])).length;
      if (n == 0) continue;
      // nothing left unread in a group: no mention is left in it either
      await db.update(
        table,
        {'unread': unread - n, if (group && unread - n <= 0) 'mentioned': 0},
        where: key,
        whereArgs: [chat],
      );
    }
  }

  // a timed message of ours that went but never had its clock started:
  // from before receipts lit it, or a stop between marking it sent and
  // lighting it. once per open is enough, nothing makes new ones after
  bool _strandedLit = false;
  Future<void> _lightStrandedOnce(Database db) async {
    if (_strandedLit) return;
    await _lightStranded(db);
    _strandedLit = true;
  }

  Future<int> lightStrandedBurns() async => _lightStranded(await open());

  static Future<int> _lightStranded(Database db) async {
    final rows = await db.query(
      'messages',
      columns: ['id', 'burn_secs'],
      where:
          "direction = 'out' AND sent = 1 AND burn_secs IS NOT NULL "
          'AND burn_at IS NULL',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      final secs = (r['burn_secs'] as num).toInt();
      await db.update(
        'messages',
        {'burn_at': now + secs * 1000},
        where: 'id = ? AND burn_at IS NULL',
        whereArgs: [r['id']],
      );
    }
    return rows.length;
  }

  // a row of ours that has not gone yet is not due: its clock starts when
  // it goes. only outgoing rows are ever unsent
  static const _kBurnDue = 'burn_at IS NOT NULL AND burn_at < ? AND sent = 1';

  // the timed rows that came in and wait to be read, with [cols]
  Future<List<Map<String, Object?>>> _idle(Database db, List<String> cols) =>
      db.query(
        'messages',
        columns: {...cols, 'id', 'peer_id', 'sent_at', 'burn_secs'}.toList(),
        where: _kBurnIdle,
      );

  // waited unread a day and its window after that: due as if lit then,
  // whether or not anything lit it. a phone off all that time, or a vault
  // shut, burns it at the next sweep
  static bool _waitedOut(Map<String, Object?> r, int now) =>
      burnStartBy((r['sent_at'] as num?)?.toInt() ?? now, now) +
          (r['burn_secs'] as num).toInt() * 1000 <
      now;

  Future<int> _dropRows(Database db, List<Map<String, Object?>> rows) async {
    var n = 0;
    for (var i = 0; i < rows.length; i += 500) {
      final ids = [for (final r in rows.skip(i).take(500)) r['id']];
      n += await db.delete(
        'messages',
        where: 'id IN (${List.filled(ids.length, '?').join(', ')})',
        whereArgs: ids,
      );
    }
    return n;
  }

  // what still waits a day after it came starts counting, unread, and so
  // does a blocked sender's (a restore or a hide brings blocks along).
  // [blocked] is everyone blocked on this side, this container's own list
  // when null. an arrival further ahead of this phone's clock than
  // kBurnSkew counts from now, written down so it cannot wait on
  Future<void> _lightWaited(
    Database db,
    int now,
    List<Map<String, Object?>> idle,
    Future<Set<String>> Function()? blocked,
  ) async {
    final rows = [
      for (final r in idle)
        if (!_waitedOut(r, now)) r,
    ];
    if (rows.isEmpty) return;
    final out = await (blocked == null ? _blockedIn(db) : blocked());
    final ahead = now + kBurnSkew.inMilliseconds;
    final lit = <(Map<String, Object?>, int)>[];
    for (final r in rows) {
      final sent = (r['sent_at'] as num?)?.toInt() ?? now;
      final by = burnStartBy(sent, now);
      if (out.contains(r['peer_id'])) {
        lit.add((r, min(now, by)));
      } else if (by <= now || sent > ahead) {
        lit.add((r, by));
      }
    }
    if (lit.isEmpty) return;
    await db.transaction((t) async {
      for (final (r, from) in lit) {
        await _lightUnread(t, r, from);
      }
    });
  }

  // [blocked] as for purgeExpired
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {
    final db = await open();
    await _lightStrandedOnce(db);
    final cut = DateTime.now().millisecondsSinceEpoch;
    final due = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kBurnDue,
      whereArgs: [cut],
    );
    final idle = await _idle(db, [
      ..._kFileCols,
      ..._kUnreadCols,
      ..._kGoneCols,
    ]);
    // after what waits is read: nothing in it was filed past this now
    final now = DateTime.now().millisecondsSinceEpoch;
    final waited = [
      for (final r in idle)
        if (_waitedOut(r, now)) r,
    ];
    final rows = [...due, ...waited];
    await _unreadGo(db, rows);
    await _noteGone(db, rows, burned: true);
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        // the sweep would have taken its notification down, and this
        // read can beat the sweep to it
        if (r['direction'] == 'in') unawaited(clearMessageNotification(uid));
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
        await db.delete(
          'group_media_owed',
          where: 'msg_uid = ?',
          whereArgs: [uid],
        );
      }
    }
    await db.delete('messages', where: _kBurnDue, whereArgs: [cut]);
    await _dropRows(db, waited);
    await _scrubMedia(rows);
    await _lightWaited(db, now, idle, blocked);
  }

  Future<void> clearConversation(String peerId) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kOneToOne,
      whereArgs: [peerId],
    );
    await _noteGone(db, media);
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE $_kOneToOne AND msg_uid IS NOT NULL)',
      [peerId],
    );
    await db.delete('messages', where: _kOneToOne, whereArgs: [peerId]);
    await _dropFilesComingFrom(db, peerId);
    await _scrubMedia(media);
  }

  // [noteGone] false for a group about to go: its delete drops the records
  Future<void> clearGroupConversation(
    String groupId, {
    bool noteGone = true,
  }) async {
    final db = await open();
    final media = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    if (noteGone) await _noteGone(db, media);
    await db.rawDelete(
      'DELETE FROM reactions WHERE msg_uid IN '
      '(SELECT msg_uid FROM messages WHERE group_id = ? AND msg_uid IS NOT NULL)',
      [groupId],
    );
    await db.delete(
      'group_media_owed',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await _dropGroupFiles(db, groupId);
    await db.delete('messages', where: 'group_id = ?', whereArgs: [groupId]);
    await _scrubMedia(media);
  }

  // what a group left by an older version kept, and the paths of its files
  Future<List<String>> dropGroupLeftovers() async {
    final db = await open();
    final rows = await db.transaction(dropGroupLeftoversIn);
    return [
      for (final r in rows)
        for (final k in _kFileCols)
          if ((r[k] as String?)?.isNotEmpty == true) r[k] as String,
    ];
  }

  // an item of an album takes the earliest clock any of the album has, so
  // all of it burns together. gives the clock it took
  Future<int> setMsgBurnAt(String msgUid, int burnAt) async {
    final db = await open();
    return db.transaction((t) async {
      final at = albumItemBurnAt(
        burnAt,
        await _albumClocks(t, msgUid),
        DateTime.now().millisecondsSinceEpoch,
      );
      await t.update(
        'messages',
        {'burn_at': at},
        where: 'msg_uid = ?',
        whereArgs: [msgUid],
      );
      return at;
    });
  }

  // the album [msgUid] is in, as (album, peer, group, direction), or null
  static Future<(String, String, String, String)?> _albumOf(
    DatabaseExecutor t,
    String msgUid,
  ) async {
    final r = await t.query(
      'messages',
      columns: ['album_id', 'peer_id', 'group_id', 'direction'],
      where: 'msg_uid = ? AND album_id IS NOT NULL',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (
      r.first['album_id'] as String,
      r.first['peer_id'] as String,
      (r.first['group_id'] as String?) ?? '',
      r.first['direction'] as String,
    );
  }

  static const _albumMates =
      "album_id = ? AND peer_id = ? AND IFNULL(group_id, '') = ? "
      'AND direction = ? AND msg_uid IS NOT NULL AND msg_uid != ?';

  // the clocks running on the other items of [msgUid]'s album
  static Future<List<int?>> _albumClocks(
    DatabaseExecutor t,
    String msgUid,
  ) async {
    final a = await _albumOf(t, msgUid);
    if (a == null) return const [];
    final (album, peer, group, dir) = a;
    final rows = await t.query(
      'messages',
      columns: ['burn_at'],
      where: '$_albumMates AND burn_at IS NOT NULL AND burn_unseen = 0',
      whereArgs: [album, peer, group, dir, msgUid],
    );
    return [for (final r in rows) (r['burn_at'] as num?)?.toInt()];
  }

  // delete messages whose burn_at is past, and what waited unread past a
  // day and its window. called by the periodic sweep started in boot().
  // [gone] hears each one that came in. [blocked] gives everyone blocked
  // on this side, the open vault's list with the everyday one's, so a
  // block made in one starts the other's clocks; this container's own
  // list when null. [ifOpen]: one shut is left shut, and 0
  Future<int> purgeExpired({
    void Function(String msgUid)? gone,
    Future<Set<String>> Function()? blocked,
    bool ifOpen = false,
    bool Function(String chatId, bool group)? draftOnScreen,
    void Function(HaloContainer c, String chatId, bool group)? draftGone,
  }) async {
    // an open one is handed back at once, and nothing below opens it again
    final db = ifOpen && !isOpen ? null : await open();
    if (db == null) return 0;
    await _lightStrandedOnce(db);
    final cut = DateTime.now().millisecondsSinceEpoch;
    final due = await db.query(
      'messages',
      columns: [..._kFileCols, ..._kUnreadCols, ..._kGoneCols],
      where: _kBurnDue,
      whereArgs: [cut],
    );
    final idle = await _idle(db, [
      ..._kFileCols,
      ..._kUnreadCols,
      ..._kGoneCols,
    ]);
    // after what waits is read: nothing in it was filed past this now
    final now = DateTime.now().millisecondsSinceEpoch;
    final waited = [
      for (final r in idle)
        if (_waitedOut(r, now)) r,
    ];
    final media = [...due, ...waited];
    await _unreadGo(db, media);
    await _noteGone(db, media, burned: true);
    await db.delete(
      'gone_in',
      where: 'at < ?',
      whereArgs: [now - HaloDb.kGoneFor.inMilliseconds],
    );
    if (gone != null) {
      for (final r in media) {
        final uid = r['msg_uid'] as String?;
        if (uid != null && r['direction'] == 'in') gone(uid);
      }
    }
    var n = await db.delete('messages', where: _kBurnDue, whereArgs: [cut]);
    n += await _dropRows(db, waited);
    await _scrubMedia(media);
    await _lightWaited(db, now, idle, blocked);
    // a timed chat's draft goes on the same clock as its messages
    try {
      await sweepDrafts(
        this as DraftRows,
        onScreen: draftOnScreen,
        gone: draftGone,
        spent: await spentDraftsIn(db, now),
      );
    } catch (e) {
      dlog('drafts: not swept (${e.runtimeType})');
    }
    return n;
  }

  // a chat put away takes the files still coming in it: their slices, and
  // the asks for the rest that would tell its person to send them again
  Future<void> _dropFilesComingFrom(DatabaseExecutor t, String peerId) async {
    await t.rawDelete(
      'DELETE FROM media_chunks WHERE media_id IN '
      '(SELECT media_id FROM media_wants WHERE peer_id = ?)',
      [peerId],
    );
    await t.delete('media_wants', where: 'peer_id = ?', whereArgs: [peerId]);
    // and the ones of this chat still to come from the files service, noted
    // gone so a frame sent again stays out. what came of them is in the
    // fetch folder, which the start sweep empties of what no fetch names.
    // the person's files in a group are the group's
    final coming = await t.query(
      'file_fetches',
      columns: const ['msg_uid'],
      where: 'sender = ? AND group_id IS NULL',
      whereArgs: [peerId],
    );
    await _noteGone(t, [
      for (final r in coming)
        {'msg_uid': r['msg_uid'], 'peer_id': peerId, 'direction': 'in'},
    ]);
    await t.delete(
      'file_fetches',
      where: 'sender = ? AND group_id IS NULL',
      whereArgs: [peerId],
    );
    // weighed again from what is left
    _unfinished = null;
    // nothing more comes for them, so the banner would stay paused for a day
    incomingMediaDone(container.chatKey(peerId));
  }

  // a group gone or cleared takes the files still coming in it. slices
  // kept before the group was noted on them go too where they can be told:
  // left by a message of the group, or sent by a room's member keys, which
  // are the room's own. run before the group's messages go
  Future<void> _dropGroupFiles(
    DatabaseExecutor t,
    String groupId, {
    Iterable<String> keys = const [],
  }) async {
    final coming = await t.query(
      'file_fetches',
      columns: const ['msg_uid', 'sender'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await _noteGone(t, [
      for (final r in coming)
        {
          'msg_uid': r['msg_uid'],
          'peer_id': r['sender'],
          'group_id': groupId,
          'direction': 'in',
        },
    ]);
    await t.delete('file_fetches', where: 'group_id = ?', whereArgs: [groupId]);
    var n = await t.delete(
      'media_chunks',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    final uids = [
      for (final r in await t.query(
        'messages',
        columns: ['msg_uid'],
        where: 'group_id = ? AND msg_uid IS NOT NULL',
        whereArgs: [groupId],
      ))
        r['msg_uid'] as String,
    ];
    for (final (col, ids) in [
      ('media_id', uids),
      ('sender', keys.toSet().toList()),
    ]) {
      for (var i = 0; i < ids.length; i += 400) {
        final part = ids.sublist(i, min(i + 400, ids.length));
        n += await t.delete(
          'media_chunks',
          where:
              'group_id IS NULL AND '
              '$col IN (${List.filled(part.length, '?').join(', ')})',
          whereArgs: part,
        );
      }
    }
    if (n == 0) return;
    // weighed again from what is left
    _unfinished = null;
    incomingMediaDone(container.chatKey(groupId));
  }

  // the clock of a timed message of ours that went, started now if nothing
  // started it yet. null for a message with no timer
  Future<int?> lightBurn(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['burn_secs', 'burn_at'],
      where: 'msg_uid = ? AND direction = ?',
      whereArgs: [msgUid, 'out'],
      limit: 1,
    );
    if (r.isEmpty) return null;
    final lit = (r.first['burn_at'] as num?)?.toInt();
    final secs = (r.first['burn_secs'] as num?)?.toInt();
    if (lit != null || secs == null) return lit;
    final at = DateTime.now().millisecondsSinceEpoch + secs * 1000;
    await db.update(
      'messages',
      {'burn_at': at},
      where: 'msg_uid = ? AND direction = ? AND burn_at IS NULL',
      whereArgs: [msgUid, 'out'],
    );
    return at;
  }

  // timed messages that came in, read just now: each clock starts here,
  // written before the screen counts it down, or a day after it came if
  // that is sooner (kBurnWaitMost). a row lit already keeps its time, and
  // one whose clock started unread keeps the earlier of the two. what came
  // in before them in the same chat has been read as well, scrolled past
  // or not, and starts with them, as the unread count clears for all of
  // it. gives the burn time of every row lit
  Future<Map<String, int>> lightReadBurns(List<String> msgUids) async {
    if (msgUids.isEmpty) return const {};
    final db = await open();
    final marks = List.filled(msgUids.length, '?').join(', ');
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <String, int>{};
    const cols = [
      'id',
      'msg_uid',
      'peer_id',
      'group_id',
      'sent_at',
      'written_at',
      'burn_secs',
      'burn_at',
      'burn_unseen',
    ];
    await db.transaction((t) async {
      final rows = await t.query(
        'messages',
        columns: cols,
        where: "msg_uid IN ($marks) AND direction = 'in'",
        whereArgs: msgUids,
      );
      // the newest row read in each chat, by when it was written and as it
      // came: a row older both ways was above it when it was read
      final newest = <(String, String?), (int, int)>{};
      Future<void> lightRow(Map<String, Object?> r) async {
        final uid = r['msg_uid'] as String?;
        final lit = (r['burn_at'] as num?)?.toInt();
        final secs = (r['burn_secs'] as num?)?.toInt();
        if (lit != null && (r['burn_unseen'] != 1 || secs == null)) {
          if (uid != null) out[uid] = lit;
          return;
        }
        if (secs == null) return;
        final sent = (r['sent_at'] as num?)?.toInt() ?? now;
        final from = min(now, burnStartBy(sent, now));
        var at = min(lit ?? from + secs * 1000, from + secs * 1000);
        // an album is read as one and burns as one
        if (uid != null) {
          at = albumItemBurnAt(at, await _albumClocks(t, uid), now);
        }
        await t.update(
          'messages',
          {'burn_at': at, 'burn_unseen': 0},
          where: lit == null
              ? 'id = ? AND burn_at IS NULL'
              : 'id = ? AND burn_unseen = 1',
          whereArgs: [r['id']],
        );
        if (uid == null) return;
        out[uid] = at;
        final a = await _albumOf(t, uid);
        if (a == null) return;
        final (album, peer, group, dir) = a;
        const behind =
            'burn_secs IS NOT NULL '
            'AND (burn_at IS NULL OR burn_at > ? OR burn_unseen = 1)';
        final mates = await t.query(
          'messages',
          columns: ['msg_uid'],
          where: '$_albumMates AND $behind',
          whereArgs: [album, peer, group, dir, uid, at],
        );
        if (mates.isEmpty) return;
        await t.update(
          'messages',
          {'burn_at': at, 'burn_unseen': 0},
          where: '$_albumMates AND $behind',
          whereArgs: [album, peer, group, dir, uid, at],
        );
        for (final m in mates) {
          out[m['msg_uid'] as String] = at;
        }
      }

      for (final r in rows) {
        await lightRow(r);
        final g = r['group_id'] as String?;
        final chat = (g == null || g.isEmpty)
            ? (r['peer_id'] as String, null)
            : ('', g);
        final (w0, id0) = newest[chat] ?? (-1, -1);
        newest[chat] = (
          max(w0, rowWrittenAt(r)),
          max(id0, (r['id'] as num).toInt()),
        );
      }
      for (final MapEntry(key: (peer, group), value: (w, id))
          in newest.entries) {
        final chat = group == null
            ? 'peer_id = ? AND group_id IS NULL'
            : 'group_id = ?';
        // waiting, or counting since before anyone read it
        for (final unread in const ['burn_at IS NULL', 'burn_unseen = 1']) {
          final older = await t.query(
            'messages',
            columns: cols,
            where:
                "$chat AND direction = 'in' AND burn_secs IS NOT NULL"
                ' AND $unread',
            whereArgs: [group ?? peer],
          );
          for (final r in older) {
            if (rowWrittenAt(r) <= w && (r['id'] as num).toInt() <= id) {
              await lightRow(r);
            }
          }
        }
      }
    });
    return out;
  }
}

// every column that names a file of a message: a photo, or a voice note,
// a video or any other file
const _kFileCols = ['media_path', 'file_path'];

// a person's own chat: what they wrote in groups is the groups'
const _kOneToOne = 'peer_id = ? AND group_id IS NULL';

// a group_members row of a group still running
const _kRunningGroup =
    ' AND group_id NOT IN (SELECT group_id FROM groups '
    'WHERE ended_at IS NOT NULL)';

// what a row needs for _unreadGo to place it
const _kUnreadCols = ['id', 'peer_id', 'group_id', 'direction'];

// and for _noteGone, with those
const _kGoneCols = ['msg_uid', 'sent_at', 'album_id'];

// the rows of these that came in, kept by uid as they go: a 1:1 one by
// its sender, a group's or a room's by its group and sender (goneKey).
// only what a resend or the relays could still bring: sent within
// kGoneFor and a day for clocks
Future<void> _noteGone(
  DatabaseExecutor db,
  Iterable<Map<String, Object?>> rows, {
  // burned on its timer: its album takes nothing after it. a delete or a
  // clear by hand leaves later items to show and ring as their own
  bool burned = false,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final from =
      now -
      HaloDb.kGoneFor.inMilliseconds -
      const Duration(days: 1).inMilliseconds;
  // one commit for all of them: a busy group cleared is thousands
  final b = db.batch();
  var any = false;
  for (final r in rows) {
    final uid = r['msg_uid'] as String?;
    final peer = r['peer_id'] as String?;
    final group = r['group_id'] as String?;
    final sent = (r['sent_at'] as num?)?.toInt();
    if (uid == null || peer == null || r['direction'] != 'in') continue;
    if (sent != null && sent < from) continue;
    if (!goneKept(group)) continue;
    b.insert('gone_in', {
      'msg_uid': uid,
      'peer_id': goneKey(peer, group: group),
      'at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    // an album that burned takes nothing that comes after (albumGone)
    if (r['album_id'] case final String album when burned) {
      b.insert('gone_in', {
        'msg_uid': albumGoneUid(album),
        'peer_id': goneKey(peer, group: group),
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    any = true;
  }
  if (any) await b.commit(noResult: true);
}

// the rows of groups no longer here, which a leave in an older version
// kept: nothing opens them, yet their files sat in the outbox. gives back
// the file columns of what went, for shredding
Future<List<Map<String, Object?>>> dropGroupLeftoversIn(
  DatabaseExecutor db,
) async {
  const gone =
      "group_id IS NOT NULL AND group_id != '' "
      'AND (group_id NOT IN (SELECT group_id FROM groups) '
      'OR group_id IN (SELECT group_id FROM groups WHERE ended_at IS NOT NULL))';
  final files = await db.rawQuery(
    'SELECT media_path, file_path FROM messages WHERE $gone',
  );
  await db.rawDelete(
    'DELETE FROM reactions WHERE msg_uid IN '
    '(SELECT msg_uid FROM messages WHERE $gone AND msg_uid IS NOT NULL)',
  );
  await db.rawDelete('DELETE FROM messages WHERE $gone');
  return files;
}

/// what a message that came in and went is kept under in gone_in: its
/// sender, or in a group its group and sender. a hidden group's rows move
/// with it, and one member's word never stands for another's
String goneKey(String sender, {String? group}) =>
    group == null ? sender : 'group:$group:$sender';

/// the gone_in rows of [group]: its own, every sender's
String goneGroupPrefix(String group) => 'group:$group:';

/// whether what of [group] went is written down. an id with a ':' in it
/// could read as another group's start, so its records stay in memory
bool goneKept(String? group) => group == null || !group.contains(':');
