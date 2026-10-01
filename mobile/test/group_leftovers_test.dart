// SPDX-License-Identifier: GPL-3.0-or-later
// a group left in an older version kept its rows. they go at the next
// start, with their reactions, and their files are handed back to shred;
// a group still here and the 1:1 chats keep everything
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show dropGroupLeftoversIn;

import 'sqlite_ffi.dart';

Future<SqliteMem> _rows() async {
  final db = SqliteMem.open()!;
  await db.execute('CREATE TABLE groups (group_id TEXT PRIMARY KEY)');
  await db.execute(
    'CREATE TABLE messages (id INTEGER PRIMARY KEY, msg_uid TEXT, '
    'peer_id TEXT, group_id TEXT, direction TEXT, sent INTEGER, '
    'media_path TEXT, file_path TEXT)',
  );
  await db.execute(
    'CREATE TABLE reactions (msg_uid TEXT, reactor TEXT, emoji TEXT)',
  );
  await db.execute("INSERT INTO groups VALUES ('here')");
  final rows = <(String, String?, String?, String?)>[
    ('a', null, null, null),
    ('b', '', '/m/one-to-one.jpg', null),
    ('c', 'here', '/m/kept.jpg', null),
    ('d', 'gone', '/m/left.jpg', null),
    ('e', 'gone', null, '/f/left.pdf'),
    ('f', 'gone', null, null),
  ];
  for (final (i, (uid, group, media, file)) in rows.indexed) {
    await db.execute(
      'INSERT INTO messages (id, msg_uid, peer_id, group_id, direction, '
      "sent, media_path, file_path) VALUES (?, ?, 'p', ?, 'out', 0, ?, ?)",
      [i + 1, uid, group, media, file],
    );
    await db.execute("INSERT INTO reactions VALUES (?, 'p', 'x')", [uid]);
  }
  return db;
}

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test(
    'a group gone takes its rows and reactions, and names its files',
    () async {
      final db = await _rows();
      final files = await dropGroupLeftoversIn(db);
      expect(
        {
          for (final r in files)
            for (final v in [r['media_path'], r['file_path']]) ?v,
        },
        {'/m/left.jpg', '/f/left.pdf'},
      );
      final left = await db.rawQuery('SELECT msg_uid FROM messages');
      expect([for (final r in left) r['msg_uid']], ['a', 'b', 'c']);
      final rx = await db.rawQuery('SELECT msg_uid FROM reactions');
      expect([for (final r in rx) r['msg_uid']], ['a', 'b', 'c']);
    },
    skip: skip,
  );

  test('nothing to take leaves everything', () async {
    final db = await _rows();
    await db.execute("INSERT INTO groups VALUES ('gone')");
    expect(await dropGroupLeftoversIn(db), isEmpty);
    expect(await db.rawQuery('SELECT id FROM messages'), hasLength(6));
    expect(await db.rawQuery('SELECT msg_uid FROM reactions'), hasLength(6));
  }, skip: skip);
}
