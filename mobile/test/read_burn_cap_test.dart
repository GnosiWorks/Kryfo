// SPDX-License-Identifier: GPL-3.0-or-later
// a timed message that came in waits to be read a day at most: then its
// clock starts unread, the app open or not, and it stays out of lists
// until read. reading it after that never gives it longer. a block starts
// the clocks of what that sender left waiting. the real database methods
// over rows kept in maps
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show settleWaitingBurns;
import 'package:kryfo/main.dart' show HaloDb, runSearchQuery;
import 'package:kryfo/read_burn.dart'
    show burnStartBy, burnWaitsRow, kBurnWaitMost;
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'sqlite_ffi.dart';

class _Rows extends HaloDb {
  _Rows(this.db);
  final Database db;
  @override
  Future<Database> open() async => db;
}

const _peer = 'amber-fox-run';
const _other = 'blue-owl-sky';
const _g = 'grp000000001';
final _day = kBurnWaitMost.inMilliseconds;

int _now() => DateTime.now().millisecondsSinceEpoch;

Future<void> _row(
  MemDb mem,
  String uid, {
  required int sentAt,
  int? burnSecs,
  int? burnAt,
  String direction = 'in',
  String peer = _peer,
  String? group,
  String? media,
  bool saved = false,
}) => mem.insert('messages', {
  'peer_id': peer,
  'direction': direction,
  'plaintext': 'hi $uid',
  'sent_at': sentAt,
  'msg_uid': uid,
  'group_id': group,
  'media_path': media,
  'burn_secs': burnSecs,
  'burn_at': burnAt,
  'saved': saved ? 1 : 0,
  'sent': 1,
});

Map<String, Object?>? _get(MemDb mem, String uid) {
  for (final r in mem.rows('messages')) {
    if (r['msg_uid'] == uid) return r;
  }
  return null;
}

Future<void> _contact(MemDb mem, String id, {bool blocked = false}) =>
    mem.insert('contacts', {
      'halo_id': id,
      'onion': '',
      'xpub': '',
      'first_seen': 1,
      'last_seen': 1,
      'blocked': blocked ? 1 : 0,
    });

