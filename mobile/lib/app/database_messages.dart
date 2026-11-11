// SPDX-License-Identifier: GPL-3.0-or-later
// messages saved, and read back in a chat's order

part of '../main.dart';

mixin _MessageRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();

  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    // when it came, if not now: an arrival opened from the seal
    int? sentAt,
    // when it was written, held to what can be true (writtenAtOf). when it
    // came if not given: ours are written as they go
    int? writtenAt,
    // a contact's, through the developer chat (viaDevChat)
    bool viaDev = false,
    // its place in an album
    AlbumTag? album,
    // a photo blurred until it is tapped
    bool spoiler = false,
  }) async {
    final db = await open();
    final came = sentAt ?? DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      // your own words too (a pasted caption, a forward): no direction
      // controls reach the screen from here (bidi_safe.dart)
      'plaintext': unmarked(plaintext),
      'sent_at': came,
      'written_at': writtenAt ?? came,
      'burn_at': burnAt,
      'burn_secs': burnSecs,
      // came in with its window and its clock already running: nobody read
      // it, it waited too long (kBurnWaitMost)
      if (direction == 'in' && burnSecs != null && burnAt != null)
        'burn_unseen': 1,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'group_id': groupId,
      'media_path': mediaPath,
      'file_path': filePath,
      'file_name': fileName == null ? null : unmarked(fileName),
      'voice_disguised': voiceDisguised ? 1 : 0,
      'preview': preview,
      'saved': saved ? 1 : 0,
      'sent': sent,
      'secure': secure ? 1 : 0,
      'poll': ?poll,
      'sticker': ?sticker,
      if (viaDev) 'via_dev': 1,
      if (spoiler) 'spoiler': 1,
      ...?album?.toRow(),
    });
    try {
      await indexSearchRow(db, id, {
        'plaintext': plaintext,
        'poll': poll,
        'file_name': fileName,
        'preview': preview,
        'sticker': sticker,
      });
    } catch (e) {
      // a message is never lost to its index; the fill catches it up
      dlog('search: not indexed now: $e');
    }
    // any inbound message proves the peer knows us, so flip back_paired.
    // subsequent sends to them can use nostr safely.
    if (direction == 'in') {
      await db.update(
        'contacts',
        {'back_paired': 1},
        where: 'halo_id = ?',
        whereArgs: [peerId],
      );
    }
    // a word from them, or one to them that carries the accept with it:
    // the line saying they may not know goes
    if (groupId == null || groupId.isEmpty) {
      await db.update(
        'contacts',
        {'ack_owed': 0},
        where: 'halo_id = ? AND ack_owed = 2',
        whereArgs: [peerId],
      );
    }
  }

  /// a file of this phone's own in the chat with [peerId], kept in the
  /// same go as a look that the chat is still here: one deleted, or hidden
  /// away while it was made, keeps nothing. [wasAccepted] is what the chat
  /// was when the send began. false then
  Future<bool> saveInChat(
    String peerId, {
    required String msgUid,
    required bool wasAccepted,
    required int writtenAt,
    String? replyTo,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    int? burnAt,
    int? burnSecs,
    int sent = 0,
  }) async {
    final db = await open();
    final id = await db.transaction((t) async {
      final c = await t.query(
        'contacts',
        columns: ['accepted', 'archived'],
        where: 'halo_id = ?',
        whereArgs: [peerId],
        limit: 1,
      );
      if (c.isEmpty) return null;
      final accepted = c.first['accepted'] == 1;
      // a deleted chat is parked: unaccepted and archived. a hidden one
      // leaves at most a key here, unaccepted
      if (!accepted && (wasAccepted || c.first['archived'] == 1)) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      return t.insert('messages', {
        'peer_id': peerId,
        'direction': 'out',
        'plaintext': '',
        'sent_at': now,
        'written_at': writtenAt,
        'burn_at': burnAt,
        'burn_secs': burnSecs,
        'msg_uid': msgUid,
        'reply_to': replyTo,
        'file_path': filePath,
        'file_name': fileName == null ? null : unmarked(fileName),
        'voice_disguised': voiceDisguised ? 1 : 0,
        'saved': 0,
        'sent': sent,
        'secure': 0,
      });
    });
    if (id == null) return false;
    try {
      await indexSearchRow(db, id, {'plaintext': '', 'file_name': fileName});
    } catch (e) {
      dlog('search: not indexed now: $e');
    }
    return true;
  }

  /// a row of this phone's own in group [groupId], kept in the same go as
  /// a look that the group is still here: one that ended, was left or was
  /// taken out of keeps nothing. false then
  Future<bool> saveInGroup(
    String peerId,
    String plaintext, {
    required String groupId,
    required String msgUid,
    int? burnSecs,
    String? replyTo,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    int sent = 0,
    String? preview,
    String? poll,
    String? sticker,
    AlbumTag? album,
    bool spoiler = false,
    // when it was begun, if not now: a bubble shown before it was saved
    int? writtenAt,
  }) async {
    final db = await open();
    final id = await db.transaction((t) async {
      final there = await t.query(
        'groups',
        columns: ['group_id'],
        where: 'group_id = ? AND ended_at IS NULL',
        whereArgs: [groupId],
        limit: 1,
      );
      if (there.isEmpty) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      return t.insert('messages', {
        'peer_id': peerId,
        'direction': 'out',
        'plaintext': unmarked(plaintext),
        'sent_at': now,
        'written_at': writtenAt ?? now,
        'burn_secs': burnSecs,
        'msg_uid': msgUid,
        'reply_to': replyTo,
        'group_id': groupId,
        'media_path': mediaPath,
        'file_path': filePath,
        'file_name': fileName == null ? null : unmarked(fileName),
        'voice_disguised': voiceDisguised ? 1 : 0,
        'preview': preview,
        'saved': 0,
        'sent': sent,
        'secure': 0,
        'poll': ?poll,
        'sticker': ?sticker,
        if (spoiler) 'spoiler': 1,
        ...?album?.toRow(),
      });
    });
    if (id == null) return false;
    try {
      await indexSearchRow(db, id, {
        'plaintext': plaintext,
        'poll': poll,
        'file_name': fileName,
        'preview': preview,
        'sticker': sticker,
      });
    } catch (e) {
      dlog('search: not indexed now: $e');
    }
    return true;
  }

  // the same message can come via tor and nostr, plus retries. a duplicate
  // crashes on the used-up prekey, so it is dropped before any decrypt.
  Future<bool> alreadySeen(String hash) async {
    final db = await open();
    final rows = await db.query(
      'seen_msgs',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markSeen(String hash) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // prune anything older than a day so the table stays tiny
    await db.delete('seen_msgs', where: 'ts < ?', whereArgs: [now - 86400000]);
  }

  // like markSeen but stamped a month ahead of the daily prune: a pruned
  // hash of an undecryptable cipher replays the bad mac the next day. relays
  // age the events out well before the month is up.
  Future<void> markSeenLong(String hash) async {
    final db = await open();
    await db.insert('seen_msgs', {
      'hash': hash,
      'ts': DateTime.now().millisecondsSinceEpoch + 30 * 86400000,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // a msg_uid for a row from before the v5 migration, so it can take
  // reactions. (peer_id, sent_at) is unique enough in practice.
  Future<void> assignUidIfMissing(
    String peerId,
    int sentAtMs,
    String uid,
  ) async {
    final db = await open();
    await db.update(
      'messages',
      {'msg_uid': uid},
      where: 'peer_id = ? AND sent_at = ? AND msg_uid IS NULL',
      whereArgs: [peerId, sentAtMs],
    );
  }

  // a chat's order (msg_order.dart): by when each was written, then as
  // they came. before and from name a row by its time and id
  static const _kOldestFirst = 'written_at ASC, id ASC';
  static const _kNewestFirst = 'written_at DESC, id DESC';
  static const _kBefore = '(written_at < ? OR (written_at = ? AND id < ?))';
  static const _kFrom = '(written_at > ? OR (written_at = ? AND id >= ?))';

  // the args for _kBefore or _kFrom at row [id]. its own time when [at] is
  // not given, null when that row is gone
  static Future<List<Object>?> _at(Database db, int id, int? at) async {
    if (at != null) return [at, at, id];
    final r = await db.query(
      'messages',
      columns: ['written_at'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final w = r.isEmpty ? null : (r.first['written_at'] as num?)?.toInt();
    return w == null ? null : [w, w, id];
  }

  // peer_id on each row is the sender's kryfo id, ours on our own messages
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: _kOldestFirst,
    );
  }

  // the newest page of a group, or the one before row [beforeRowid],
  // written at [beforeAt]
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    final db = await open();
    final at = beforeRowid == null
        ? null
        : await _at(db, beforeRowid, beforeAt);
    if (beforeRowid != null && at == null) return [];
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: at == null ? 'group_id = ?' : 'group_id = ? AND $_kBefore',
      whereArgs: [groupId, ...?at],
      orderBy: _kNewestFirst,
      limit: limit,
    );
    return rows.reversed.toList();
  }

  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: 'group_id = ? AND rowid > ?',
      whereArgs: [groupId, afterRowid],
      orderBy: 'sent_at ASC',
    );
  }

  // the chat a row lives in: (peer_id, group_id), or null when there is no
  // such row
  Future<(String, String?)?> chatOf(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['peer_id', 'group_id'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (r.first['peer_id'] as String, r.first['group_id'] as String?);
  }

  Future<void> setPinned(String msgUid, bool pinned, {int? at}) async {
    final db = await open();
    await db.update(
      'messages',
      {
        'pinned': pinned ? 1 : 0,
        'pinned_at': pinned
            ? at ?? DateTime.now().millisecondsSinceEpoch
            : null,
      },
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // every pin in one chat, newest pin first, whatever part of the thread
  // the screen has loaded. a 1:1 chat by the other person's id, a group by
  // its own.
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async {
    final db = await open();
    return db.query(
      'messages',
      columns: [
        'msg_uid',
        'peer_id',
        'direction',
        'plaintext',
        'sent_at',
        'written_at',
        'media_path',
        'file_name',
        'pinned_at',
        'sticker',
        // what says it waits to be read (burnWaitsRow)
        'burn_secs',
        'burn_at',
        'burn_unseen',
      ],
      where: groupId != null
          ? 'pinned = 1 AND msg_uid IS NOT NULL AND group_id = ?'
          : "pinned = 1 AND msg_uid IS NOT NULL AND peer_id = ? "
                "AND (group_id IS NULL OR group_id = '')",
      whereArgs: [groupId ?? peerId],
      orderBy: 'COALESCE(pinned_at, written_at) DESC',
    );
  }

  Future<void> setSaved(String msgUid, bool saved) async {
    final db = await open();
    await db.update(
      'messages',
      {'saved': saved ? 1 : 0},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  // every saved message across all chats, newest first. peer_id rides along
  // so the saved screen can show who it's from.
  // a timed message not read yet is left out: it shows in its own chat
  // alone, where reading it starts its clock
  Future<List<Map<String, Object?>>> savedMessages() async {
    final db = await open();
    final rows = await db.query(
      'messages',
      where: 'saved = 1',
      orderBy: _kNewestFirst,
      limit: 500,
    );
    return [
      for (final r in rows)
        if (!burnWaitsRow(r)) r,
    ];
  }

  /// the sticker on a row, as it goes on the wire
  Future<String?> stickerOf(String uid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sticker'],
      where: 'msg_uid = ? AND sticker IS NOT NULL',
      whereArgs: [uid],
      limit: 1,
    );
    return r.isEmpty ? null : StickerWire.parse(r.first['sticker'])?.value;
  }

  // did this sender write this row. what edit and unsend frames check.
  Future<bool> isTheirs(String msgUid, String sender) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['id'],
      where: "msg_uid = ? AND direction = 'in' AND peer_id = ?",
      whereArgs: [msgUid, sender],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  // [from] keeps a sender's edit on their own row of that uid
  Future<void> editMessage(
    String msgUid,
    String newText, {
    String? from,
  }) async {
    final db = await open();
    final only = from == null ? '' : " AND direction = 'in' AND peer_id = ?";
    final args = [msgUid, ?from];
    // a page title belongs to the link it was fetched for
    final was = await db.query(
      'messages',
      columns: ['plaintext'],
      where: 'msg_uid = ?$only',
      whereArgs: args,
      limit: 1,
    );
    final linkMoved =
        was.isNotEmpty &&
        firstUrl(was.first['plaintext'] as String? ?? '') !=
            firstUrl(unmarked(newText));
    await db.update(
      'messages',
      {
        'plaintext': unmarked(newText),
        'edited': 1,
        if (linkMoved) 'preview': null,
      },
      // a sticker has no words to edit: its text stays its emoji
      where: 'msg_uid = ? AND sticker IS NULL$only',
      whereArgs: args,
    );
    // an opener that goes again goes as it reads now
    await db.update(
      'opener_again',
      {'wire': null},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    // the old words must not find it any more
    final rows = await db.query(
      'messages',
      columns: ['id', 'plaintext', 'poll', 'file_name', 'preview', 'sticker'],
      where: 'msg_uid = ?$only',
      whereArgs: args,
    );
    for (final r in rows) {
      await indexSearchRow(db, r['id'] as int, r);
    }
  }

  // what is here of [sender]'s album [albumId]: its count, the places
  // taken, when its first row was written and when its first row came.
  // null while none is
  Future<({int n, Set<int> taken, int first, int came})?> albumHeld(
    String albumId,
    String sender,
    String? groupId,
  ) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['album_n', 'album_i', 'written_at', 'sent_at'],
      where:
          "album_id = ? AND peer_id = ? AND IFNULL(group_id, '') = ? "
          "AND direction = 'in'",
      whereArgs: [albumId, sender, groupId ?? ''],
    );
    if (rows.isEmpty) return null;
    var first = rowWrittenAt(rows.first);
    var came = (rows.first['sent_at'] as num).toInt();
    for (final r in rows) {
      first = min(first, rowWrittenAt(r));
      came = min(came, (r['sent_at'] as num).toInt());
    }
    return (
      n: (rows.first['album_n'] as num?)?.toInt() ?? 0,
      taken: {for (final r in rows) (r['album_i'] as num?)?.toInt() ?? -1},
      first: first,
      came: came,
    );
  }

  Future<bool> messageExists(String msgUid) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['rowid AS rowid'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // [sender]'s own copy of [msgUid] in that chat, or one of mine: a uid
  // another member's frame took first never hides theirs
  Future<bool> messageFrom(String msgUid, String sender, String? group) async {
    final db = await open();
    for (final (where, args) in [
      ("msg_uid = ? AND direction = 'out'", [msgUid]),
      group == null
          ? (
              'msg_uid = ? AND peer_id = ? AND group_id IS NULL',
              [msgUid, sender],
            )
          : (
              'msg_uid = ? AND peer_id = ? AND group_id = ?',
              [msgUid, sender, group],
            ),
    ]) {
      final rows = await db.query(
        'messages',
        columns: ['rowid AS rowid'],
        where: where,
        whereArgs: args,
        limit: 1,
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  // add or replace a reaction. reactor is '' for self, peer's kryfo id
  // for theirs. one reaction per (msgUid, reactor): re-reacting replaces.
  Future<void> addReaction(
    String msgUid,
    String reactor,
    String emoji, {
    int? at,
  }) async {
    final db = await open();
    await db.insert('reactions', {
      'msg_uid': msgUid,
      'reactor': reactor,
      'emoji': emoji,
      'reacted_at': at ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeReaction(String msgUid, String reactor) async {
    final db = await open();
    await db.delete(
      'reactions',
      where: 'msg_uid = ? AND reactor = ?',
      whereArgs: [msgUid, reactor],
    );
  }

  // load reactions for a batch of messages. returns
  // { msgUid: [ (reactor, emoji), ... ] }.
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async {
    if (msgUids.isEmpty) return {};
    final db = await open();
    final placeholders = List.filled(msgUids.length, '?').join(',');
    final rows = await db.query(
      'reactions',
      columns: ['msg_uid', 'reactor', 'emoji'],
      where: 'msg_uid IN ($placeholders)',
      whereArgs: msgUids,
    );
    final out = <String, List<MapEntry<String, String>>>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      final reactor = r['reactor'] as String;
      final emoji = r['emoji'] as String;
      out.putIfAbsent(uid, () => []).add(MapEntry(reactor, emoji));
    }
    return out;
  }

  // a bare rowid comes back named after the INTEGER PRIMARY KEY (id), so
  // every read here asks for it AS rowid
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    final db = await open();
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      // group_id IS NULL keeps group messages out of the 1:1 thread: a group
      // row carries peer_id = sender too
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: _kOldestFirst,
    );
  }

  // one message of a 1:1 thread by its uid, for a draft quoting one older
  // than the pages a chat holds. none when it is gone, or past its time
  // and only not swept yet
  Future<Map<String, Object?>?> messageIn(String peerId, String msgUid) =>
      _byUid(msgUid, (r) => r['peer_id'] == peerId && r['group_id'] == null);

  // the same in a group
  Future<Map<String, Object?>?> groupMessageIn(String groupId, String msgUid) =>
      _byUid(msgUid, (r) => r['group_id'] == groupId);

  // by msg_uid alone, so its own index is the one read: a group's would
  // walk every row of the group
  Future<Map<String, Object?>?> _byUid(
    String msgUid,
    bool Function(Map<String, Object?> r) ours,
  ) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    for (final r in rows) {
      final burn = (r['burn_at'] as num?)?.toInt();
      if (ours(r) && (burn == null || burn > now)) return r;
    }
    return null;
  }

  // newest page of a 1:1 thread. beforeRowid, written at beforeAt, pages
  // older on scroll-up so a 5000-message chat doesn't parse the world on
  // open.
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    final db = await open();
    final at = beforeRowid == null
        ? null
        : await _at(db, beforeRowid, beforeAt);
    if (beforeRowid != null && at == null) return [];
    final rows = await db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: at == null
          ? 'peer_id = ? AND group_id IS NULL'
          : 'peer_id = ? AND group_id IS NULL AND $_kBefore',
      whereArgs: [peerId, ...?at],
      orderBy: _kNewestFirst,
      limit: limit,
    );
    return rows.reversed.toList();
  }

  // a 1:1 thread from row [rowid], written at [at], to its newest: a
  // reload keeps the pages already scrolled in
  Future<List<Map<String, Object?>>> messagesFrom(
    String peerId, {
    required int rowid,
    int? at,
  }) async {
    final db = await open();
    final from = await _at(db, rowid, at);
    if (from == null) return messagesPage(peerId);
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: 'peer_id = ? AND group_id IS NULL AND $_kFrom',
      whereArgs: [peerId, ...from],
      orderBy: _kOldestFirst,
    );
  }

  // only messages after a rowid, oldest first, for the chat's
  // append-on-receive fast path
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async {
    final db = await open();
    // rowid, not sent_at: clock skew can give a received note a sent_at older
    // than our local newest. rowid always climbs.
    return db.query(
      'messages',
      columns: ['*', 'rowid AS rowid'],
      where: "peer_id = ? AND group_id IS NULL AND rowid > ?",
      whereArgs: [peerId, afterRowid],
      orderBy: 'Rowid ASC',
    );
  }

  // the newest 1:1 row per peer in the chat's order, for the home list,
  // which refreshes after every send. the burn columns say a timed one
  // still waits to be read (burnWaitsRow)
  Future<Map<String, Map<String, Object?>>> lastMessages() async {
    final db = await open();
    final rows = await db.rawQuery('''
      SELECT m.peer_id, m.direction, m.plaintext, m.media_path, m.file_name,
             m.sent_at, m.written_at, m.sticker, m.burn_secs, m.burn_at,
             m.burn_unseen
      FROM messages m
      WHERE m.id IN (
        SELECT (
          SELECT y.id FROM messages y
          WHERE y.peer_id = p.peer_id AND y.group_id IS NULL
          ORDER BY y.written_at DESC, y.id DESC LIMIT 1
        )
        FROM (SELECT DISTINCT peer_id FROM messages WHERE group_id IS NULL) p
      )
    ''');
    return {for (final r in rows) r['peer_id'] as String: r};
  }

  // the newest row per group, for its row on home: who wrote it and what.
  // the same columns as a chat's, with the poll
  Future<Map<String, Map<String, Object?>>> lastGroupMessages() async {
    final db = await open();
    final rows = await db.rawQuery('''
      SELECT m.group_id, m.peer_id, m.direction, m.plaintext, m.media_path,
             m.file_name, m.sent_at, m.written_at, m.sticker, m.burn_secs,
             m.burn_at, m.burn_unseen, m.poll
      FROM messages m
      WHERE m.id IN (
        SELECT (
          SELECT y.id FROM messages y
          WHERE y.group_id = g.group_id
          ORDER BY y.written_at DESC, y.id DESC LIMIT 1
        )
        FROM (SELECT DISTINCT group_id FROM messages
              WHERE group_id IS NOT NULL) g
      )
    ''');
    return {for (final r in rows) r['group_id'] as String: r};
  }

  // what a 1:1 chat shared, newest first: its photos, files, voice notes and
  // messages with a link, with only what the shared lists draw. three narrow
  // queries rather than one pass over every message. a timed one not read
  // yet is left out: it shows in the thread alone, where reading it starts
  // its clock
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async {
    final db = await open();
    const cols = [
      'id',
      'media_path',
      'file_path',
      'file_name',
      'secure',
      'direction',
      'sent_at',
      'msg_uid',
      'plaintext',
      'preview',
      'burn_secs',
      'burn_at',
      'burn_unseen',
      'spoiler',
    ];
    const chat = 'peer_id = ? AND group_id IS NULL';
    final parts = await Future.wait([
      db.query(
        'messages',
        columns: cols,
        where: '$chat AND media_path IS NOT NULL AND media_path != ?',
        whereArgs: [peerId, ''],
      ),
      db.query(
        'messages',
        columns: cols,
        where: '$chat AND file_name IS NOT NULL',
        whereArgs: [peerId],
      ),
      db.query(
        'messages',
        columns: cols,
        where: '$chat AND plaintext LIKE ?',
        whereArgs: [peerId, '%://%'],
      ),
    ]);
    final byId = <int, Map<String, Object?>>{
      for (final part in parts)
        for (final r in part) r['id'] as int: r,
    };
    final ids = byId.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final id in ids)
        if (!burnWaitsRow(byId[id]!)) byId[id]!,
    ];
  }

  /// the files that came or went lately, any chat in this container, the
  /// newest first: what the sending sheet's recent tab offers. voice notes
  /// and pictures sent as photos are not files
  Future<List<Map<String, Object?>>> recentFiles({int limit = 40}) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: const [
        'file_path',
        'file_name',
        'sent_at',
        'direction',
        'peer_id',
        'group_id',
        'secure',
      ],
      // a timed one goes with its timer: it is never offered on
      where:
          "file_path IS NOT NULL AND file_path != '' AND file_name IS NOT NULL "
          'AND burn_secs IS NULL AND burn_at IS NULL',
      orderBy: 'rowid DESC',
      limit: limit * 2,
    );
    return rows;
  }

  // when the first message with a peer was, either way. null before any.
  Future<int?> firstMessageAt(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT MIN(sent_at) t FROM messages '
      'WHERE peer_id = ? AND group_id IS NULL',
      [peerId],
    );
    return r.isEmpty ? null : r.first['t'] as int?;
  }

  /// when [peerId] last wrote anything here, a group's message too: null
  /// when nothing of theirs is held
  Future<int?> lastHeardAt(String peerId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT MAX(sent_at) t FROM messages '
      "WHERE peer_id = ? AND direction = 'in'",
      [peerId],
    );
    return r.isEmpty ? null : r.first['t'] as int?;
  }

  Future<Map<String, Object?>?> lastMessageFor(String peerId) async {
    final db = await open();
    // the newest in the chat's order. group_id IS NULL: a group message is
    // stored under the sender's peer_id too.
    final rows = await db.query(
      'messages',
      where: 'peer_id = ? AND group_id IS NULL',
      whereArgs: [peerId],
      orderBy: _kNewestFirst,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}
