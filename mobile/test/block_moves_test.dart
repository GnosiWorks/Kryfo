// SPDX-License-Identifier: GPL-3.0-or-later
// a group moved into the vault, or back, takes its people's block spans
// and the uids dropped from them along with their rows. someone the move
// takes out of one side leaves none of it there, so a span left open never
// holds over them if they are added again. the move's own sql, run on real
// sqlite with the vault attached; with no sqlite the tests are skipped
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, blockTables;
import 'package:kryfo/vault_life.dart';

import 'sqlite_ffi.dart';

const _g = 'g1group00001';
// blocked, known by key alone, named by nothing but the group
const _m = 'blocked-key-only';
// a contact with a chat of their own, who stays
const _f = 'friend-stays-here';

class _NoDb implements HaloDb {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// what a move reads and writes, in [s]
Future<void> _tables(SqliteMem db, String s) async {
  for (final t in [
    'CREATE TABLE $s.contacts (halo_id TEXT PRIMARY KEY, onion TEXT, '
        'xpub TEXT, first_seen INTEGER, last_seen INTEGER, back_paired '
        'INTEGER DEFAULT 0, blocked INTEGER DEFAULT 0, accepted INTEGER '
        'DEFAULT 1)',
    'CREATE TABLE $s.groups (group_id TEXT PRIMARY KEY, name TEXT)',
    'CREATE TABLE $s.group_members (group_id TEXT, halo_id TEXT, '
        'PRIMARY KEY (group_id, halo_id))',
    'CREATE TABLE $s.messages (id INTEGER PRIMARY KEY, msg_uid TEXT, '
        'peer_id TEXT, group_id TEXT, plaintext TEXT, poll TEXT, '
        'file_name TEXT, preview TEXT, sticker TEXT, media_path TEXT, '
        'file_path TEXT)',
    'CREATE TABLE $s.msg_fts (body TEXT)',
    'CREATE TABLE $s.polls_gone (uid TEXT)',
    'CREATE TABLE $s.reactions (msg_uid TEXT, reactor TEXT)',
    'CREATE TABLE $s.poll_votes (poll_uid TEXT, voter TEXT)',
    'CREATE TABLE $s.pins_out (msg_uid TEXT PRIMARY KEY)',
    'CREATE TABLE $s.edits_out (msg_uid TEXT PRIMARY KEY)',
    'CREATE TABLE $s.group_media_owed (group_id TEXT, member TEXT)',
    'CREATE TABLE $s.group_ctl_out (id INTEGER PRIMARY KEY, group_id TEXT)',
    'CREATE TABLE $s.group_roster (group_id TEXT PRIMARY KEY)',
    'CREATE TABLE $s.held_onion (id INTEGER PRIMARY KEY, peer_id TEXT)',
    'CREATE TABLE $s.media_wants (media_id TEXT, peer_id TEXT)',
    'CREATE TABLE $s.vouches (halo_id TEXT, voucher_id TEXT)',
    'CREATE TABLE $s.shield (halo_id TEXT PRIMARY KEY)',
  ]) {
    await db.execute(t);
  }
}

Future<SqliteMem> _world() async {
  final db = SqliteMem.open()!;
  await db.execute("ATTACH DATABASE ':memory:' AS v");
  await _tables(db, 'main');
  await _tables(db, 'v');
  // the app's own on the everyday side, its trigger with them
  await blockTables(db);
  await db.execute(
    'CREATE TABLE v.block_spans (peer_id TEXT NOT NULL, '
    'from_at INTEGER NOT NULL, to_at INTEGER)',
  );
  await db.execute(
    'CREATE TABLE v.blocked_drops (peer_id TEXT NOT NULL, uid TEXT NOT '
    'NULL, at INTEGER NOT NULL, PRIMARY KEY (peer_id, uid))',
  );
  await db.execute("INSERT INTO main.groups VALUES ('$_g', 'night shift')");
  for (final who in ['me', _m, _f]) {
    await db.execute("INSERT INTO main.group_members VALUES ('$_g', '$who')");
  }
  await db.execute(
    'INSERT INTO main.contacts (halo_id, onion, xpub, first_seen, last_seen, '
    "blocked, accepted) VALUES ('$_m', 'o-m', 'x-m', 1, 1, 1, 0), "
    "('$_f', 'o-f', 'x-f', 1, 1, 0, 1)",
  );
  // her own chat keeps her on the everyday side
  await db.execute(
    "INSERT INTO main.messages (msg_uid, peer_id) VALUES ('f1', '$_f')",
  );
  await db.execute(
    'INSERT INTO main.block_spans (peer_id, from_at, to_at) VALUES '
    "('$_m', 10, 50), ('$_m', 100, NULL), ('$_f', 20, 30)",
  );
  await db.execute(
    'INSERT INTO main.blocked_drops (peer_id, uid, at) VALUES '
    "('$_m', 'u1', 5), ('$_f', 'f-drop', 6)",
  );
  return db;
}

Future<List<String>> _rows(SqliteMem db, String s, String who) async => [
  for (final r in await db.rawQuery(
    'SELECT from_at, to_at FROM $s.block_spans WHERE peer_id = ? '
    'ORDER BY from_at',
    [who],
  ))
    'span ${r['from_at']}-${r['to_at']}',
  for (final r in await db.rawQuery(
    'SELECT uid FROM $s.blocked_drops WHERE peer_id = ? ORDER BY uid',
    [who],
  ))
    'drop ${r['uid']}',
];

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  const group = ChatRef(_g, group: true);

  test('a group into the vault takes its blocked member\'s spans and drops, '
      'and leaves none of them behind', () async {
    final db = await _world();
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    // the vault holds them blocked, and knows when
    expect(
      await db.rawQuery("SELECT blocked FROM v.contacts WHERE halo_id = '$_m'"),
      [
        {'blocked': 1},
      ],
    );
    expect(await _rows(db, 'v', _m), [
      'span 10-50',
      'span 100-null',
      'drop u1',
    ]);
    // the everyday side has no row of theirs, and nothing of the block
    expect(
      await db.rawQuery("SELECT 1 FROM main.contacts WHERE halo_id = '$_m'"),
      isEmpty,
    );
    expect(await _rows(db, 'main', _m), isEmpty);
    // she stays, with what is hers, and the vault's key-only row of her
    // carries the same
    expect(await _rows(db, 'main', _f), ['span 20-30', 'drop f-drop']);
    expect(await _rows(db, 'v', _f), ['span 20-30', 'drop f-drop']);
  }, skip: skip);

  test('and back out again, the same the other way', () async {
    final db = await _world();
    final mover = SqlChatMover(_NoDb(), _NoDb());
    await mover.moveRowsOn(db, group, intoVault: true);
    await mover.moveRowsOn(db, group, intoVault: false);
    expect(await _rows(db, 'main', _m), [
      'span 10-50',
      'span 100-null',
      'drop u1',
    ]);
    expect(await _rows(db, 'v', _m), isEmpty);
    expect(await _rows(db, 'v', _f), isEmpty);
    // her own rows are not doubled by the way back
    expect(await _rows(db, 'main', _f), ['span 20-30', 'drop f-drop']);
  }, skip: skip);
}
