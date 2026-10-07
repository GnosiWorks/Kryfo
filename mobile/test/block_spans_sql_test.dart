// SPDX-License-Identifier: GPL-3.0-or-later
// a block's spans and what it dropped, on real sqlite over the app's own
// statements: an ended span holds from its start to its end less the
// grace for a slow clock, an open one adds nothing, a contact row that goes
// ends its open span, someone blocked before the spans were kept holds
// from the start, and the drops are swept by age at most once a day and
// held to a count per person. a block is listened on while it is young.
// the system's sqlite library is used; with none the tests are skipped
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        blockTables,
        blockedAtArgs,
        droppedIn,
        kBlockListenFor,
        kBlockedAtWhere,
        kBlockedDropsKept,
        kBlockedRowsSql,
        kSeedBlockSpans,
        kUnblockGrace,
        noteBlockedDropIn,
        upgradeTo64;

import 'sqlite_ffi.dart';

const _day = 86400000;

Future<SqliteMem> _db() async {
  final db = SqliteMem.open()!;
  await db.execute(
    'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, '
    'blocked INTEGER NOT NULL DEFAULT 0)',
  );
  await blockTables(db);
  return db;
}

Future<bool> _held(SqliteMem db, String peer, int at) async =>
    (await db.rawQuery(
      'SELECT 1 FROM block_spans WHERE $kBlockedAtWhere',
      blockedAtArgs(peer, at),
    )).isNotEmpty;

