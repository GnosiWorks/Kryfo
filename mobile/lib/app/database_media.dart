// SPDX-License-Identifier: GPL-3.0-or-later
// files coming in slice by slice

part of '../main.dart';

mixin _MediaRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();

  // ---- chunked media ----
  // buffered on disk so a restart doesn't lose a transfer

  // store one slice from [from], return how many of this media's slices we
  // now hold. [group] is the group the file is posted in
  Future<int> putMediaChunk(
    String mediaId,
    int idx,
    String slice,
    int total,
    int? burn, {
    required String from,
    String? group,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    // a file sent again in another number of slices is other bytes, a photo
    // cleaned since say: what was held of it no longer fits
    final stale = await db.delete(
      'media_chunks',
      where: 'media_id = ? AND total != ?',
      whereArgs: [mediaId, total],
    );
    if (stale > 0 && _unfinished != null) await _reweigh(mediaId);
    // a slice sent again replaces the one held, and weighs only once
    final held = _unfinished;
    final was = held == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'media_chunks',
            columns: ['length(slice) AS n'],
            where: 'media_id = ? AND idx = ?',
            whereArgs: [mediaId, idx],
            limit: 1,
          );
    await db.rawInsert(
      'INSERT OR REPLACE INTO media_chunks '
      '(media_id, idx, slice, total, burn, at, sender, group_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [mediaId, idx, slice, total, burn, now, from, group],
    );
    if (held != null && identical(held, _unfinished)) {
      final old = was.isEmpty
          ? 0
          : sliceWeight((was.first['n'] as num? ?? 0).toInt());
      final f = held[mediaId];
      held[mediaId] = (
        bytes: (f?.bytes ?? 0) + sliceWeight(slice.length) - old,
        at: now,
      );
    }
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM media_chunks WHERE media_id = ?',
      [mediaId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // burn window rides the slices so it survives a restart too.
  Future<int?> mediaChunkBurn(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['burn'],
      where: 'media_id = ? AND burn IS NOT NULL',
      whereArgs: [mediaId],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return r.first['burn'] as int?;
  }

  // one slice, so a file is rebuilt piece by piece instead of all its
  // slices sitting in one list
  Future<String?> mediaChunkSlice(String mediaId, int idx) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['slice'],
      where: 'media_id = ? AND idx = ?',
      whereArgs: [mediaId, idx],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['slice'] as String?;
  }

  // a file's slices, or with [from] only the ones that sender sent
  Future<int> dropMediaChunks(String mediaId, {String? from}) async {
    final db = await open();
    final n = await db.delete(
      'media_chunks',
      where: from == null ? 'media_id = ?' : 'media_id = ? AND sender = ?',
      whereArgs: [mediaId, ?from],
    );
    if (n > 0 && _unfinished != null) await _reweigh(mediaId);
    return n;
  }

  // the unfinished files here, each with what its slices weigh and when its
  // last slice came. read whole the first time it is needed, then kept up
  // as slices come and go
  Map<String, ({int bytes, int at})>? _unfinished;

  Future<Map<String, ({int bytes, int at})>> _unfinishedFiles() async {
    final have = _unfinished;
    if (have != null) return have;
    final db = await open();
    final rows = await db.query(
      'media_chunks',
      columns: ['media_id', 'length(slice) AS n', 'at'],
    );
    final out = <String, ({int bytes, int at})>{};
    for (final r in rows) {
      final id = r['media_id'] as String;
      final at = (r['at'] as num).toInt();
      final f = out[id];
      out[id] = (
        bytes: (f?.bytes ?? 0) + sliceWeight((r['n'] as num? ?? 0).toInt()),
        at: f == null || at > f.at ? at : f.at,
      );
    }
    return _unfinished = out;
  }

  // one file's entry read again from what is left of it
  Future<void> _reweigh(String mediaId) async {
    final db = await open();
    final rows = await db.query(
      'media_chunks',
      columns: ['length(slice) AS n', 'at'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    final held = _unfinished;
    if (held == null) return;
    if (rows.isEmpty) {
      held.remove(mediaId);
      return;
    }
    var bytes = 0;
    var at = 0;
    for (final r in rows) {
      bytes += sliceWeight((r['n'] as num? ?? 0).toInt());
      final t = (r['at'] as num).toInt();
      if (t > at) at = t;
    }
    held[mediaId] = (bytes: bytes, at: at);
  }

  // unfinished files past the cap go, whole, the one whose last slice came
  // longest ago first. a file in [keep] is being put together and stays;
  // finished messages are never touched. the files that went
  Future<Set<String>> trimUnfinishedMedia({
    Set<String> keep = const {},
    int bytes = kUnfinishedBytes,
    int files = kUnfinishedFiles,
  }) async {
    final held = await _unfinishedFiles();
    final drop = unfinishedPastCap(
      held,
      bytes: bytes,
      files: files,
      keep: keep,
    );
    if (drop.isEmpty) return const <String>{};
    final db = await open();
    final gone = <String>{};
    for (final id in drop) {
      // one that began to be put together meanwhile stays
      if (keep.contains(id)) continue;
      await db.delete('media_chunks', where: 'media_id = ?', whereArgs: [id]);
      await dropMediaWant(id);
      _unfinished?.remove(id);
      gone.add(id);
    }
    dlog('unfinished files past the cap: ${gone.length} dropped');
    return gone;
  }

  // who sent the slices held for a file, null for none or for slices kept
  // before senders were noted
  Future<String?> mediaChunkSender(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['sender'],
      where: 'media_id = ? AND sender IS NOT NULL',
      whereArgs: [mediaId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['sender'] as String?;
  }

  // how many unfinished files [from] is sending in their own chat, [except]
  // not counted. only those have a want row: a file they post in a group
  // counts for the group, not against their chat
  Future<int> filesInFlightFrom(String from, {String? except}) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      distinct: true,
      columns: ['media_id'],
      where: 'sender = ?',
      whereArgs: [from],
    );
    final direct = {
      for (final w in await db.query(
        'media_wants',
        columns: ['media_id'],
        where: 'peer_id = ?',
        whereArgs: [from],
      ))
        w['media_id'],
    };
    final sliced = r
        .where((x) => x['media_id'] != except && direct.contains(x['media_id']))
        .length;
    // and the ones still to come from the files service
    return sliced + await fetchesFrom(db, from, except: except);
  }

  // a slice of an unfinished file just came in. can_resend only ever goes
  // up: one slice from a sender that can answer is enough to know it can.
  // the count of slices is the latest one's, as with the slices held
  Future<void> noteMediaWant(
    String mediaId,
    String peerId,
    int total,
    bool canResend,
  ) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      'INSERT INTO media_wants (media_id, peer_id, total, can_resend, last_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(media_id) DO UPDATE SET last_at = excluded.last_at, '
      'total = excluded.total, '
      'can_resend = MAX(can_resend, excluded.can_resend)',
      [mediaId, peerId, total, canResend ? 1 : 0, now],
    );
  }

  Future<List<Map<String, Object?>>> mediaWants() async {
    final db = await open();
    return db.query('media_wants', where: 'can_resend = 1');
  }

  Future<Set<int>> heldSlices(String mediaId) async {
    final db = await open();
    final r = await db.query(
      'media_chunks',
      columns: ['idx'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    return {for (final row in r) (row['idx'] as num).toInt()};
  }

  // [at] is the time the ask was decided on, stamped before it goes. read
  // and written in one go, so a slice landing meanwhile is not missed
  Future<void> markMediaAsked(String mediaId, int at) async {
    final db = await open();
    await db.transaction((t) async {
      final r = await t.query(
        'media_wants',
        columns: ['last_at', 'asked_at', 'asks'],
        where: 'media_id = ?',
        whereArgs: [mediaId],
        limit: 1,
      );
      if (r.isEmpty) return;
      final w = r.first;
      await t.update(
        'media_wants',
        {
          'asked_at': at,
          'asks': asksAfterAsk(
            lastSliceAt: (w['last_at'] as num).toInt(),
            askedAt: (w['asked_at'] as num).toInt(),
            asks: (w['asks'] as num).toInt(),
          ),
        },
        where: 'media_id = ?',
        whereArgs: [mediaId],
      );
    });
  }

  Future<void> dropMediaWant(String mediaId) async {
    final db = await open();
    await db.delete('media_wants', where: 'media_id = ?', whereArgs: [mediaId]);
  }

  // what a request for slices is checked against and answered from
  Future<Map<String, Object?>?> sentMediaRow(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  /// where an incoming row's file goes: its file's path, or its picture's.
  /// null when the row is gone or names none
  Future<String?> incomingFilePath(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: const ['file_path', 'media_path'],
      where: "msg_uid = ? AND direction = 'in'",
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (r.first['file_path'] ?? r.first['media_path']) as String?;
  }

  /// an incoming row filed before its file, whose file will not come now:
  /// its paths go and it says so under what it said. false when it is gone
  Future<bool> fileNeverCame(String msgUid, String line) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: const ['plaintext'],
      where: "msg_uid = ? AND direction = 'in'",
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return false;
    final said = (r.first['plaintext'] as String?) ?? '';
    await db.update(
      'messages',
      {
        'plaintext': [said, line].where((s) => s.trim().isNotEmpty).join('\n'),
        'media_path': null,
        'file_path': null,
      },
      where: "msg_uid = ? AND direction = 'in'",
      whereArgs: [msgUid],
    );
    return true;
  }

  // a transfer nobody ever finished shouldn't sit in the db forever.
  // a week for a file from someone here, a day for one from a stranger:
  // someone not accepted and in no group
  Future<void> sweepMediaChunks({DateTime? now}) async {
    final db = await open();
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final cutoff = at - const Duration(days: 7).inMilliseconds;
    final strangers = at - const Duration(days: 1).inMilliseconds;
    var n = await db.delete(
      'media_chunks',
      where: 'at < ?',
      whereArgs: [cutoff],
    );
    final old = await db.query(
      'media_chunks',
      distinct: true,
      columns: ['media_id', 'sender'],
      where: 'at < ? AND sender IS NOT NULL',
      whereArgs: [strangers],
    );
    final known = <String, bool>{};
    for (final r in old) {
      final mid = r['media_id'] as String;
      final from = r['sender'] as String;
      if (known[from] ??= await _heldHere(from)) continue;
      n += await dropMediaChunks(mid, from: from);
      await dropMediaWant(mid);
    }
    if (n > 0) dlog('swept $n stale media chunks');
    await db.delete('media_wants', where: 'last_at < ?', whereArgs: [cutoff]);
    // counted again from what is left, and held to the cap
    _unfinished = null;
    await trimUnfinishedMedia();
  }

  // an accepted contact, or a member of a group here
  Future<bool> _heldHere(String id) async {
    final db = await open();
    final c = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'halo_id = ? AND accepted = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    if (c.isNotEmpty) return true;
    final g = await db.query(
      'group_members',
      columns: ['group_id'],
      where: 'halo_id = ?$_kRunningGroup',
      whereArgs: [id],
      limit: 1,
    );
    return g.isNotEmpty;
  }
}
