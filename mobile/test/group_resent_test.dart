// SPDX-License-Identifier: GPL-3.0-or-later
// which groups' texts went again to a member after their restore, made on
// create and on the upgrade to 73, the last step. a phone from before gets
// the table and keeps its rows; a group that goes takes its marks
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show groupResentTables;
import 'package:kryfo/vault_life.dart' show chatTables;

import 'sqlite_ffi.dart';

void main() {
  final src = File('lib/main.dart').readAsStringSync();
  final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
  final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
  final create = src.substring(
    src.indexOf('onCreate: (db, _) async {'),
    upgrade,
  );

  test('made on create, and on the upgrade to 73 after every older step', () {
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), 73);
    expect(create, contains('await groupResentTables(db);'));
    expect(
      RegExp(
        r'if \(oldV < 73\) \{[^}]*await groupResentTables\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at73 = steps.indexOf('if (oldV < 73) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 73) expect(m.start, lessThan(at73));
    }
  });

  test('its marks go with the group, and move with it', () {
    final at = src.indexOf(
      '  Future<void> deleteGroup(String groupId) async {',
    );
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body, contains("'group_resent',"));
    expect(chatTables, contains('group_resent'));
  });

  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test(
    'a phone from before gets the table, once per restore and group',
    () async {
      final db = SqliteMem.open()!;
      await db.execute('CREATE TABLE groups (group_id TEXT PRIMARY KEY)');
      await db.execute("INSERT INTO groups VALUES ('grp000000001')");
      await groupResentTables(db);
      // a second run finds it there
      await groupResentTables(db);
      expect(await db.rawQuery('SELECT group_id FROM groups'), [
        {'group_id': 'grp000000001'},
      ]);
      await db.execute(
        "INSERT INTO group_resent VALUES ('grp000000001', 'amber', 0, 1)",
      );
      await db.execute(
        "INSERT INTO group_resent VALUES ('grp000000001', 'amber', 86400000, 1)",
      );
      await expectLater(
        db.execute(
          "INSERT INTO group_resent VALUES ('grp000000001', 'amber', 0, 2)",
        ),
        throwsA(anything),
      );
    },
    skip: skip,
  );
}