Future<void> _span(SqliteMem db, String peer, int from, int? to) => db.execute(
  'INSERT INTO block_spans (peer_id, from_at, to_at) VALUES (?, ?, ?)',
  [peer, from, to],
);

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test('an ended block holds from its start to its end, less the grace a '
      'slow clock is given', () async {
    final db = await _db();
    const from = 1000000;
    const to = from + 3 * 3600000;
    await _span(db, 'was-blocked', from, to);
    expect(await _held(db, 'was-blocked', from - 1), isFalse);
    expect(await _held(db, 'was-blocked', from), isTrue);
    expect(await _held(db, 'was-blocked', to - kUnblockGrace - 1), isTrue);
    // wrapped in the last ten minutes by their clock: let in
    expect(await _held(db, 'was-blocked', to - kUnblockGrace), isFalse);
    expect(await _held(db, 'was-blocked', to - 5 * 60000), isFalse);
    expect(await _held(db, 'was-blocked', to), isFalse);
    expect(await _held(db, 'someone-else-here', from + 1), isFalse);
  }, skip: skip);

  test('an open span holds nothing: the block itself answers while it '
      'lasts, and one left open must not hold over a later add', () async {
    final db = await _db();
    await _span(db, 'left-open-span', 100, null);
    for (final at in [100, 5000, DateTime.now().millisecondsSinceEpoch]) {
      expect(await _held(db, 'left-open-span', at), isFalse, reason: '$at');
    }
  }, skip: skip);

  test('a contact row that goes ends its open span, and leaves the ended '
      'ones as they were', () async {
    final db = await _db();
    await db.execute(
      "INSERT INTO contacts (halo_id, blocked) VALUES ('gone-row-here', 1)",
    );
    await _span(db, 'gone-row-here', 10, 50);
    await _span(db, 'gone-row-here', 100, null);
    await _span(db, 'stays-blocked', 100, null);
    final before = DateTime.now().millisecondsSinceEpoch;
    await db.execute("DELETE FROM contacts WHERE halo_id = 'gone-row-here'");
    final after = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT peer_id, from_at, to_at FROM block_spans ORDER BY peer_id, '
      'from_at',
    );
    expect(rows[0]['to_at'], 50);
    final ended = rows[1]['to_at'] as int?;
    expect(ended, isNotNull);
    // sqlite's clock, to the second
    expect(ended, inInclusiveRange(before - 1000, after));
    expect(rows[2], {
      'peer_id': 'stays-blocked',
      'from_at': 100,
      'to_at': null,
    });
  }, skip: skip);

  test('someone blocked before the spans were kept holds from the start once '
      'unblocked', () async {
    final db = await _db();
    await db.execute(
      "INSERT INTO contacts (halo_id, blocked) VALUES ('long-blocked', 1), "
      "('free-one-here', 0)",
    );
    await db.execute(kSeedBlockSpans);
    expect(
      await db.rawQuery('SELECT peer_id, from_at, to_at FROM block_spans'),
      [
        {'peer_id': 'long-blocked', 'from_at': 0, 'to_at': null},
      ],
    );
    await db.execute(
      "UPDATE block_spans SET to_at = ? WHERE peer_id = 'long-blocked'",
      [_day],
    );
    expect(await _held(db, 'long-blocked', 5), isTrue);
    expect(await _held(db, 'free-one-here', 5), isFalse);
  }, skip: skip);

  test('a uid is kept once per person, and what has not come again in sixty '
      'days goes at most once a day, by an index', () async {
    final db = await _db();
    const now = 100 * _day;
    Future<List<String>> uids() async => [
      for (final r in await db.rawQuery(
        'SELECT uid FROM blocked_drops ORDER BY uid',
      ))
        r['uid'] as String,
    ];
    await db.execute(
      'INSERT INTO blocked_drops (peer_id, uid, at) VALUES '
      "('p', 'old1', 1), ('p', 'kept', ?)",
      [now - _day],
    );
    var swept = await noteBlockedDropIn(db, 'p', 'u1', now: now, sweptAt: 0);
    expect(swept, now);
    expect(await uids(), ['kept', 'u1']);
    // the same uid again moves its row up, not a second row
    await noteBlockedDropIn(db, 'p', 'u1', now: now + 1, sweptAt: swept);
    expect(await db.rawQuery("SELECT at FROM blocked_drops WHERE uid = 'u1'"), [
      {'at': now + 1},
    ]);
    // within the day nothing is swept
    await db.execute(
      "INSERT INTO blocked_drops (peer_id, uid, at) VALUES ('p', 'old2', 1)",
    );
    swept = await noteBlockedDropIn(
      db,
      'p',
      'u2',
      now: now + _day - 1,
      sweptAt: swept,
    );
    expect(swept, now);
    expect(await uids(), ['kept', 'old2', 'u1', 'u2']);
    // a day on it is
    swept = await noteBlockedDropIn(
      db,
      'p',
      'u3',
      now: now + _day,
      sweptAt: swept,
    );
    expect(swept, now + _day);
    expect(await uids(), ['kept', 'u1', 'u2', 'u3']);
    final plan = await db.rawQuery(
      'EXPLAIN QUERY PLAN DELETE FROM blocked_drops WHERE at < ?',
      [1],
    );
    expect('$plan', contains('blocked_drops_at'));
  }, skip: skip);

  test('a person keeps only their newest drops, and one person\'s note '
      'leaves another\'s same uid alone', () async {
    final db = await _db();
    const now = 100 * _day;
    for (var i = 0; i < kBlockedDropsKept + 5; i++) {
      await noteBlockedDropIn(db, 'a', 'u$i', now: now + i, sweptAt: now);
    }
    await noteBlockedDropIn(db, 'b', 'other', now: now, sweptAt: now);
    Future<int> count(String peer) async =>
        (await db.rawQuery(
              'SELECT COUNT(*) AS n FROM blocked_drops WHERE peer_id = ?',
              [peer],
            )).first['n']
            as int;
    expect(await count('a'), kBlockedDropsKept);
    expect(await count('b'), 1);
    expect(await droppedIn(db, 'a', 'u4'), isFalse);
    expect(await droppedIn(db, 'a', 'u5'), isTrue);
    expect(await droppedIn(db, 'a', 'u${kBlockedDropsKept + 4}'), isTrue);
    expect(await droppedIn(db, 'b', 'u5'), isFalse);
    expect(await droppedIn(db, 'a', 'other'), isFalse);
    expect(await droppedIn(db, 'b', 'other'), isTrue);
  }, skip: skip);

  test('a block is listened on until it is older than the bound, an ended '
      'or seeded one not at all', () async {
    final db = await _db();
    const now = 100 * _day;
    await db.execute(
      'INSERT INTO contacts (halo_id, blocked) VALUES '
      "('young', 1), ('old', 1), ('seeded', 1), ('free', 0)",
    );
    await _span(db, 'young', now - kBlockListenFor + 1, null);
    await _span(db, 'old', 5, 10);
    await _span(db, 'old', now - kBlockListenFor, null);
    await _span(db, 'seeded', 0, null);
    await _span(db, 'free', now - 1, now);
    final rows = await db.rawQuery('$kBlockedRowsSql ORDER BY c.halo_id', [
      now - kBlockListenFor,
    ]);
    expect(
      {for (final r in rows) r['halo_id']: r['listen']},
      {'old': 0, 'seeded': 0, 'young': 1},
    );
  }, skip: skip);

  test('the steps to 64 make both tables from 63 whichever it held, and run '
      'again they open no second span', () async {
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, '
      'blocked INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      "INSERT INTO contacts (halo_id, blocked) VALUES ('long-blocked', 1), "
      "('blocked-at-63', 1)",
    );
    // a 63 that made the block tables, and a block it kept
    await blockTables(db);
    await db.execute(
      "INSERT INTO block_spans (peer_id, from_at) VALUES ('blocked-at-63', 5)",
    );
    await upgradeTo64(db, 63);
    await upgradeTo64(db, 63);
    expect(
      await db.rawQuery(
        'SELECT peer_id, from_at, to_at FROM block_spans ORDER BY peer_id',
      ),
      [
        {'peer_id': 'blocked-at-63', 'from_at': 5, 'to_at': null},
        {'peer_id': 'long-blocked', 'from_at': 0, 'to_at': null},
      ],
    );
    // and the table of what came in and went, with the same uid from two
    // people kept for each
    for (final peer in ['long-blocked', 'blocked-at-63']) {
      await db.execute(
        'INSERT OR REPLACE INTO gone_in (msg_uid, peer_id, at) '
        "VALUES ('same-uid', ?, 1)",
        [peer],
      );
    }
    expect(await db.rawQuery('SELECT peer_id FROM gone_in'), hasLength(2));
  }, skip: skip);
}
