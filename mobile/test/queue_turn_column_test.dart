// SPDX-License-Identifier: GPL-3.0-or-later
// a queued edit, pin or frame keeps its tries and its next turn on disk,
// and the order of edits and reactions taken in is kept per message. made
// on create and on the upgrade to 72, the last step. a phone from before
// keeps what it had queued, each row due at once
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show queueTurnColumns;

import 'real_sqlite.dart';

void main() {
  final src = File('lib/main.dart').readAsStringSync();
  final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
  final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));

  test('made on create, and on the upgrade to 72 after every older step', () {
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(72));
    for (final t in ['edits_out', 'pins_out', 'frames_out']) {
      final table = src.substring(
        src.indexOf('CREATE TABLE IF NOT EXISTS $t ('),
      );
      final cols = table.substring(0, table.indexOf("'''"));
      expect(cols, contains('tries INTEGER NOT NULL DEFAULT 0'), reason: t);
      expect(cols, contains('next_at INTEGER NOT NULL DEFAULT 0'), reason: t);
    }
    final create = src.substring(
      src.indexOf('onCreate: (db, _) async {'),
      upgrade,
    );
    expect(create, contains('await frameOrderTable(db);'));
    expect(
      RegExp(
        r'if \(oldV < 72\) \{[^}]*await queueTurnColumns\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at72 = steps.indexOf('if (oldV < 72) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 72) expect(m.start, lessThan(at72));
    }
    // wrapped: a column already there is no failed boot
    final at = src.indexOf('Future<void> queueTurnColumns(');
    final body = src.substring(at, src.indexOf('\n}\n', at));
    expect('addColumn('.allMatches(body), hasLength(2));
    expect(body, contains("const ['edits_out', 'pins_out', 'frames_out']"));
  });

  final sql = RealSqlite.open();
  test('a phone from before gets the columns and the table, and keeps its '
      'queue', () async {
    final db = sql!;
    db.run(
      'CREATE TABLE edits_out (msg_uid TEXT PRIMARY KEY, peer_id TEXT NOT '
      'NULL, new_text TEXT NOT NULL, at INTEGER NOT NULL)',
    );
    db.run(
      'CREATE TABLE pins_out (msg_uid TEXT PRIMARY KEY, peer_id TEXT NOT '
      'NULL, pinned INTEGER NOT NULL, at INTEGER NOT NULL)',
    );
    db.run(
      'CREATE TABLE frames_out (msg_uid TEXT NOT NULL, kind TEXT NOT NULL, '
      'peer_id TEXT NOT NULL, body TEXT NOT NULL, at INTEGER NOT NULL, '
      'PRIMARY KEY (msg_uid, kind, peer_id))',
    );
    db.run('CREATE TABLE messages (id INTEGER PRIMARY KEY, msg_uid TEXT)');
    db.run("INSERT INTO edits_out VALUES ('u1', 'p', 'fixed', 5)");
    db.run("INSERT INTO pins_out VALUES ('u1', 'p', 1, 5)");
    db.run("INSERT INTO frames_out VALUES ('u1', 'unsend', 'p', '', 5)");
    await queueTurnColumns(RealExecutor(db));
    // a second run finds them there
    await queueTurnColumns(RealExecutor(db));
    for (final t in ['edits_out', 'pins_out', 'frames_out']) {
      final cols = {for (final c in db.run('PRAGMA table_info($t)')) c['name']};
      expect(cols, containsAll(['tries', 'next_at']), reason: t);
      final row = db.run('SELECT msg_uid, at, tries, next_at FROM $t').single;
      expect(row, {'msg_uid': 'u1', 'at': '5', 'tries': '0', 'next_at': '0'});
    }
    // the order of what came in goes with its message
    db.run("INSERT INTO messages (msg_uid) VALUES ('m1'), ('m2')");
    db.run(
      "INSERT INTO frame_order VALUES ('m1', 's', 'edit', 9), "
      "('m2', 's', 'reaction', 9)",
    );
    db.run("DELETE FROM messages WHERE msg_uid = 'm1'");
    expect(db.run('SELECT msg_uid FROM frame_order').map((r) => r['msg_uid']), [
      'm2',
    ]);
  }, skip: sql == null ? 'no sqlite library here' : null);
}
