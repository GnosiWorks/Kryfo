// SPDX-License-Identifier: GPL-3.0-or-later
// each chat's notifications go under a random tag kept in the chat's own
// container, made on create and on the upgrade to 73. one tag per chat,
// stable, and read back to the chat on a tap. a group that goes takes its
// tag, after its notifications are taken down by it
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show notifChatIn, notifTagIn, notifTagOfIn, notifTagTables;

import 'mem_db.dart';
import 'sqlite_ffi.dart';

String _body(String src, String head) {
  final at = src.indexOf(head);
  expect(at, greaterThan(-1), reason: head);
  return src.substring(at, src.indexOf('\n  }\n', at));
}

void main() {
  final src = [
    'lib/app/database.dart',
    'lib/app/state.dart',
  ].map((f) => File(f).readAsStringSync()).join('\n');
  final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
  final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
  final create = src.substring(
    src.indexOf('onCreate: (db, _) async {'),
    upgrade,
  );

  test('made on create, and on the upgrade to 73 after every older step', () {
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(73));
    expect(create, contains('await notifTagTables(db);'));
    expect(
      RegExp(
        r'if \(oldV < 73\) \{[^}]*await notifTagTables\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at73 = steps.indexOf('if (oldV < 73) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 73) expect(m.start, lessThan(at73));
    }
  });

  test('a group that goes takes its tag, after its shade is cleared', () {
    expect(
      _body(src, '  Future<void> deleteGroup(String groupId) async {'),
      contains("whereArgs: ['group:\$groupId']"),
    );
    for (final head in [
      '  Future<void> _destroyRoomTurn(',
      '  Future<void> leaveGroupAndAnnounce(String groupId) async {',
      '  Future<void> _dropGroup(String groupId, HaloDb db) async {',
    ]) {
      final body = _body(src, head);
      final un = body.indexOf("_io.unnotify('group:\$groupId')");
      final del = body.indexOf('deleteGroup(groupId)');
      expect(un, greaterThan(-1), reason: head);
      expect(del, greaterThan(un), reason: head);
    }
  });

  final sql = SqliteMem.open();
  final skip = sql == null ? 'no sqlite on this host' : null;

  test('one random tag per chat, stable, and read back', () async {
    // the app's own schema
    final db = MemDb();
    expect(await notifTagOfIn(db, 'calm-orbit-lantern'), isNull);
    final a = await notifTagIn(db, 'calm-orbit-lantern');
    final g = await notifTagIn(db, 'group:grp000000001');
    expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(g, isNot(a));
    expect(await notifTagIn(db, 'calm-orbit-lantern'), a);
    expect(await notifTagOfIn(db, 'calm-orbit-lantern'), a);
    expect(await notifChatIn(db, a), 'calm-orbit-lantern');
    expect(await notifChatIn(db, g), 'group:grp000000001');
    expect(await notifChatIn(db, 'calm-orbit-lantern'), isNull);
    expect(db.rows('notif_tags'), hasLength(2));
  });

  test('a phone from before gets the table and keeps its rows', () async {
    final db = SqliteMem.open()!;
    await db.execute('CREATE TABLE groups (group_id TEXT PRIMARY KEY)');
    await db.execute("INSERT INTO groups VALUES ('grp000000001')");
    await notifTagTables(db);
    // a second run finds it there
    await notifTagTables(db);
    await db.execute(
      "INSERT INTO notif_tags VALUES ('group:grp000000001', 'aa')",
    );
    expect(await db.rawQuery('SELECT group_id FROM groups'), [
      {'group_id': 'grp000000001'},
    ]);
    // one tag per chat, and a tag names one chat
    for (final dup in [
      "INSERT INTO notif_tags VALUES ('group:grp000000001', 'bb')",
      "INSERT INTO notif_tags VALUES ('calm-orbit-lantern', 'aa')",
    ]) {
      await expectLater(db.execute(dup), throwsA(anything));
    }
  }, skip: skip);
}
