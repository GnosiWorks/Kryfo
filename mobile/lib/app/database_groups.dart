// SPDX-License-Identifier: GPL-3.0-or-later
// groups and their members

part of '../main.dart';

mixin _GroupRows {
  // what these rows take from the rest of HaloDb
  HaloContainer get container;
  Future<Database> open();
  Future<void> _dropPhotos(Iterable<Object?> atmospheres);
  Future<void> clearGroupConversation(String groupId, {bool noteGone = true});
  Future<void> _dropGroupFiles(
    DatabaseExecutor t,
    String groupId, {
    Iterable<String> keys = const [],
  });
  Future<void> keepGroupOwedTo(String groupId, List<String> members);
  Future<String?> notifTagOf(String chat);
  Future<Set<String>> roomKeysOf(String groupId);

  // ---- groups ----

  // when this phone first had group [groupId]: its first members' row. a
  // roster sent again keeps it
  Future<int?> groupJoinedAt(String groupId) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT MIN(joined_at) AS t FROM group_members WHERE group_id = ?',
      [groupId],
    );
    return (r.first['t'] as num?)?.toInt();
  }

  // members is the full set, including the creator. isAdmin is true for
  // groups we created.
  Future<void> createGroup(
    String groupId,
    String name,
    List<String> members, {
    required bool isAdmin,
    String? adminId,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': isAdmin ? 1 : 0,
      'admin_id': adminId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = db.batch();
    for (final m in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': m,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> groupExists(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['group_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> loadGroups() async {
    final db = await open();
    return db.query('groups', orderBy: 'created_at DESC');
  }

  Future<Map<String, Object?>?> getGroup(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // the group creator/admin kryfo id. used to verify a roster self-heal
  // really came from the admin, not a member spoofing membership changes.
  Future<String?> groupAdminId(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['admin_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['admin_id'] as String?;
  }

  Future<List<String>> getGroupMembers(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'group_members',
      columns: ['halo_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'joined_at ASC',
    );
    return rows.map((r) => r['halo_id'] as String).toList();
  }

  Future<void> addGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.insert('group_members', {
      'group_id': groupId,
      'halo_id': haloId,
      'joined_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // the authoritative list from a create or reconcile control replaces the
  // whole member set. one still in it keeps when they joined: what went
  // before it never went to them
  Future<void> syncGroupMembers(String groupId, List<String> members) async {
    await keepGroupOwedTo(groupId, members);
    final db = await open();
    final batch = db.batch();
    batch.delete(
      'group_members',
      where: members.isEmpty
          ? 'group_id = ?'
          : 'group_id = ? AND halo_id NOT IN '
                '(${List.filled(members.length, '?').join(', ')})',
      whereArgs: [groupId, ...members],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final h in members) {
      batch.insert('group_members', {
        'group_id': groupId,
        'halo_id': h,
        'joined_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeGroupMember(String groupId, String haloId) async {
    final db = await open();
    await db.delete(
      'group_members',
      where: 'group_id = ? AND halo_id = ?',
      whereArgs: [groupId, haloId],
    );
    await db.transaction((t) async {
      await _owedGone(t, 'group_id = ? AND member = ?', [groupId, haloId]);
      // our edits and reactions are no longer theirs to get. take-backs
      // and controls stay: they may hold the message yet
      for (final r in await t.query(
        'group_ctl_out',
        columns: ['id', 'ctl'],
        where: 'group_id = ? AND member = ?',
        whereArgs: [groupId, haloId],
      )) {
        if (groupFrameOf(r['ctl']) == null &&
            groupWrappedOf(r['ctl']) == null) {
          continue;
        }
        await t.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
      }
    });
  }

  Future<void> renameGroup(String groupId, String name) async {
    final db = await open();
    await db.update(
      'groups',
      {'name': name},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  /// ends [groupId] here, once: what it held goes as a leave takes it,
  /// and the row stays as the line that says so. its members stay with it,
  /// for an end told again to one still writing
  Future<bool> endGroup(
    String groupId, {
    required String by,
    required int at,
  }) async {
    final db = await open();
    final n = await db.update(
      'groups',
      {'ended_at': at, 'ended_by': by, 'unread': 0, 'mentioned': 0},
      where: 'group_id = ? AND ended_at IS NULL AND room_pub IS NULL',
      whereArgs: [groupId],
    );
    if (n == 0) return false;
    await wipeEnded(groupId);
    return true;
  }

  /// an ended group's content, as deleteGroup takes it, all but the row,
  /// its members, and what of ours still goes: take-backs, the end itself
  /// and its words for older versions
  Future<void> wipeEnded(String groupId) async {
    dropDraft(container.chatKey(groupId), group: true);
    await clearGroupConversation(groupId, noteGone: false);
    final db = await open();
    // its wallpaper too: the line stays on a plain page, with no count. a
    // row with none of it is left as it is
    final atmo = (await getGroup(groupId))?['atmosphere'];
    await db.update(
      'groups',
      {'atmosphere': null, 'unread': 0, 'mentioned': 0},
      where:
          'group_id = ? AND (atmosphere IS NOT NULL OR unread != 0 '
          'OR mentioned != 0)',
      whereArgs: [groupId],
    );
    if (atmo != null) await _dropPhotos([atmo]);
    for (final table in const ['group_media_owed', 'group_resent']) {
      await db.delete(table, where: 'group_id = ?', whereArgs: [groupId]);
    }
    final gone = goneGroupPrefix(groupId);
    for (final k in {
      for (final r in await db.query('gone_in', columns: ['peer_id']))
        if (r['peer_id'] case final String k when k.startsWith(gone)) k,
    }) {
      await db.delete('gone_in', where: 'peer_id = ?', whereArgs: [k]);
    }
    for (final r in await db.query(
      'group_ctl_out',
      columns: ['id', 'ctl'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    )) {
      // a remove still owed: the one taken out drops the group by it
      if (groupUnsendOf(r['ctl']) != null ||
          groupEndOut(r['ctl']) ||
          groupRemoveOut(r['ctl'])) {
        continue;
      }
      await db.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
    }
    await db.delete(
      'notif_tags',
      where: 'chat = ?',
      whereArgs: ['group:$groupId'],
    );
  }

  /// the groups here their admin ended that still hold something a wipe
  /// takes: one cut short. a wiped one costs a look at a few indexes
  Future<List<String>> endedGroupIds() async {
    final db = await open();
    return [
      for (final r in await db.rawQuery(
        'SELECT g.group_id FROM groups g WHERE g.ended_at IS NOT NULL AND ('
        'g.atmosphere IS NOT NULL OR g.unread != 0 OR g.mentioned != 0 '
        'OR EXISTS (SELECT 1 FROM messages m WHERE m.group_id = g.group_id) '
        'OR EXISTS (SELECT 1 FROM media_chunks c '
        'WHERE c.group_id = g.group_id) '
        'OR EXISTS (SELECT 1 FROM group_media_owed o '
        'WHERE o.group_id = g.group_id) '
        'OR EXISTS (SELECT 1 FROM group_resent r '
        'WHERE r.group_id = g.group_id) '
        "OR EXISTS (SELECT 1 FROM notif_tags n WHERE n.chat = 'group:' || "
        'g.group_id))',
      ))
        r['group_id'] as String,
    ];
  }

  /// the wipes of ended groups a stop cut short, finished, each one's
  /// notifications handed to [unshade] by the tag read before it went. one
  /// that fails leaves the rest to go on; how many were finished
  Future<int> finishEndedWipes({
    Future<void> Function(String chat, Set<String> tags)? unshade,
  }) async {
    var n = 0;
    for (final g in await endedGroupIds()) {
      try {
        final chat = 'group:$g';
        final tags = {?await notifTagOf(chat)};
        await wipeEnded(g);
        n++;
        await unshade?.call(chat, tags);
      } catch (e) {
        dlog('groups: an ended one not swept (${e.runtimeType})');
      }
    }
    return n;
  }

  /// the end and its words for older versions, in each member's lane at
  /// once: a stop between the two can lose neither
  Future<void> queueGroupEnd(
    String groupId,
    Iterable<String> members,
    String notice, {
    required int now,
  }) async {
    final end = jsonEncode(const GroupControl(type: 'end').toWire());
    final words = jsonEncode(groupWrappedRow(notice));
    final db = await open();
    await db.transaction((t) async {
      for (final ctl in [end, words]) {
        for (final m in members) {
          await t.insert('group_ctl_out', {
            'group_id': groupId,
            'member': m,
            'ctl': ctl,
            'since': now,
            'tries': 0,
            'next_at': now,
          });
        }
      }
    });
  }

  Future<void> deleteGroup(String groupId) async {
    dropDraft(container.chatKey(groupId), group: true);
    final db = await open();
    final room = (await getGroup(groupId))?['room_pub'] != null;
    // what its members were still sending goes with it
    await _dropGroupFiles(
      db,
      groupId,
      keys: room
          ? {...await getGroupMembers(groupId), ...await roomKeysOf(groupId)}
          : const <String>[],
    );
    for (final table in const [
      'group_media_owed',
      'group_roster',
      'room_keys',
      'group_resent',
    ]) {
      await db.delete(table, where: 'group_id = ?', whereArgs: [groupId]);
    }
    // what of it came in and went is known no longer
    final gone = goneGroupPrefix(groupId);
    for (final k in {
      for (final r in await db.query('gone_in', columns: ['peer_id']))
        if (r['peer_id'] case final String k when k.startsWith(gone)) k,
    }) {
      await db.delete('gone_in', where: 'peer_id = ?', whereArgs: [k]);
    }
    // a take-back still goes to members who may hold the message, after
    // a leave or a remove too: they act on it without the group, and so
    // does an end. a room's keys go with it, and nothing of it could go
    for (final r in await db.query(
      'group_ctl_out',
      columns: ['id', 'ctl'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    )) {
      if (!room && groupUnsendOf(r['ctl']) != null) continue;
      if (!room && groupEndOut(r['ctl'])) continue;
      await db.delete('group_ctl_out', where: 'id = ?', whereArgs: [r['id']]);
    }
    await db.delete(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete(
      'notif_tags',
      where: 'chat = ?',
      whereArgs: ['group:$groupId'],
    );
    await db.delete('groups', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // every file a group's messages point at, so expiry can shred them
  Future<List<String>> groupFilePaths(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['media_path', 'file_path'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return [
      for (final r in rows)
        for (final k in const ['media_path', 'file_path'])
          if ((r[k] as String?)?.isNotEmpty == true) r[k] as String,
    ];
  }

  Future<void> deleteGroupMessages(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['msg_uid'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    for (final r in rows) {
      final uid = r['msg_uid'] as String?;
      if (uid != null) {
        await db.delete('reactions', where: 'msg_uid = ?', whereArgs: [uid]);
      }
    }
    await db.delete(
      'group_media_owed',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.delete('messages', where: 'group_id = ?', whereArgs: [groupId]);
  }
}
