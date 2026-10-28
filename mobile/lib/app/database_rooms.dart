// SPDX-License-Identifier: GPL-3.0-or-later
// burner rooms, their rosters and member keys

part of '../main.dart';

mixin _RoomRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();

  // a burner room: a group row with a key of its own and an end time.
  // members are room keys, not kryfo ids; admin_id is the creator's key.
  // [joiningAt]: joined off a link, waiting for the creator's roster
  Future<void> createRoom({
    required String groupId,
    required String name,
    required String priv,
    required String pub,
    required int expiresAt,
    required String creatorPub,
    required String fcPk,
    int? cap,
    required List<String> members,
    int? joiningAt,
  }) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': now,
      'is_admin': creatorPub == pub ? 1 : 0,
      'admin_id': creatorPub,
      'room_priv': priv,
      'room_pub': pub,
      'expires_at': expiresAt,
      'creator_pub': creatorPub,
      'fc_pk': fcPk,
      'member_cap': cap,
      'joining_at': joiningAt,
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

  Future<Map<String, Object?>?> roomByPub(String pub) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      where: 'room_pub = ?',
      whereArgs: [pub],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// the room a knock on [pub] is for: its door key since a reset, its own
  /// key before one. once reset, its own key finds nothing
  Future<Map<String, Object?>?> roomByDoor(String pub) async {
    final db = await open();
    final reset = await db.query(
      'groups',
      where: 'door_pub = ?',
      whereArgs: [pub],
      limit: 1,
    );
    if (reset.isNotEmpty) return reset.first;
    final rows = await db.query(
      'groups',
      where: 'room_pub = ? AND door_pub IS NULL',
      whereArgs: [pub],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// a new link for a room this phone made: a new door key and the
  /// address it gives the link. [was] is the door before, kept until its
  /// files are gone. with [roster] the members' roster carrying the new
  /// address is queued in the same step, so a kill leaves both or neither.
  /// false when the room is not here, or not this phone's
  Future<bool> resetRoomDoor(
    String groupId, {
    required String priv,
    required String pub,
    required String fcPk,
    String? was,
    bool roster = false,
    required int now,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'groups',
        where: 'group_id = ? AND is_admin = 1 AND room_pub IS NOT NULL',
        whereArgs: [groupId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final g = rows.first;
      final n = await t.update(
        'groups',
        {'door_priv': priv, 'door_pub': pub, 'fc_pk': fcPk, 'door_was': was},
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      if (n == 0) return false;
      if (!roster) return true;
      final members = [
        for (final r in await t.query(
          'group_members',
          columns: ['halo_id'],
          where: 'group_id = ?',
          whereArgs: [groupId],
          orderBy: 'joined_at ASC',
        ))
          r['halo_id'] as String,
      ];
      final held = await _rosterRow(t, groupId);
      final stamp = max(now, ((held?['stamp'] as int?) ?? 0) + 1);
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      final body = jsonEncode(
        GroupControl(
          type: 'create',
          name: g['name'] as String,
          members: members,
          stamp: stamp,
          fc: fcPk,
        ).toWire(),
      );
      for (final m in members) {
        if (m == g['room_pub']) continue;
        await t.insert('group_ctl_out', {
          'group_id': groupId,
          'member': m,
          'ctl': body,
          'since': now,
          'tries': 0,
          'next_at': now,
        });
      }
      return true;
    });
  }

  /// the door before a reset, its files gone
  Future<void> clearRoomDoorWas(String groupId, String priv) async {
    final db = await open();
    await db.update(
      'groups',
      {'door_was': null},
      where: 'group_id = ? AND door_was = ?',
      whereArgs: [groupId, priv],
    );
  }

  /// the address a room's link knocks on, as its maker last gave it
  Future<void> setRoomFc(String groupId, String fcPk) async {
    final db = await open();
    await db.update(
      'groups',
      {'fc_pk': fcPk},
      where: 'group_id = ? AND room_pub IS NOT NULL',
      whereArgs: [groupId],
    );
  }

  Future<List<Map<String, Object?>>> rooms() async {
    final db = await open();
    return db.query('groups', where: 'room_pub IS NOT NULL');
  }

  Future<List<Map<String, Object?>>> expiredRooms(int now) async {
    final db = await open();
    return db.query(
      'groups',
      where: 'room_pub IS NOT NULL AND expires_at <= ?',
      whereArgs: [now],
    );
  }

  /// a join sent again at [at], or null once the creator let this phone in
  Future<void> setRoomJoining(String groupId, int? at) async {
    final db = await open();
    await db.update(
      'groups',
      {'joining_at': at},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  /// the wait of a room still waiting starts again at [at]. one let in
  /// meanwhile stays let in. false when there was no wait to restart
  Future<bool> restartRoomJoining(String groupId, int at) async {
    final db = await open();
    final n = await db.update(
      'groups',
      {'joining_at': at},
      where: 'group_id = ? AND joining_at IS NOT NULL',
      whereArgs: [groupId],
    );
    return n > 0;
  }

  /// the join sent at [at] did not go: its wait is over at once, so the
  /// room says it is not answering. a newer join, or a let-in, is kept
  Future<bool> failRoomJoining(String groupId, int at) async {
    final db = await open();
    final n = await db.update(
      'groups',
      {'joining_at': at - kRoomJoinWait.inMilliseconds},
      where: 'group_id = ? AND joining_at = ?',
      whereArgs: [groupId, at],
    );
    return n > 0;
  }

  Future<void> markRoomSeen(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'room_seen': 1},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // ---- the newest roster each group took ----

  /// the stamp for a roster this phone makes of [groupId]: above the last
  /// one, and the clock when that is higher
  Future<int> nextRosterStamp(String groupId, int now) async {
    final db = await open();
    return db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      final stamp = max(now, ((held?['stamp'] as int?) ?? 0) + 1);
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      return stamp;
    });
  }

  /// keeps [stamp] when it is newer than the last roster [groupId] took.
  /// false for an older one, or the same one again
  Future<bool> takeRosterStamp(String groupId, int stamp) async {
    final db = await open();
    return db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      if (stamp <= ((held?['stamp'] as int?) ?? 0)) return false;
      await _putRoster(t, groupId, stamp: stamp, had: held != null);
      return true;
    });
  }

  /// the number for the next frame this phone sends into room [groupId]:
  /// one up from the last, from one. none for a room no longer here: its
  /// roster row would outlive it
  Future<int> nextRoomSeq(String groupId) async {
    final db = await open();
    return db.transaction((t) async {
      final there = await t.query(
        'groups',
        columns: ['group_id'],
        where: 'group_id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (there.isEmpty) throw StateError('no room $groupId here');
      final held = await _rosterRow(t, groupId);
      final seq = ((held?['seq'] as int?) ?? 0) + 1;
      await _putRoster(t, groupId, seq: seq, had: held != null);
      return seq;
    });
  }

  /// the room keys that left [groupId] or were taken out
  Future<Set<String>> rosterGone(String groupId) async {
    final db = await open();
    final held = await _rosterRow(db, groupId);
    return {
      for (final k in ((held?['gone'] as String?) ?? '').split(','))
        if (k.isNotEmpty) k,
    };
  }

  Future<void> noteRosterGone(String groupId, Iterable<String> keys) async {
    final db = await open();
    await db.transaction((t) async {
      final held = await _rosterRow(t, groupId);
      final gone = {
        for (final k in ((held?['gone'] as String?) ?? '').split(','))
          if (k.isNotEmpty) k,
        for (final k in keys)
          if (k.isNotEmpty && !k.contains(',')) k,
      };
      await _putRoster(t, groupId, gone: gone.join(','), had: held != null);
    });
  }

  /// every member key room [groupId] ever listened to, for its end
  Future<Set<String>> roomKeysOf(String groupId) async {
    final db = await open();
    return {
      for (final r in await db.query(
        'room_keys',
        columns: ['member'],
        where: 'group_id = ?',
        whereArgs: [groupId],
      ))
        r['member'] as String,
    };
  }

  /// room [groupId] listens to [keys] from now on. false for a room no
  /// longer here, which listens to nothing
  Future<bool> noteRoomKeys(String groupId, Iterable<String> keys) =>
      _inRoom(groupId, (t) async {
        for (final k in keys) {
          await t.insert('room_keys', {
            'group_id': groupId,
            'member': k,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });

  /// a message of [key]'s taken in room [groupId], as [roomEntry] names
  /// it: the last [kRoomRecent] are what a remove of [key] lets the others
  /// still take
  Future<void> noteRoomEntry(String groupId, String key, String h) =>
      _inRoom(groupId, (t) async {
        final had = await _roomKey(t, groupId, key);
        final recent = [
          for (final x in _hashes(had?['recent']))
            if (x != h) x,
          h,
        ];
        final keep = recent.length > kRoomRecent
            ? recent.sublist(recent.length - kRoomRecent)
            : recent;
        await _putRoomKey(t, groupId, key, {
          'recent': keep.join(','),
        }, had: had != null);
      });

  /// [key]'s last messages taken in room [groupId] as [roomEntry] names
  /// them, oldest first
  Future<List<String>> roomRecent(String groupId, String key) async {
    final db = await open();
    return _hashes((await _roomKey(db, groupId, key))?['recent']);
  }

  /// [key] is out of room [groupId]. of [listed], its messages the admin
  /// took before that, the ones not taken here are owed: only they still
  /// come in. a second remove keeps what both list
  Future<Set<String>> noteRoomKeyOut(
    String groupId,
    String key, {
    Iterable<String> listed = const [],
  }) async {
    Set<String> owed = const {};
    await _inRoom(groupId, (t) async {
      final had = await _roomKey(t, groupId, key);
      final here = _hashes(had?['recent']).toSet();
      final was = (had?['out'] as int? ?? 0) == 0
          ? null
          : _hashes(had?['owed']).toSet();
      owed = {
        for (final h in listed)
          if (!here.contains(h) && (was == null || was.contains(h))) h,
      };
      await _putRoomKey(t, groupId, key, {
        'owed': owed.join(','),
        // a lane stopped already stays stopped
        if ((had?['out'] as int? ?? 0) != 2) 'out': 1,
      }, had: had != null);
    });
    return owed;
  }

  /// whether the message [entry] names ([roomEntry]) from [key], out of
  /// room [groupId], is one still owed from before it went
  Future<bool> roomOwes(String groupId, String key, String entry) async {
    final db = await open();
    final had = await _roomKey(db, groupId, key);
    return _hashes(had?['owed']).contains(entry);
  }

  /// whether a message by [uid] from [key] may be owed, its words or bytes
  /// not read yet: a file's slices, held until the file is whole
  Future<bool> roomOwesUid(String groupId, String key, String uid) async {
    final db = await open();
    final had = await _roomKey(db, groupId, key);
    final part = roomUidPart(groupId, uid);
    return _hashes(had?['owed']).any((h) => h.startsWith(part));
  }

  /// [uid] from [key] is in: how many of its owed are left
  Future<int> roomOwedIn(String groupId, String key, String uid) async {
    var left = 0;
    await _inRoom(groupId, (t) async {
      final had = await _roomKey(t, groupId, key);
      if (had == null) return;
      final part = roomUidPart(groupId, uid);
      final owed = [
        for (final x in _hashes(had['owed']))
          if (!x.startsWith(part)) x,
      ];
      left = owed.length;
      await _putRoomKey(t, groupId, key, {'owed': owed.join(',')}, had: true);
    });
    return left;
  }

  /// the keys out of room [groupId] whose lane is still to stop
  Future<Set<String>> roomKeysGoing(String groupId) async {
    final db = await open();
    return {
      for (final r in await db.query(
        'room_keys',
        columns: ['member'],
        where: 'group_id = ? AND out = ?',
        whereArgs: [groupId, 1],
      ))
        r['member'] as String,
    };
  }

  /// [key]'s lane in room [groupId] stopped and its files gone: nothing
  /// more of it comes in
  Future<void> roomKeyStopped(String groupId, String key) =>
      _inRoom(groupId, (t) async {
        final had = await _roomKey(t, groupId, key);
        await _putRoomKey(t, groupId, key, {
          'owed': '',
          'out': 2,
        }, had: had != null);
      });

  // [run] in one go with room [groupId] still here. false when it is not:
  // a row of a room gone would outlive it
  Future<bool> _inRoom(
    String groupId,
    Future<void> Function(Transaction t) run,
  ) async {
    final db = await open();
    return db.transaction((t) async {
      final there = await t.query(
        'groups',
        columns: ['group_id'],
        where: 'group_id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (there.isEmpty) return false;
      await run(t);
      return true;
    });
  }

  static List<String> _hashes(Object? text) => [
    for (final h in ((text as String?) ?? '').split(','))
      if (h.isNotEmpty) h,
  ];

  static Future<Map<String, Object?>?> _roomKey(
    DatabaseExecutor t,
    String groupId,
    String key,
  ) async {
    final r = await t.query(
      'room_keys',
      where: 'group_id = ? AND member = ?',
      whereArgs: [groupId, key],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  static Future<void> _putRoomKey(
    DatabaseExecutor t,
    String groupId,
    String key,
    Map<String, Object?> cols, {
    required bool had,
  }) async {
    if (had) {
      await t.update(
        'room_keys',
        cols,
        where: 'group_id = ? AND member = ?',
        whereArgs: [groupId, key],
      );
    } else {
      await t.insert('room_keys', {
        'group_id': groupId,
        'member': key,
        ...cols,
      });
    }
  }

  static Future<Map<String, Object?>?> _rosterRow(
    DatabaseExecutor t,
    String groupId,
  ) async {
    final r = await t.query(
      'group_roster',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  static Future<void> _putRoster(
    DatabaseExecutor t,
    String groupId, {
    int? stamp,
    String? gone,
    int? seq,
    required bool had,
  }) async {
    final cols = {'stamp': ?stamp, 'gone': ?gone, 'seq': ?seq};
    if (had) {
      await t.update(
        'group_roster',
        cols,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    } else {
      await t.insert('group_roster', {'group_id': groupId, ...cols});
    }
  }
}
