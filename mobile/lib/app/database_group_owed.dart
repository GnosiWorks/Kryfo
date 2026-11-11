// SPDX-License-Identifier: GPL-3.0-or-later
// what group members still lack: messages, files and controls

part of '../main.dart';

mixin _GroupOwedRows implements GroupOwedStore {
  // what these rows take from the rest of HaloDb
  Future<Database> open();

  // ---- group messages and files some members still lack ----

  /// a send of [msgUid] to [tried] ended with [short] still lacking slices.
  /// the rest of [tried] have it all and are owed nothing. a short member
  /// keeps its row with what it holds; [first] sends add the ones new to
  /// it, waiting from [now]. a row gone meanwhile leaves nothing owed
  Future<void> settleGroupOwed(
    String msgUid,
    String groupId, {
    required int total,
    required Iterable<String> tried,
    required Map<String, Set<int>> short,
    required int sentTo,
    required bool first,
    required int now,
  }) async {
    final db = await open();
    await db.transaction((t) async {
      final row = await t.query(
        'messages',
        columns: ['msg_uid'],
        where: 'msg_uid = ?',
        whereArgs: [msgUid],
        limit: 1,
      );
      if (row.isEmpty) {
        await t.delete(
          'group_media_owed',
          where: 'msg_uid = ?',
          whereArgs: [msgUid],
        );
        return;
      }
      for (final m in tried) {
        if (short.containsKey(m)) continue;
        await t.delete(
          'group_media_owed',
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
      }
      for (final MapEntry(key: m, value: have) in short.entries) {
        final n = await t.update(
          'group_media_owed',
          {'have': packSlices(have), 'total': total},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
        if (n > 0 || !first) continue;
        await t.insert('group_media_owed', {
          'msg_uid': msgUid,
          'group_id': groupId,
          'member': m,
          'total': total,
          'have': packSlices(have),
          'sent_to': sentTo,
          'since': now,
          'tries': 0,
          'next_at': now + groupOwedGap(0),
        });
      }
    });
  }

  @override
  Future<List<GroupOwed>> dueGroupOwed(int now) async {
    final db = await open();
    // a member past its tries is not tried again, and keeps its row
    final rows = await db.query(
      'group_media_owed',
      where: 'next_at < ? AND tries < ?',
      whereArgs: [now + 1, kGroupOwedTries],
      orderBy: 'next_at ASC',
    );
    return [for (final r in rows) GroupOwed.fromRow(r)];
  }

  @override
  Future<void> triedGroupOwed(
    String msgUid,
    Iterable<String> members,
    int now,
  ) async {
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        final r = await t.query(
          'group_media_owed',
          columns: ['tries'],
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
          limit: 1,
        );
        if (r.isEmpty) continue;
        final tries = (r.first['tries'] as int? ?? 0) + 1;
        await t.update(
          'group_media_owed',
          {'tries': tries, 'next_at': now + groupOwedGap(tries)},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [msgUid, m],
        );
      }
    });
  }

  @override
  Future<void> dropGroupOwed(String msgUid) async {
    final db = await open();
    await db.delete(
      'group_media_owed',
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
  }

  /// the members of [groupId] no longer in [members] are owed nothing
  Future<void> keepGroupOwedTo(String groupId, List<String> members) async {
    final db = await open();
    await db.transaction((t) async {
      final rows = await t.query(
        'group_media_owed',
        columns: ['member'],
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      for (final m in {for (final r in rows) r['member'] as String}) {
        if (members.contains(m)) continue;
        await _owedGone(t, 'group_id = ? AND member = ?', [groupId, m]);
      }
    });
  }

  /// [member]'s session is there now: what they are owed is due at once,
  /// with a try more for one past its tries
  Future<int> groupOwedDueNow(String member) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'group_media_owed',
        columns: ['msg_uid', 'tries'],
        where: 'member = ?',
        whereArgs: [member],
      );
      for (final r in rows) {
        final tries = r['tries'] as int? ?? 0;
        await t.update(
          'group_media_owed',
          {'next_at': 0, 'tries': min(tries, kGroupOwedTries - 1)},
          where: 'msg_uid = ? AND member = ?',
          whereArgs: [r['msg_uid'], member],
        );
      }
      return rows.length;
    });
  }

  // a restore's mark outlives any window it could still stop
  static const _kResentKeep = Duration(days: 16);
  // one restore per member a day: each ask names its own date
  static const _kResentEvery = Duration(days: 1);

  /// our group texts since [from], owed again to [member] as texts they
  /// missed are: in each group here they are in, only what went since they
  /// joined, never one that burned. once per [restore] and group, and one
  /// [restore] per member a day. one owed already is left as it is. a
  /// room's members are keys of its own, never a restored phone. how many
  Future<int> oweGroupTextsAfterRestore(
    String member, {
    required String me,
    required int from,
    required int restore,
    required int now,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      await t.delete(
        'group_resent',
        where: 'at < ?',
        whereArgs: [now - _kResentKeep.inMilliseconds],
      );
      // another restore of theirs marked within the day: not this one too
      for (final r in await t.query(
        'group_resent',
        columns: ['since', 'at'],
        where: 'member = ?',
        whereArgs: [member],
      )) {
        final at = (r['at'] as num).toInt();
        if (r['since'] != restore && now - at < _kResentEvery.inMilliseconds) {
          return 0;
        }
      }
      var n = 0;
      for (final m in await t.query(
        'group_members',
        columns: ['group_id', 'joined_at'],
        where: 'halo_id = ?',
        whereArgs: [member],
      )) {
        final g = m['group_id'] as String;
        final group = await t.query(
          'groups',
          columns: ['room_pub'],
          where: 'group_id = ?',
          whereArgs: [g],
          limit: 1,
        );
        if (group.isEmpty || group.first['room_pub'] != null) continue;
        final marked = await t.query(
          'group_resent',
          columns: ['at'],
          where: 'group_id = ? AND member = ? AND since = ?',
          whereArgs: [g, member, restore],
          limit: 1,
        );
        if (marked.isNotEmpty) continue;
        await t.insert('group_resent', {
          'group_id': g,
          'member': member,
          'since': restore,
          'at': now,
        });
        final start = max(from, (m['joined_at'] as num?)?.toInt() ?? now);
        final others = [
          for (final r in await t.query(
            'group_members',
            columns: ['halo_id'],
            where: 'group_id = ?',
            whereArgs: [g],
          ))
            if (r['halo_id'] != me) r,
        ].length;
        // kNotSent is a block's: those wait for a tap
        for (final r in await t.query(
          'messages',
          columns: ['msg_uid', 'sent_at', 'burn_at'],
          where:
              'group_id = ? AND direction = ? AND sent = ? AND msg_uid IS NOT '
              'NULL AND media_path IS NULL AND file_path IS NULL '
              'AND sent_at >= ?',
          whereArgs: [g, 'out', 1, start],
        )) {
          final at = (r['sent_at'] as num?)?.toInt() ?? 0;
          final burn = (r['burn_at'] as num?)?.toInt();
          if (at < start || (burn != null && burn <= now)) continue;
          final uid = r['msg_uid'] as String;
          // one owed already keeps its own tries
          final had = await t.query(
            'group_media_owed',
            columns: ['tries'],
            where: 'msg_uid = ? AND member = ?',
            whereArgs: [uid, member],
            limit: 1,
          );
          if (had.isNotEmpty) continue;
          await t.insert('group_media_owed', {
            'msg_uid': uid,
            'group_id': g,
            'member': member,
            'total': 1,
            'have': '',
            'sent_to': max(others, 1),
            'since': now,
            'tries': 0,
            'next_at': now,
          });
          n++;
        }
      }
      return n;
    });
  }

  /// a group's messages some members still lack, by uid: how many of the
  /// members each went to have it, and how many of the rest are past their
  /// tries
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async {
    final db = await open();
    final rows = await db.query(
      'group_media_owed',
      columns: ['msg_uid', 'sent_to', 'tries'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    final owed = <String, int>{};
    final of = <String, int>{};
    final gaveUp = <String, int>{};
    for (final r in rows) {
      final uid = r['msg_uid'] as String;
      owed[uid] = (owed[uid] ?? 0) + 1;
      of[uid] = max(of[uid] ?? 0, r['sent_to'] as int? ?? 0);
      if ((r['tries'] as int? ?? 0) >= kGroupOwedTries) {
        gaveUp[uid] = (gaveUp[uid] ?? 0) + 1;
      }
    }
    return {
      for (final MapEntry(key: uid, value: n) in owed.entries)
        uid: (
          have: max(0, of[uid]! - n),
          of: max(of[uid]!, n),
          gaveUp: gaveUp[uid] ?? 0,
        ),
    };
  }

  // ---- group controls on their way to each member ----

  /// [ctl] for each of [members], after what each is still to get of
  /// [groupId]. due at once
  Future<void> queueGroupCtl(
    String groupId,
    Iterable<String> members,
    GroupControl ctl, {
    required int now,
  }) async {
    final body = jsonEncode(ctl.toWire());
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// a frame sealed for all of [members], each to get it in their lane
  Future<void> queueGroupWrapped(
    String groupId,
    Iterable<String> members,
    String wrapped, {
    required int now,
  }) async {
    final body = jsonEncode(groupWrappedRow(wrapped));
    final db = await open();
    await db.transaction((t) async {
      for (final m in members) {
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// the take-back of [uid] for each of [members], in the same lanes as the
  /// controls. a member it already waits for gets no second one
  Future<void> queueGroupUnsend(
    String groupId,
    Iterable<String> members,
    String uid, {
    required int now,
    // kept to go again after a member's restore (requeueGroupTakenSince)
    bool note = true,
  }) async {
    final body = jsonEncode(groupUnsendRow(uid));
    final db = await open();
    await db.transaction((t) async {
      if (note) await noteTaken(t, uid, kTakenUnsend, group: groupId, at: now);
      for (final m in members) {
        // taken back, its edit or reaction has nothing left to change
        await _dropGroupFrames(t, groupId, m, uid);
        final held = await t.query(
          'group_ctl_out',
          columns: ['id'],
          where: 'group_id = ? AND member = ? AND ctl = ?',
          whereArgs: [groupId, m, body],
          limit: 1,
        );
        if (held.isNotEmpty) continue;
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// a group edit or reaction ([groupEditRow], [groupReactRow]) for each
  /// of [members]. one of the same kind for the same message still waiting
  /// for a member goes: only the newest word is sent
  Future<void> queueGroupFrame(
    String groupId,
    Iterable<String> members,
    Map<String, String> row, {
    required int now,
    // an edit is kept to go again after a member's restore
    bool note = true,
  }) async {
    final body = jsonEncode(row);
    final f = groupFrameOf(body);
    if (f == null) return;
    final db = await open();
    await db.transaction((t) async {
      if (note && f.edit != null) {
        await noteTaken(t, f.uid, kTakenEdit, group: groupId, at: now);
      }
      for (final m in members) {
        await _dropGroupFrames(t, groupId, m, f.uid, edits: f.edit != null);
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
    });
  }

  /// a burner room has no heal to ask for what a restore brought back: our
  /// unsends in [groupId] younger than the relays keep them go to each of
  /// [members] again. one still waiting for a member gets no second. how
  /// many
  Future<int> requeueRoomUnsends(
    String groupId,
    Iterable<String> members, {
    required int now,
  }) async {
    final db = await open();
    final rows = await db.query(
      'taken_out',
      columns: ['msg_uid'],
      where: 'group_id = ? AND kind = ? AND at >= ?',
      whereArgs: [groupId, kTakenUnsend, now - kTakenKeep.inMilliseconds],
    );
    for (final r in rows) {
      await queueGroupUnsend(
        groupId,
        members,
        r['msg_uid'] as String,
        now: now,
        note: false,
      );
    }
    return rows.length;
  }

  /// [member] restored a backup: our group unsends and last edits since
  /// [since], in the groups they are still in and made since they joined,
  /// go to them again. an edit only of a row still ours, sent since they
  /// joined, with the words it holds now. how many
  Future<int> requeueGroupTakenSince(
    String member, {
    required int since,
    required int now,
  }) async {
    final db = await open();
    final taken = await takenSince(db, since: since);
    // when they joined each group, null where they are not in it
    final joined = <String, int?>{};
    Future<int?> joinedAt(String g) async {
      if (joined.containsKey(g)) return joined[g];
      final r = await db.query(
        'group_members',
        columns: ['joined_at'],
        where: 'group_id = ? AND halo_id = ?',
        whereArgs: [g, member],
        limit: 1,
      );
      return joined[g] = r.isEmpty
          ? null
          : (r.first['joined_at'] as num?)?.toInt() ?? 0;
    }

    var n = 0;
    for (final r in taken) {
      final g = r.group!;
      final from = await joinedAt(g);
      if (from == null || r.at < from) continue;
      if (r.kind == kTakenUnsend) {
        await queueGroupUnsend(g, [member], r.uid, now: now, note: false);
      } else {
        final mine = await db.query(
          'messages',
          columns: ['plaintext', 'sent_at'],
          where: "msg_uid = ? AND direction = 'out' AND group_id = ?",
          whereArgs: [r.uid, g],
          limit: 1,
        );
        if (mine.isEmpty) continue;
        if (((mine.first['sent_at'] as num?)?.toInt() ?? 0) < from) continue;
        await queueGroupFrame(
          g,
          [member],
          groupEditRow(r.uid, mine.first['plaintext'] as String? ?? ''),
          now: now,
          note: false,
        );
      }
      n++;
    }
    return n;
  }

  // [member]'s queued edits ([edits]) or reactions of [uid], or both when
  // null
  static Future<void> _dropGroupFrames(
    DatabaseExecutor t,
    String groupId,
    String member,
    String uid, {
    bool? edits,
  }) async {
    for (final r in await t.query(
      'group_ctl_out',
      columns: ['id', 'ctl'],
      where: 'group_id = ? AND member = ?',
      whereArgs: [groupId, member],
    )) {
      final o = groupFrameOf(r['ctl']);
      if (o == null || o.uid != uid) continue;
      if (edits != null && (o.edit != null) != edits) continue;
      await t.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
    }
  }

  /// every control still to go, oldest first
  Future<List<Map<String, Object?>>> groupCtlOut() async {
    final db = await open();
    return db.query('group_ctl_out', orderBy: 'id ASC');
  }

  /// what [member] is still to get of [groupId], oldest first
  Future<List<Map<String, Object?>>> groupCtlFor(
    String groupId,
    String member,
  ) async {
    final db = await open();
    return db.query(
      'group_ctl_out',
      where: 'group_id = ? AND member = ?',
      whereArgs: [groupId, member],
      orderBy: 'id ASC',
    );
  }

  /// a try of [id] is starting: its count goes up and the next wait is set
  Future<void> triedGroupCtl(int id, int now) async {
    final db = await open();
    await db.transaction((t) async {
      final r = await t.query(
        'group_ctl_out',
        columns: ['tries'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (r.isEmpty) return;
      final tries = (r.first['tries'] as int? ?? 0) + 1;
      await t.update(
        'group_ctl_out',
        {'tries': tries, 'next_at': now + groupOwedGap(tries)},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> dropGroupCtl(int id) async {
    final db = await open();
    await db.delete('group_ctl_out', where: 'id = ?', whereArgs: [id]);
  }

  /// the members still to get a control of [groupId]
  Future<Set<String>> groupCtlWaiting(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'group_ctl_out',
      columns: ['member'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return {for (final r in rows) r['member'] as String};
  }

  /// [member]'s session is there now: what it is still to get is due at
  /// once, with a try more for one past its tries
  Future<int> groupCtlDueNow(String member) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'group_ctl_out',
        columns: ['id', 'tries'],
        where: 'member = ?',
        whereArgs: [member],
      );
      for (final r in rows) {
        final tries = r['tries'] as int? ?? 0;
        await t.update(
          'group_ctl_out',
          {'next_at': 0, 'tries': min(tries, kGroupOwedTries - 1)},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
      return rows.length;
    });
  }
}

// members who left or were taken out: their rows go, and each file they
// were owed counts one fewer it went to, so the others' line stays true
Future<void> _owedGone(
  DatabaseExecutor t,
  String where,
  List<Object?> args,
) async {
  final rows = await t.query(
    'group_media_owed',
    columns: ['msg_uid', 'member', 'sent_to'],
    where: where,
    whereArgs: args,
  );
  for (final r in rows) {
    final uid = r['msg_uid'] as String;
    final to = r['sent_to'] as int? ?? 1;
    await t.delete(
      'group_media_owed',
      where: 'msg_uid = ? AND member = ?',
      whereArgs: [uid, r['member']],
    );
    await t.update(
      'group_media_owed',
      {'sent_to': to > 1 ? to - 1 : 1},
      where: 'msg_uid = ?',
      whereArgs: [uid],
    );
  }
}
