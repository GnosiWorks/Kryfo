// SPDX-License-Identifier: GPL-3.0-or-later
// a held slice keeps its file and its place in it, in columns of their own,
// made on create and on the upgrade to 69, the last step. a phone from
// before keeps what its shelf holds, every row a text
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show heldMediaColumn;

import 'real_sqlite.dart';

void main() {
  final src = File('lib/app/database.dart').readAsStringSync();
  final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
  final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));

  test('made on create, and on the upgrade to 69 after every older step', () {
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(70));
    final table = src.substring(
      src.indexOf('CREATE TABLE IF NOT EXISTS held_onion ('),
    );
    final cols = table.substring(0, table.indexOf(')'));
    expect(cols, contains('media_id TEXT'));
    expect(cols, contains('chunk INTEGER'));
    expect(
      RegExp(
        r'if \(oldV < 69\) \{[^}]*await heldMediaColumn\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at69 = steps.indexOf('if (oldV < 69) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 69) expect(m.start, lessThan(at69));
    }
    // wrapped: a column already there is no failed boot
    final at = src.indexOf('Future<void> heldMediaColumn(');
    final body = src.substring(at, src.indexOf('\n}\n', at));
    expect('addColumn('.allMatches(body), hasLength(2));
  });

  final sql = RealSqlite.open();
  test(
    'a phone from before gets both columns, and keeps its shelf',
    () async {
      final db = sql!;
      db.run(
        'CREATE TABLE held_onion (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'peer_id TEXT NOT NULL, cipher TEXT NOT NULL, at INTEGER NOT NULL)',
      );
      db.run(
        "INSERT INTO held_onion (peer_id, cipher, at) "
        "VALUES ('calm-orbit-lantern', 'wire:{}', 1)",
      );
      await heldMediaColumn(RealExecutor(db));
      // a second run finds them there
      await heldMediaColumn(RealExecutor(db));
      final cols = {
        for (final c in db.run('PRAGMA table_info(held_onion)')) c['name'],
      };
      expect(cols, containsAll(['media_id', 'chunk']));
      final row = db
          .run('SELECT cipher, media_id, chunk FROM held_onion')
          .single;
      expect(row, {'cipher': 'wire:{}', 'media_id': null, 'chunk': null});
    },
    skip: sql == null ? 'no sqlite library here' : null,
  );
}
