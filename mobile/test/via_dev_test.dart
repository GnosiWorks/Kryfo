// SPDX-License-Identifier: GPL-3.0-or-later
// a contact's message that came through the developer chat is marked as
// such on his phone. the mark is a column of its own, made on create and
// on the upgrade to 67, after every older step. a phone from before keeps
// its messages, none of them marked
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show viaDevColumn;

import 'real_sqlite.dart';

const _column = 'via_dev INTEGER NOT NULL DEFAULT 0';

void main() {
  final src = File('lib/main.dart').readAsStringSync();
  final create = src.indexOf('onCreate: (db, _) async {');
  final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
  final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));

  test('made on create, and on the upgrade to 67 after every older step', () {
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), 71);
    expect(src.substring(create, upgrade), contains('$_column,'));
    expect(
      RegExp(
        r'if \(oldV < 67\) \{[^}]*await viaDevColumn\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at67 = steps.indexOf('if (oldV < 67) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 67) expect(m.start, lessThan(at67));
    }
    expect('if (oldV < 67)'.allMatches(steps), hasLength(1));
    // wrapped: a column already there is no failed boot
    final at = src.indexOf('Future<void> viaDevColumn(');
    final body = src.substring(at, src.indexOf(');\n', at));
    expect(body, contains('addColumn('));
    expect(body, contains('ADD COLUMN $_column'));
  });

  final sql = RealSqlite.open();
  test(
    'a phone from 66 gets the column, and keeps its messages unmarked',
    () async {
      final db = sql!;
      final table = RegExp(
        r"'''\s*(CREATE TABLE messages \(.*?\))\s*'''",
        dotAll: true,
      ).firstMatch(src.substring(create, upgrade))!.group(1)!;
      final v66 = table.replaceFirst(RegExp(',\\s*$_column'), '');
      expect(v66, isNot(contains('via_dev')));
      db.run(v66);
      db.run(
        "INSERT INTO messages (peer_id, direction, plaintext, sent_at) "
        "VALUES ('calm-orbit-lantern', 'in', 'from before', 1)",
      );
      await viaDevColumn(RealExecutor(db));
      // a second run finds it there
      await viaDevColumn(RealExecutor(db));
      expect(
        db
            .run('PRAGMA table_info(messages)')
            .where((c) => c['name'] == 'via_dev'),
        hasLength(1),
      );
      final row = db.run('SELECT plaintext, via_dev FROM messages').single;
      expect(row['plaintext'], 'from before');
      expect('${row['via_dev']}', '0');
    },
    skip: sql == null ? 'no sqlite library here' : null,
  );
}
