// SPDX-License-Identifier: GPL-3.0-or-later
// what waits to go: unsent rows and queued pins, frames and edits

part of '../main.dart';

mixin _OutboxRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();
  Future<String?> Function(String haloId)? get _keySource;
  Future<List<String>> getGroupMembers(String groupId);

  Future<void> queuePin(String msgUid, String peerId, bool pinned) async {
    final db = await open();
    // one row a message: the latest word replaces the last
    await db.insert('pins_out', {
      'msg_uid': msgUid,
      'peer_id': peerId,
      'pinned': pinned ? 1 : 0,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // the oldest rows whose turn has come: one still waiting out its gap
  // keeps no other out of the window
  Future<List<Map<String, Object?>>> unsentPins({
    Set<String> skip = const {},
    int? now,
  }) async {
    final db = await open();
    final s = skip.toList();
    return db.query(
      'pins_out',
      where: '$kNotBlocked AND next_at < ?${_notIn(s)}',
      whereArgs: [(now ?? DateTime.now().millisecondsSinceEpoch) + 1, ...s],
      orderBy: 'at ASC',
      limit: 40,
    );
  }

  /// a drain's try of a queued pin is starting: counted, and the next one
  /// waits its gap. a newer word queued meanwhile is not touched
  Future<void> triedPin(String msgUid, bool pinned, int tries, int now) =>
      _tried(
        'pins_out',
        'msg_uid = ? AND pinned = ?',
        [msgUid, pinned ? 1 : 0],
        tries,
        now,
      );

  Future<void> _tried(
    String table,
    String where,
    List<Object?> args,
    int tries,
    int now,
  ) async {
    final db = await open();
    await db.update(
      table,
      {'tries': tries + 1, 'next_at': now + queueGap(tries)},
      where: where,
      whereArgs: args,
    );
  }

  // only the word that was sent: a newer one queued meanwhile stays
  Future<void> dropPin(String msgUid, bool pinned) async {
    final db = await open();
    await db.delete(
      'pins_out',
      where: 'msg_uid = ? AND pinned = ?',
      whereArgs: [msgUid, pinned ? 1 : 0],
    );
  }

  Future<void> queueFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      // a message taken back has nothing left to edit, pin or react to
      if (kind == kFrameUnsend) {
        for (final table in const ['edits_out', 'pins_out', 'frames_out']) {
          await t.delete(
            table,
            where: 'msg_uid = ? AND peer_id = ?',
            whereArgs: [msgUid, peerId],
          );
        }
      }
      final at = DateTime.now().millisecondsSinceEpoch;
      await t.insert('frames_out', {
        'msg_uid': msgUid,
        'kind': kind,
        'peer_id': peerId,
        'body': body,
        'at': at,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // kept to go again if their restore brings it back
      if (kind == kFrameUnsend) {
        await noteTaken(t, msgUid, kTakenUnsend, peer: peerId, at: at);
      }
    });
  }

  /// [peer] restored a backup: our unsends and last edits to them since
  /// [since] go again, each with the time it was made, so what we undid
  /// after their backup is undone there again. one already queued keeps
  /// its place. how many
  Future<int> requeueTakenSince(String peer, {required int since}) async {
    final db = await open();
    return db.transaction((t) async {
      var n = 0;
      Future<bool> held(String table, String where, List<Object?> args) async =>
          (await t.query(
            table,
            columns: ['msg_uid'],
            where: where,
            whereArgs: args,
            limit: 1,
          )).isNotEmpty;
      for (final r in await takenSince(t, peer: peer, since: since)) {
        if (r.kind == kTakenUnsend) {
          if (await held(
            'frames_out',
            'msg_uid = ? AND kind = ? AND peer_id = ?',
            [r.uid, kFrameUnsend, peer],
          )) {
            continue;
          }
          await t.insert('frames_out', {
            'msg_uid': r.uid,
            'kind': kFrameUnsend,
            'peer_id': peer,
            'body': '',
            'at': r.at,
          });
          n++;
          continue;
        }
        if (await held('edits_out', 'msg_uid = ?', [r.uid])) continue;
        // only a row still ours to them
        final mine = await t.query(
          'messages',
          columns: ['id'],
          where: "msg_uid = ? AND direction = 'out' AND peer_id = ?",
          whereArgs: [r.uid, peer],
          limit: 1,
        );
        if (mine.isEmpty) continue;
        await t.insert('edits_out', {
          'msg_uid': r.uid,
          'peer_id': peer,
          'new_text': r.body,
          'at': r.at,
        });
        n++;
      }
      return n;
    });
  }

  // the oldest rows that can go now: none of the [waiting] peers', whose
  // seals wait on their card, and none still waiting out its gap. a
  // receipt or a reaction a week old, or a reaction past its tries, has
  // no one left to reach, and goes. a take-back stays
  Future<List<Map<String, Object?>>> unsentFrames({
    Iterable<String> waiting = const [],
    int? now,
  }) async {
    final db = await open();
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final old = at - kReceiptKeptFor.inMilliseconds;
    for (final kind in const [kFrameReceipt, kFrameReaction]) {
      await db.delete(
        'frames_out',
        where: 'kind = ? AND at < ?',
        whereArgs: [kind, old],
      );
    }
    for (final kind in const [kFrameReaction, kFrameShots]) {
      await db.delete(
        'frames_out',
        where: 'kind = ? AND tries > ?',
        whereArgs: [kind, kFrameTries - 1],
      );
    }
    final skip = waiting.toList();
    return db.query(
      'frames_out',
      where:
          'next_at < ?'
          '${skip.isEmpty ? '' : ' AND peer_id NOT IN (${List.filled(skip.length, '?').join(', ')})'}',
      whereArgs: [at + 1, ...skip],
      orderBy: 'at ASC',
      limit: 40,
    );
  }

  Future<void> triedFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
    int tries,
    int now,
  ) => _tried(
    'frames_out',
    'msg_uid = ? AND kind = ? AND peer_id = ? AND body = ?',
    [msgUid, kind, peerId, body],
    tries,
    now,
  );

  /// [w], the sender's time on an edit or reaction of [msgUid], is no
  /// older than the last one taken from them: noted, and true. false for
  /// a late copy
  Future<bool> takeFrameOrder(
    String msgUid,
    String sender,
    String kind,
    int w,
  ) async {
    final db = await open();
    return db.transaction((t) async {
      final r = await t.query(
        'frame_order',
        columns: ['w'],
        where: 'msg_uid = ? AND sender = ? AND kind = ?',
        whereArgs: [msgUid, sender, kind],
        limit: 1,
      );
      if (r.isNotEmpty && (r.first['w'] as int) > w) return false;
      await t.insert('frame_order', {
        'msg_uid': msgUid,
        'sender': sender,
        'kind': kind,
        'w': w,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  // only the word that was sent: a newer one queued meanwhile stays
  Future<void> dropFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async {
    final db = await open();
    await db.delete(
      'frames_out',
      where: 'msg_uid = ? AND kind = ? AND peer_id = ? AND body = ?',
      whereArgs: [msgUid, kind, peerId, body],
    );
  }

  // a block: nothing queued for them goes after it, a receipt, an edit, a
  // pin or a reaction. a take-back only withdraws, and still goes
  Future<void> dropQueuedTo(String peerId) async =>
      _dropQueuedTo(await open(), peerId);

  // a row of ours a block here kept from going
  Future<bool> heldBack(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return r.isNotEmpty && r.first['sent'] == kNotSent;
  }

  // one row a block kept from going
  Future<void> holdBack(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': kNotSent},
      where: 'msg_uid = ? AND direction = ? AND sent = ?',
      whereArgs: [msgUid, 'out', 0],
    );
  }

  // a tap on a row a block held back: it waits to go like any unsent row
  Future<void> sendAgain(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': 0},
      where: 'msg_uid = ? AND sent = ?',
      whereArgs: [msgUid, kNotSent],
    );
  }

  Future<void> queueEdit(String msgUid, String peerId, String newText) async {
    final db = await open();
    final at = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((t) async {
      await t.insert('edits_out', {
        'msg_uid': msgUid,
        'peer_id': peerId,
        'new_text': newText,
        'at': at,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await noteTaken(
        t,
        msgUid,
        kTakenEdit,
        peer: peerId,
        body: newText,
        at: at,
      );
    });
  }

  Future<List<Map<String, Object?>>> unsentEdits({
    Set<String> skip = const {},
    int? now,
  }) async {
    final db = await open();
    final s = skip.toList();
    return db.query(
      'edits_out',
      where: '$kNotBlocked AND next_at < ?${_notIn(s)}',
      whereArgs: [(now ?? DateTime.now().millisecondsSinceEpoch) + 1, ...s],
      orderBy: 'at ASC',
      limit: 40,
    );
  }

  Future<void> triedEdit(String msgUid, String newText, int tries, int now) =>
      _tried(
        'edits_out',
        'msg_uid = ? AND new_text = ?',
        [msgUid, newText],
        tries,
        now,
      );

  // with [newText], only the wording that went: a newer one queued
  // meanwhile stays
  Future<void> dropEdit(String msgUid, {String? newText}) async {
    final db = await open();
    await db.delete(
      'edits_out',
      where: newText == null ? 'msg_uid = ?' : 'msg_uid = ? AND new_text = ?',
      whereArgs: [msgUid, ?newText],
    );
  }

  Future<Map<String, Object?>?> queuedEdit(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'edits_out',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  Future<bool> isSent(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return false;
    return (r.first['sent'] as int? ?? 0) == 1;
  }

  // every outgoing row the wire never accepted, oldest first. the drainer
  // walks this on a timer so a send survives tor warmup, backing out of the
  // chat, and a cold restart. keyed on `sent`, not `delivered`: retrying on
  // a missing ack loops forever when the ack never comes.
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async {
    final db = await open();
    final s = skip.toList();
    return db.query(
      'messages',
      // group text stays out: a group send marks sent on the first ack, so
      // a row still at 0 is one nobody could take, and the screen owns its
      // retry. group media comes along, it has the same chunked path as 1:1.
      where:
          "direction = 'out' AND sent = 0 AND msg_uid IS NOT NULL "
          "AND (group_id IS NULL OR group_id = '' "
          "OR media_path IS NOT NULL OR file_path IS NOT NULL) "
          'AND $kNotBlocked${_notIn(s)}',
      whereArgs: s.isEmpty ? null : s,
      orderBy: 'sent_at ASC',
      limit: 40,
    );
  }

  // rows for these peers stay out of a queue's window
  static String _notIn(List<String> s) => s.isEmpty
      ? ''
      : ' AND peer_id NOT IN (${List.filled(s.length, '?').join(', ')})';

  // every contact held here: verified under one key, holding another now,
  // or verified and their session rebuilt by a heal
  Future<Set<String>> heldPeers() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'verified_key IS NOT NULL',
    );
    return {
      for (final r in rows)
        if (await keyHeldIn(db, r['halo_id'] as String, identity: _keySource))
          r['halo_id'] as String,
      // and those a heal holds until the person looks
      if (kHealHold) ...await healHeldPeers(db),
    };
  }

  Future<bool> isDelivered(String msgUid) async =>
      (await sendState(msgUid)).delivered;

  // what the database knows about one of our messages: handed over
  // somewhere (sent), and acknowledged by the peer (delivered)
  Future<({bool sent, bool delivered})> sendState(String msgUid) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['sent', 'delivered'],
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
      limit: 1,
    );
    if (r.isEmpty) return (sent: false, delivered: false);
    return (
      sent: (r.first['sent'] as int? ?? 0) == 1,
      delivered: (r.first['delivered'] as int? ?? 0) == 1,
    );
  }

  // a receipt from [from]: it ticks only a message of ours that went to
  // them, or one in a group they are a member of
  // [before]: only a row written before then
  Future<void> markDelivered(
    String msgUid, {
    required String from,
    int? before,
  }) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['peer_id', 'group_id', 'burn_secs', 'burn_at', 'sent_at'],
      where: 'msg_uid = ? AND direction = ?',
      whereArgs: [msgUid, 'out'],
    );
    for (final r in rows) {
      if (before != null && (r['sent_at'] as int? ?? before) >= before) {
        continue;
      }
      final g = r['group_id'] as String?;
      final ok = g == null || g.isEmpty
          ? r['peer_id'] == from
          : (await getGroupMembers(g)).contains(from);
      if (!ok) continue;
      // a timed message whose own send never came back ok is lit here,
      // or once it counts as sent nothing else ever starts its clock
      final secs = (r['burn_secs'] as num?)?.toInt();
      await db.update(
        'messages',
        {
          'sent': 1,
          'delivered': 1,
          if (secs != null && r['burn_at'] == null)
            'burn_at': DateTime.now().millisecondsSinceEpoch + secs * 1000,
        },
        where: g == null || g.isEmpty
            ? 'msg_uid = ? AND direction = ? AND peer_id = ?'
            : 'msg_uid = ? AND direction = ? AND group_id = ?',
        whereArgs: [msgUid, 'out', g == null || g.isEmpty ? from : g],
      );
    }
  }

  /// texts of ours to [peer] since [since] that went out and never came
  /// back delivered, put back in the outbox. how many
  Future<int> resendUndelivered(String peer, {required int since}) async {
    final db = await open();
    const ours =
        "$_kOneToOne AND direction = 'out' AND sent = 1 AND delivered = 0";
    final rows = await db.query(
      'messages',
      columns: ['msg_uid', 'sent_at'],
      where:
          '$ours AND msg_uid IS NOT NULL '
          'AND media_path IS NULL AND file_path IS NULL',
      whereArgs: [peer],
    );
    var n = 0;
    for (final r in rows) {
      if ((r['sent_at'] as int) < since) continue;
      // a uid is only ours to [peer]: a row of theirs or of another chat
      // with the same one stays as it is
      n += await db.update(
        'messages',
        {'sent': 0},
        where: 'msg_uid = ? AND $ours',
        whereArgs: [r['msg_uid'], peer],
      );
    }
    return n;
  }

  Future<void> markSent(String msgUid) async {
    final db = await open();
    await db.update(
      'messages',
      {'sent': 1},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }
}

Future<void> _dropQueuedTo(DatabaseExecutor db, String peerId) async {
  for (final (table, where, args) in [
    ('frames_out', 'peer_id = ? AND kind != ?', [peerId, kFrameUnsend]),
    ('edits_out', 'peer_id = ?', [peerId]),
    ('pins_out', 'peer_id = ?', [peerId]),
  ]) {
    try {
      await db.delete(table, where: where, whereArgs: args);
    } catch (e) {
      dlog('block: $table not dropped (${e.runtimeType})');
    }
  }
}

/// [sent] on a row of ours a block kept from going: not sent, and only a
/// tap sends it, an unblock never does
const kNotSent = -1;

/// every row of ours in [db] still waiting to go, in a copy that leaves
/// the phone or what a restore brought (before [before] when given): not
/// sent, and only a tap sends it. it may be one deleted, or sent long
/// since, on the phone the file came from. how many
Future<int> holdRestoredOutbox(DatabaseExecutor db, {int? before}) => db.update(
  'messages',
  {'sent': kNotSent},
  where: before == null
      ? "direction = 'out' AND sent = 0"
      : "direction = 'out' AND sent = 0 AND sent_at < ?",
  whereArgs: before == null ? null : [before],
);

/// a queue's rows for no one blocked here: one list in the database, so
/// however many there are none is a variable of its own
@visibleForTesting
const kNotBlocked =
    'peer_id NOT IN (SELECT halo_id FROM contacts WHERE blocked = 1)';
