// SPDX-License-Identifier: GPL-3.0-or-later
// a block's spans and what it dropped, on real sqlite over the app's own
// statements: a contact row that goes ends its open span, someone blocked
// before the spans were kept holds from the start and is listened on from
// when that was seeded, and the drops are swept by age at most once a day
// and held to a count per person. a block is listened on while it is
// young. the system's sqlite library is used; with none the tests are
// skipped
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        blockListenColumn,
        blockTables,
        droppedIn,
        heldBySpans,
        kBlockedDropsKept,
        kBlockedRowsSql,
        kSeedBlockSpans,
        noteBlockedDropIn,
        upgradeTo64;
import 'package:kryfo/router.dart' show kBlockListenFor;

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

// their ended spans as the app reads them
Future<List<(int, int)>> _ended(SqliteMem db, String peer) async => [
  for (final r in await db.rawQuery(
    'SELECT from_at, to_at FROM block_spans WHERE peer_id = ? AND to_at IS '
    'NOT NULL',
    [peer],
  ))
    (r['from_at'] as int, r['to_at'] as int),
];

Future<void> _span(SqliteMem db, String peer, int from, int? to) => db.execute(
  'INSERT INTO block_spans (peer_id, from_at, to_at) VALUES (?, ?, ?)',
  [peer, from, to],
);

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

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
      'unblocked, and is listened on from when that was seeded', () async {
    final db = await _db();
    await db.execute(
      "INSERT INTO contacts (halo_id, blocked) VALUES ('long-blocked', 1), "
      "('free-one-here', 0)",
    );
    final before = DateTime.now().millisecondsSinceEpoch;
    await db.execute(kSeedBlockSpans);
    final after = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT peer_id, from_at, to_at, listen_from FROM block_spans',
    );
    expect(rows, hasLength(1));
    expect(rows.single['peer_id'], 'long-blocked');
    expect(rows.single['from_at'], 0);
    expect(rows.single['to_at'], isNull);
    // sqlite's clock, to the second
    expect(rows.single['listen_from'], inInclusiveRange(before - 1000, after));
    // listened on now, and no longer once past the bound from the seed
    Future<Object?> listen(int now) async => (await db.rawQuery(
      kBlockedRowsSql,
      [now - kBlockListenFor],
    )).single['listen'];
    expect(await listen(after), 1);
    expect(await listen(before + kBlockListenFor - 2000), 1);
    expect(await listen(after + kBlockListenFor + 1000), 0);
    await db.execute(
      "UPDATE block_spans SET to_at = ? WHERE peer_id = 'long-blocked'",
      [_day],
    );
    // what came at any time is judged as held back by it
    expect(
      heldBySpans(
        await _ended(db, 'long-blocked'),
        reached: (from: 5, until: 5),
        came: 5,
      ),
      isTrue,
    );
    expect(await _ended(db, 'free-one-here'), isEmpty);
  }, skip: skip);

  test('the upgrade to 75 listens on a span seeded at 64 from now, leaves '
      'every other span alone, and runs again without harm', () async {
    final db = SqliteMem.open()!;
    // block_spans as 64 to 70 made it
    await db.execute(
      'CREATE TABLE block_spans (peer_id TEXT NOT NULL, '
      'from_at INTEGER NOT NULL, to_at INTEGER)',
    );
    await db.execute(
      'INSERT INTO block_spans (peer_id, from_at, to_at) VALUES '
      "('seeded', 0, NULL), ('seeded-ended', 0, 50), ('blocked', 7, NULL)",
    );
    final before = DateTime.now().millisecondsSinceEpoch;
    await blockListenColumn(db);
    final after = DateTime.now().millisecondsSinceEpoch;
    await blockListenColumn(db);
    final rows = {
      for (final r in await db.rawQuery(
        'SELECT peer_id, listen_from FROM block_spans',
      ))
        r['peer_id']: r['listen_from'],
    };
    expect(rows['seeded'], inInclusiveRange(before - 1000, after));
    expect(rows['seeded-ended'], isNull);
    expect(rows['blocked'], isNull);
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
      'one not at all, a seeded one from its seed', () async {
    final db = await _db();
    const now = 100 * _day;
    await db.execute(
      'INSERT INTO contacts (halo_id, blocked) VALUES '
      "('young', 1), ('old', 1), ('seeded', 1), ('seeded-old', 1), "
      "('free', 0)",
    );
    await _span(db, 'young', now - kBlockListenFor + 1, null);
    await _span(db, 'old', 5, 10);
    await _span(db, 'old', now - kBlockListenFor, null);
    await _span(db, 'seeded', 0, null);
    await db.execute(
      "UPDATE block_spans SET listen_from = ? WHERE peer_id = 'seeded'",
      [now - _day],
    );
    await db.execute(
      'INSERT INTO block_spans (peer_id, from_at, listen_from) '
      "VALUES ('seeded-old', 0, ?)",
      [now - kBlockListenFor],
    );
    await _span(db, 'free', now - 1, now);
    final rows = await db.rawQuery('$kBlockedRowsSql ORDER BY c.halo_id', [
      now - kBlockListenFor,
    ]);
    expect(
      {for (final r in rows) r['halo_id']: r['listen']},
      {'old': 0, 'seeded': 1, 'seeded-old': 0, 'young': 1},
    );
  }, skip: skip);

  test('a seed on a span table made before the column was adds it first, '
      'and the upgrade to 75 gives kept openers when they came', () async {
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, '
      'blocked INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      "INSERT INTO contacts (halo_id, blocked) VALUES ('long-blocked', 1)",
    );
    await db.execute(
      'CREATE TABLE block_spans (peer_id TEXT NOT NULL, '
      'from_at INTEGER NOT NULL, to_at INTEGER)',
    );
    await blockTables(db, seed: true);
    final rows = await db.rawQuery(
      'SELECT peer_id, from_at, listen_from FROM block_spans',
    );
    expect(rows, hasLength(1));
    expect(rows.single['from_at'], 0);
    expect(rows.single['listen_from'], isNotNull);
    // first_kept as 70 to 74 made it
    await db.execute(
      'CREATE TABLE first_kept (hash TEXT PRIMARY KEY, cipher TEXT NOT NULL, '
      "peer TEXT NOT NULL DEFAULT '', uid TEXT, at INTEGER NOT NULL, "
      'tries INTEGER NOT NULL DEFAULT 0, next_at INTEGER NOT NULL)',
    );
    await blockListenColumn(db);
    await blockListenColumn(db);
    await db.execute(
      'INSERT INTO first_kept (hash, cipher, at, next_at, reached_from, '
      "reached_until) VALUES ('h', 'c', 1, 2, 3, 4)",
    );
    expect(
      await db.rawQuery('SELECT reached_from, reached_until FROM first_kept'),
      [
        {'reached_from': 3, 'reached_until': 4},
      ],
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
        'SELECT peer_id, from_at, to_at, listen_from IS NOT NULL AS seeded '
        'FROM block_spans ORDER BY peer_id',
      ),
      [
        {'peer_id': 'blocked-at-63', 'from_at': 5, 'to_at': null, 'seeded': 0},
        {'peer_id': 'long-blocked', 'from_at': 0, 'to_at': null, 'seeded': 1},
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
