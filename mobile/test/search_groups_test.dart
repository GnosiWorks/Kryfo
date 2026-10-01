// SPDX-License-Identifier: GPL-3.0-or-later
// search finds a group's rows only while the group is here: rows a group
// left behind open nothing, so they are not offered
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show runSearchQuery;
import 'package:kryfo/search.dart' show SearchKind;

import 'sqlite_ffi.dart';

Future<SqliteMem> _rows() async {
  final db = SqliteMem.open()!;
  await db.execute(
    'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, '
    'accepted INTEGER NOT NULL DEFAULT 0, blocked INTEGER NOT NULL DEFAULT 0)',
  );
  await db.execute('CREATE TABLE groups (group_id TEXT PRIMARY KEY)');
  await db.execute(
    'CREATE TABLE messages (id INTEGER PRIMARY KEY, msg_uid TEXT, '
    'peer_id TEXT, group_id TEXT, direction TEXT, plaintext TEXT, '
    'sent_at INTEGER, media_path TEXT, file_path TEXT, file_name TEXT, '
    'poll TEXT, preview TEXT)',
  );
  await db.execute(
    "CREATE VIRTUAL TABLE msg_fts USING fts5(body, tokenize = 'unicode61')",
  );
  await db.execute(
    "INSERT INTO contacts VALUES ('friend', 1, 0), ('stranger', 0, 0), "
    "('blocked', 1, 1)",
  );
  await db.execute("INSERT INTO groups VALUES ('here')");
  final rows = <(String, String?, String, String?)>[
    ('friend', null, 'in', null),
    ('stranger', null, 'in', null),
    ('me', null, 'out', null),
    ('friend', 'here', 'in', '/m/a.jpg'),
    ('friend', 'gone', 'in', '/m/b.jpg'),
    ('me', 'gone', 'out', '/m/c.jpg'),
    ('blocked', 'here', 'in', null),
  ];
  for (final (i, (peer, group, dir, media)) in rows.indexed) {
    await db.execute(
      'INSERT INTO messages (id, msg_uid, peer_id, group_id, direction, '
      'plaintext, sent_at, media_path) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [i + 1, 'u$i', peer, group, dir, 'lunch $i', i, media],
    );
    await db.execute('INSERT INTO msg_fts (rowid, body) VALUES (?, ?)', [
      i + 1,
      'lunch $i',
    ]);
  }
  return db;
}

Set<(Object?, Object?)> _found(List<Map<String, Object?>> rows) => {
  for (final r in rows) (r['peer_id'], r['group_id']),
};

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test('words: a group here is found, one gone is not', () async {
    final db = await _rows();
    final hits = await runSearchQuery(db, '"lunch"*', SearchKind.all);
    expect(_found(hits), {('friend', null), ('me', null), ('friend', 'here')});
  }, skip: skip);

  test('photos: a group gone keeps none of its pictures here', () async {
    final db = await _rows();
    final hits = await runSearchQuery(db, null, SearchKind.photos);
    expect(_found(hits), {('friend', 'here')});
  }, skip: skip);
}