void main() {
  group('a day unread', () {
    for (final (name, sweep) in <(String, Future<void> Function(HaloDb))>[
      ('the periodic sweep', (db) => db.purgeExpired()),
      ('a chat load', (db) => db.purgeExpiredBurns()),
    ]) {
      test('$name starts its clock from a day after it came', () async {
        final mem = MemDb();
        final db = _Rows(mem);
        final now = _now();
        final old = now - _day - 10000;
        await _row(mem, 'old', sentAt: old, burnSecs: 300);
        await _row(mem, 'oldg', sentAt: old, burnSecs: 300, group: _g);
        await _row(mem, 'young', sentAt: now - _day + 60000, burnSecs: 300);
        await sweep(db);
        for (final uid in ['old', 'oldg']) {
          final r = _get(mem, uid)!;
          expect(r['burn_at'], old + _day + 300000, reason: uid);
          expect(r['burn_unseen'], 1, reason: uid);
        }
        expect(_get(mem, 'young')!['burn_at'], isNull);
      });

      // a phone off, or killed, from before the day was out until after
      // its window: nothing lit it, and it goes at the first sweep
      test('$name burns one past a day and its window, never lit', () async {
        final mem = MemDb();
        final db = _Rows(mem);
        final now = _now();
        await _row(mem, 'gone', sentAt: now - _day - 31000, burnSecs: 30);
        await _row(mem, 'left', sentAt: now - _day - 29000, burnSecs: 30);
        await sweep(db);
        expect(_get(mem, 'gone'), isNull);
        expect(_get(mem, 'left'), isNotNull);
      });
    }

    test('the sweep hears each one burned that way', () async {
      final mem = MemDb();
      await _row(mem, 'gone', sentAt: _now() - _day - 31000, burnSecs: 30);
      final heard = <String>[];
      final n = await _Rows(mem).purgeExpired(gone: heard.add);
      expect(n, 1);
      expect(heard, ['gone']);
    });

    test('read before the day is out, it counts from the read', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      await _row(mem, 'a', sentAt: _now() - 3600000, burnSecs: 300);
      final before = _now();
      final lit = await db.lightReadBurns(['a']);
      final after = _now();
      expect(lit['a'], inInclusiveRange(before + 300000, after + 300000));
      expect(_get(mem, 'a')!['burn_at'], lit['a']);
      expect(_get(mem, 'a')!['burn_unseen'], 0);
    });

    test('read after the day, it keeps the clock it started unread', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      final old = _now() - _day - 10000;
      await _row(mem, 'swept', sentAt: old, burnSecs: 300);
      await db.purgeExpired();
      final capped = old + _day + 300000;
      expect(_get(mem, 'swept')!['burn_at'], capped);
      final lit = await db.lightReadBurns(['swept']);
      expect(lit['swept'], capped);
      expect(_get(mem, 'swept')!['burn_at'], capped);
      expect(_get(mem, 'swept')!['burn_unseen'], 0);
      // and one nothing swept yet gets the same clock, not a fresh window
      await _row(mem, 'unswept', sentAt: old, burnSecs: 300);
      expect((await db.lightReadBurns(['unswept']))['unswept'], capped);
      // read once, it is read: the next read changes nothing
      expect((await db.lightReadBurns(['swept']))['swept'], capped);
    });

    test('reading one clears the older ones counting unread too', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      final now = _now();
      final old = now - _day - 10000;
      await _row(mem, 'older', sentAt: old, burnSecs: 300);
      await db.purgeExpired();
      await _row(mem, 'read', sentAt: now - 1000, burnSecs: 300);
      final lit = await db.lightReadBurns(['read']);
      expect(lit['older'], old + _day + 300000);
      expect(_get(mem, 'older')!['burn_unseen'], 0);
    });

    test('counting unread, it stays out of the lists until read', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      final old = _now() - _day - 10000;
      await _row(
        mem,
        'p',
        sentAt: old,
        burnSecs: 300,
        media: '/m/p.jpg',
        saved: true,
      );
      await db.purgeExpired();
      final r = _get(mem, 'p')!;
      expect(r['burn_at'], isNotNull);
      expect(burnWaitsRow(r), isTrue);
      expect(await db.mediaFor(_peer), isEmpty);
      expect(await db.savedMessages(), isEmpty);
      await db.lightReadBurns(['p']);
      expect(burnWaitsRow(_get(mem, 'p')!), isFalse);
      expect(await db.mediaFor(_peer), hasLength(1));
      expect(await db.savedMessages(), hasLength(1));
    });

    test(
      'search and the chat list leave it out until read',
      () async {
        final s = SqliteMem.open()!;
        await s.execute(
          'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, '
          'accepted INTEGER NOT NULL DEFAULT 0, '
          'blocked INTEGER NOT NULL DEFAULT 0)',
        );
        await s.execute('CREATE TABLE groups (group_id TEXT PRIMARY KEY)');
        await s.execute(
          'CREATE TABLE messages (id INTEGER PRIMARY KEY, msg_uid TEXT, '
          'peer_id TEXT, group_id TEXT, direction TEXT, plaintext TEXT, '
          'sent_at INTEGER, media_path TEXT, file_path TEXT, '
          'file_name TEXT, poll TEXT, preview TEXT, sticker TEXT, '
          'burn_at INTEGER, burn_secs INTEGER, '
          'burn_unseen INTEGER NOT NULL DEFAULT 0)',
        );
        await s.execute(
          "CREATE VIRTUAL TABLE msg_fts USING fts5(body, tokenize = 'unicode61')",
        );
        await s.execute("INSERT INTO contacts VALUES ('friend', 1, 0)");
        final later = _now() + 60000;
        for (final (i, (uid, unseen)) in [('seen', 0), ('unseen', 1)].indexed) {
          await s.execute(
            'INSERT INTO messages (id, msg_uid, peer_id, direction, '
            'plaintext, sent_at, burn_secs, burn_at, burn_unseen) '
            "VALUES (?, ?, 'friend', 'in', ?, ?, 30, ?, ?)",
            [i + 1, uid, 'lunch $uid', i, later, unseen],
          );
          await s.execute('INSERT INTO msg_fts (rowid, body) VALUES (?, ?)', [
            i + 1,
            'lunch $uid',
          ]);
        }
        final found = await runSearchQuery(s, '"lunch"*', SearchKind.all);
        expect([for (final r in found) r['msg_uid']], ['seen']);
        final last = (await _Rows(_Sql(s)).lastMessages())['friend']!;
        expect(last['plaintext'], 'lunch unseen');
        expect(burnWaitsRow(last), isTrue);
      },
      skip: SqliteMem.open() == null ? 'no sqlite on this host' : null,
    );
  });

  // sent_at on a row that came in is this phone's clock when it was filed:
  // nothing on the wire sets it. a clock set back since makes it look
  // ahead, and that must not hold the day off
  group('an arrival ahead of the clock', () {
    test('counts from now, never from later', () {
      const now = 1000000;
      expect(burnStartBy(now + 365 * 86400000, now), now + 86400000);
      expect(burnStartBy(now - 5000, now), now - 5000 + 86400000);
    });

    test(
      'the sweep writes the day from now down, so it cannot wait on',
      () async {
        final mem = MemDb();
        final db = _Rows(mem);
        final before = _now();
        await _row(mem, 'ahead', sentAt: before + 365 * _day, burnSecs: 30);
        await db.purgeExpired();
        final after = _now();
        final at = _get(mem, 'ahead')!['burn_at'] as int?;
        expect(
          at,
          inInclusiveRange(before + _day + 30000, after + _day + 30000),
        );
        // read, it counts from the read
        final lit = await db.lightReadBurns(['ahead']);
        expect(lit['ahead'], lessThanOrEqualTo(_now() + 30000));
      },
    );
  });

  group('a backup', () {
    test('counts what waits from the backup, or a day after it came if '
        'sooner, out of lists until read', () async {
      final mem = MemDb();
      final at = _now();
      await _row(mem, 'fresh', sentAt: at - 60000, burnSecs: 300);
      // its day ran out a minute before the backup
      await _row(mem, 'old', sentAt: at - _day - 60000, burnSecs: 300);
      await mem.transaction((t) => settleWaitingBurns(t, at));
      expect(_get(mem, 'fresh')!['burn_at'], at + 300000);
      expect(_get(mem, 'old')!['burn_at'], at - 60000 + 300000);
      expect(_get(mem, 'fresh')!['burn_unseen'], 1);
      expect(burnWaitsRow(_get(mem, 'old')!), isTrue);
    });
  });

  group('a block', () {
    test('starts the clocks of what they left waiting, in their chat and '
        'in groups, and an unblock leaves them counting', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      final now = _now();
      await _contact(mem, _peer);
      await _contact(mem, _other);
      await _row(mem, 'dm', sentAt: now - 60000, burnSecs: 300);
      await _row(mem, 'ing', sentAt: now - 60000, burnSecs: 300, group: _g);
      await _row(mem, 'old', sentAt: now - _day - 1000, burnSecs: 300);
      await _row(
        mem,
        'theirs',
        sentAt: now - 60000,
        burnSecs: 300,
        peer: _other,
      );
      final before = _now();
      await db.setBlocked(_peer, true);
      final after = _now();
      for (final uid in ['dm', 'ing']) {
        expect(
          _get(mem, uid)!['burn_at'],
          inInclusiveRange(before + 300000, after + 300000),
          reason: uid,
        );
        expect(_get(mem, uid)!['burn_unseen'], 1, reason: uid);
      }
      // its day ran out a second ago: it counts from then
      expect(_get(mem, 'old')!['burn_at'], now - 1000 + 300000);
      expect(_get(mem, 'theirs')!['burn_at'], isNull);
      final dm = _get(mem, 'dm')!['burn_at'];
      await db.setBlocked(_peer, false);
      expect(_get(mem, 'dm')!['burn_at'], dm);
    });

    test('reaches their rows in the other container', () async {
      final everyday = MemDb();
      final hidden = MemDb();
      final live = _Rows(everyday);
      final vault = _Rows(hidden);
      await _contact(everyday, _peer);
      // a hidden group they are in
      await hidden.insert('groups', {
        'group_id': _g,
        'name': 'g',
        'created_at': 1,
      });
      await _row(
        hidden,
        'ing',
        sentAt: _now() - 60000,
        burnSecs: 300,
        group: _g,
      );
      final s = await Session.withVault(live, vault);
      await s.setBlocked(_peer, true);
      expect(_get(hidden, 'ing')!['burn_at'], isNotNull);
      expect(_get(hidden, 'ing')!['burn_unseen'], 1);
    });

    // a restore or a hide carries a block along with rows still waiting
    test('the sweep starts a blocked sender\'s waiting rows', () async {
      final mem = MemDb();
      await _contact(mem, _peer, blocked: true);
      await _row(mem, 'w', sentAt: _now() - 60000, burnSecs: 300);
      await _row(mem, 'x', sentAt: _now() - 60000, burnSecs: 300, peer: _other);
      final before = _now();
      await _Rows(mem).purgeExpired();
      expect(_get(mem, 'w')!['burn_at'], greaterThanOrEqualTo(before + 300000));
      expect(_get(mem, 'x')!['burn_at'], isNull);
    });
  });
}

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
