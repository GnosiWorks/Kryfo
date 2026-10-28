// SPDX-License-Identifier: GPL-3.0-or-later
// a group's screenshot block (group_shots.dart) and what each member's
// phone understands, as the 'cp' list says it (typing.dart)

part of '../main.dart';

mixin _GroupShotsRows {
  // what these rows take from the rest of HaloDb
  HaloContainer get container;
  Future<Database> open();

  static const _reads = [
    ...GroupShots.columns,
    'room_pub',
    'ended_at',
    'ended_by',
    'is_admin',
    'admin_id',
  ];

  Future<GroupShots> groupShotsOf(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: _reads,
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return GroupShots.ofRow(rows.firstOrNull, quiet: container.quiet);
  }

  // the admin's turn, read and written in one go: the word the members
  // take, null with no row or nothing to change
  Future<GroupShotsWord?> turnGroupShots(
    String groupId, {
    required bool on,
    required bool all,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final was = await _shotsIn(t, groupId);
      if (was == null || was.room || was.ended || was.on == on) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final put = groupShotsTurned(was, on: on, all: all, now: now);
      await t.update(
        'groups',
        put,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      return GroupShotsWord(on: on, all: on && all, at: put['shots_at'] as int);
    });
  }

  // the admin's row once who can has changed: the new word, or null when
  // nothing moved
  Future<GroupShotsWord?> moveGroupShotsAll(
    String groupId, {
    required bool all,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final was = await _shotsIn(t, groupId);
      if (was == null || was.room || was.ended) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final put = groupShotsAllMoved(was, all: all, now: now);
      if (put == null) return null;
      await t.update(
        'groups',
        put,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      return GroupShotsWord(on: true, all: all, at: put['shots_at'] as int);
    });
  }

  // a word from the group's admin, checked by the caller. true when taken
  Future<bool> takeGroupShots(String groupId, GroupShotsWord word) async {
    final db = await open();
    return db.transaction((t) async {
      final was = await _shotsIn(t, groupId);
      if (was == null || was.room || was.ended) return false;
      final put = groupShotsTaken(
        was,
        word,
        now: DateTime.now().millisecondsSinceEpoch,
      );
      if (put == null) return false;
      await t.update(
        'groups',
        put,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      return true;
    });
  }

  // this member's phone told the admin its bits for [at]
  Future<void> shotsTold(String groupId, int at) async {
    final db = await open();
    await db.update(
      'groups',
      {'shots_told': at},
      where: 'group_id = ? AND shots_told < ?',
      whereArgs: [groupId, at],
    );
  }

  // the groups this phone is a member of whose admin has not heard its
  // bits since the update: no rooms, none it runs, none ended
  Future<List<({String groupId, String admin})>> capsUntold() async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: const ['group_id', 'admin_id'],
      where:
          'shots_told = 0 AND is_admin = 0 AND room_pub IS NULL AND '
          'ended_at IS NULL AND admin_id IS NOT NULL',
    );
    return [
      for (final r in rows)
        (groupId: r['group_id'] as String, admin: r['admin_id'] as String),
    ];
  }

  // the groups this phone runs whose block is on: who can is worked out
  // again for them. [member]: only those [member] is in
  Future<List<String>> shotsRunHere(String me, {String? member}) async {
    final db = await open();
    const memberIn =
        ' AND EXISTS (SELECT 1 FROM group_members m '
        'WHERE m.group_id = g.group_id AND m.halo_id = ?)';
    final rows = await db.rawQuery(
      'SELECT g.group_id FROM groups g WHERE g.shots_on = 1 AND '
      'g.is_admin = 1 AND g.admin_id = ? AND g.room_pub IS NULL AND '
      'g.ended_at IS NULL${member == null ? '' : memberIn}',
      [me, ?member],
    );
    return [for (final r in rows) r['group_id'] as String];
  }

  static Future<GroupShots?> _shotsIn(Transaction t, String groupId) async {
    final rows = await t.query(
      'groups',
      columns: _reads,
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : GroupShots.ofRow(rows.first);
  }

  // ---- what each person's app can do ----

  Future<Map<String, Set<String>>> capsOfPeople(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const {};
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: const ['halo_id', 'caps'],
      where: 'halo_id IN (${List.filled(list.length, '?').join(', ')})',
      whereArgs: list,
    );
    return {
      for (final r in rows)
        r['halo_id'] as String: capsOfText(r['caps'] as String?),
    };
  }

  // what a group frame from [peer] says their phone understands, on their
  // row whether it is a contact or a member stub (typing.dart capsAfter).
  // true when it changed
  Future<bool> takeMemberCaps(
    String peer, {
    required List<String>? caps,
    required bool counts,
    int? written,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final r = await t.query(
        'contacts',
        columns: const ['caps', 'caps_at'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      if (r.isEmpty) return false;
      final next = capsAfter(
        (r.first['caps'] as String?) ?? '',
        (r.first['caps_at'] as num?)?.toInt() ?? 0,
        carried: caps,
        counts: counts,
        written: written,
      );
      if (next == null) return false;
      await t.update(
        'contacts',
        {'caps': next.caps, 'caps_at': next.at},
        where: 'halo_id = ?',
        whereArgs: [peer],
      );
      return true;
    });
  }
}

// the upgrade to 89: a group's block
Future<void> groupShotsColumns(DatabaseExecutor db) async {
  for (final col in GroupShots.columns) {
    await addColumn(
      db,
      'ALTER TABLE groups ADD COLUMN $col INTEGER NOT NULL DEFAULT 0',
    );
  }
}
