// SPDX-License-Identifier: GPL-3.0-or-later
// a timed message not read yet shows in its own chat alone, where reading it
// starts its clock: search and saved messages leave it out, and the chat
// list learns it waits. once read it is found like any other
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, runSearchQuery;
import 'package:kryfo/read_burn.dart' show burnWaitsRow;
import 'package:kryfo/search.dart' show SearchKind;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'sqlite_ffi.dart';

// the host's sqlite behind the one call the chat list's query makes
class _Sql implements Database {
  _Sql(this.s);
  final SqliteMem s;
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => s.rawQuery(sql, arguments);
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('not here: ${i.memberName}');
}

class _Rows extends HaloDb {
  _Rows(this.db);
  final Database db;
  @override
  Future<Database> open() async => db;
}

final _later = DateTime.now().millisecondsSinceEpoch + 3600000;

// (uid, direction, burn_secs, burn_at, media)
const _shapes = <(String, String, int?, int?, String?)>[
  ('plain', 'in', null, null, null),
  ('waits', 'in', 30, null, null),
  ('lit', 'in', 30, -1, null),
  ('mine', 'out', 30, null, null),
  ('photowaits', 'in', 30, null, '/m/a.jpg'),
  ('photolit', 'in', 30, -1, '/m/b.jpg'),
];

Future<SqliteMem> _sqlite() async {
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
    'poll TEXT, preview TEXT, sticker TEXT, burn_at INTEGER, '
    'burn_secs INTEGER, burn_unseen INTEGER NOT NULL DEFAULT 0)',
  );
  await db.execute(
    "CREATE VIRTUAL TABLE msg_fts USING fts5(body, tokenize = 'unicode61')",
  );
  await db.execute("INSERT INTO contacts VALUES ('friend', 1, 0)");
  for (final (i, (uid, dir, secs, at, media)) in _shapes.indexed) {
    await db.execute(
      'INSERT INTO messages (id, msg_uid, peer_id, direction, plaintext, '
      'sent_at, media_path, burn_secs, burn_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        i + 1,
        uid,
        'friend',
        dir,
        'lunch $uid',
        i,
        media,
        secs,
        at == null ? null : _later,
      ],
    );
    await db.execute('INSERT INTO msg_fts (rowid, body) VALUES (?, ?)', [
      i + 1,
      'lunch $uid',
    ]);
  }
  return db;
}

Set<Object?> _uids(List<Map<String, Object?>> rows) => {
  for (final r in rows) r['msg_uid'],
};

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test(
    'search finds a timed message once read, never while it waits',
    () async {
      final db = await _sqlite();
      expect(_uids(await runSearchQuery(db, '"lunch"*', SearchKind.all)), {
        'plain',
        'lit',
        'mine',
        'photolit',
      });
      expect(_uids(await runSearchQuery(db, null, SearchKind.photos)), {
        'photolit',
      });
    },
    skip: skip,
  );

  test('the chat list hears that its newest message waits', () async {
    final s = await _sqlite();
    final db = _Rows(_Sql(s));
    expect(burnWaitsRow((await db.lastMessages())['friend']!), isFalse);
    await s.execute(
      'INSERT INTO messages (id, msg_uid, peer_id, direction, plaintext, '
      'sent_at, burn_secs) VALUES (99, ?, ?, ?, ?, ?, ?)',
      ['newest', 'friend', 'in', 'lunch newest', 99, 30],
    );
    final last = (await db.lastMessages())['friend']!;
    expect(last['plaintext'], 'lunch newest');
    expect(burnWaitsRow(last), isTrue);
  }, skip: skip);

  test('saved messages leave out what waits to be read', () async {
    final mem = MemDb();
    for (final (i, (uid, dir, secs, at, _)) in _shapes.indexed) {
      await mem.insert('messages', {
        'peer_id': 'friend',
        'direction': dir,
        'plaintext': 'lunch $uid',
        'sent_at': i,
        'msg_uid': uid,
        'burn_secs': secs,
        'burn_at': at == null ? null : _later,
        'saved': 1,
        'sent': 1,
      });
    }
    expect(_uids(await _Rows(mem).savedMessages()), {
      'plain',
      'lit',
      'mine',
      'photolit',
    });
  });
}
