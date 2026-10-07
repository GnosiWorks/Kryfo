// SPDX-License-Identifier: GPL-3.0-or-later
// a timed message that came in waits to be read a day at most: then its
// clock starts unread, the app open or not, and it stays out of lists
// until read. reading it after that never gives it longer. a block starts
// the clocks of what that sender left waiting, in either container of the
// side it was made on. the real database methods over rows kept in maps,
// and the upgrade on the system's own sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show settleWaitingBurns;
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        burnUnseenTables,
        runSearchQuery,
        useDatabasesForTest;
import 'package:kryfo/read_burn.dart'
    show burnStartBy, burnWaitStarts, burnWaitsRow, kBurnSkew, kBurnWaitMost;
import 'package:kryfo/router.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database, Transaction;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'real_sqlite.dart';
import 'source_body.dart';
import 'sqlite_ffi.dart';

class _Rows extends HaloDb {
  _Rows(this.db);
  final Database db;
  @override
  Future<Database> open() async => db;
}

// a decoy as a sweep finds it: shut, or open with every open counted
class _Counted extends HaloDb {
  _Counted(this.db, {this.shut = false}) : super(HaloContainer.decoy);
  final Database db;
  bool shut;
  var opens = 0;
  @override
  bool get isOpen => !shut;
  @override
  Future<Database> open() async {
    opens++;
    return db;
  }
}

// every write transaction counted
class _Txns extends MemDb {
  var txns = 0;
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    txns++;
    return super.transaction(action, exclusive: exclusive);
  }
}

// a row filed while the sweep reads what waits, as far ahead of that
// moment as the skew lets it be
class _Filing extends MemDb {
  var armed = true;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (armed &&
        table == 'messages' &&
        where != null &&
        where.startsWith("direction = 'in'") &&
        where.endsWith('burn_at IS NULL')) {
      armed = false;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _row(
        this,
        'filed',
        sentAt: _now() + kBurnSkew.inMilliseconds - 20,
        burnSecs: 300,
      );
    }
    return super.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
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

    // a row filed while a sweep runs is a few ms past the sweep's now: it
    // waits its day like any other, not a day from now written down
    for (final (name, sweep) in <(String, Future<void> Function(HaloDb))>[
      ('the periodic sweep', (db) => db.purgeExpired()),
      ('a chat load', (db) => db.purgeExpiredBurns()),
    ]) {
      test('$name leaves one less than a minute ahead waiting', () async {
        final mem = MemDb();
        final db = _Rows(mem);
        final before = _now();
        await _row(mem, 'near', sentAt: before + 30000, burnSecs: 300);
        await _row(mem, 'far', sentAt: before + 120000, burnSecs: 300);
        await sweep(db);
        final after = _now();
        expect(_get(mem, 'near')!['burn_at'], isNull);
        expect(
          _get(mem, 'far')!['burn_at'],
          inInclusiveRange(before + _day + 300000, after + _day + 300000),
        );
      });

      test('$name reads the clock after it reads what waits', () async {
        final mem = _Filing();
        await sweep(_Rows(mem));
        expect(mem.armed, isFalse);
        expect(_get(mem, 'filed')!['burn_at'], isNull);
      });
    }
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

    // the vault was shut at the block, or the block came in a restore
    test('a chat load counts the other container\'s blocks too', () async {
      final everyday = MemDb();
      final hidden = MemDb();
      final live = _Rows(everyday);
      final vault = _Rows(hidden);
      await _contact(everyday, _peer, blocked: true);
      await _contact(hidden, _other, blocked: true);
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
      await _row(
        everyday,
        'dm',
        sentAt: _now() - 60000,
        burnSecs: 300,
        peer: _other,
      );
      final s = await Session.withVault(live, vault);
      await s.purgeExpiredBurns();
      expect(_get(hidden, 'ing')!['burn_unseen'], 1);
      expect(_get(everyday, 'dm')!['burn_unseen'], 1);
    });

    // a throw there must not undo the block, nor stop what follows it
    test('the other container shut meanwhile leaves the block whole', () async {
      final everyday = MemDb();
      final live = _Rows(everyday);
      final vault = _Throws(MemDb());
      await _contact(everyday, _peer);
      final s = await Session.withVault(live, vault);
      await s.setBlocked(_peer, true);
      expect(vault.lit, [_peer]);
      expect(everyday.rows('contacts').single['blocked'], 1);
    });
  });

  group('a sweep', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '.',
          );
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    Future<AppState> app() async {
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      return AppState(io: ArrivalIo(), router: router)..myId = 'me';
    }

    // a restore or a removal closed it to put other files in its place:
    // opened again here it would be an empty database the session keeps
    test('never opens a shut container', () async {
      final mem = MemDb();
      await _row(mem, 'due', sentAt: 1, burnAt: 1, burnSecs: 5);
      final shut = _Counted(mem, shut: true);
      expect(await shut.purgeExpired(ifOpen: true), 0);
      expect(shut.opens, 0);
      expect(_get(mem, 'due'), isNotNull);
      // nor does the app's own, with that decoy the open session
      final a = await app();
      final live = _Rows(MemDb());
      useDatabasesForTest(live, Session(shut));
      await a.sweepBurns();
      expect(shut.opens, 0);
      expect(_get(mem, 'due'), isNotNull);
    });

    test('opens an open one once, and nothing in it opens it again', () async {
      final mem = MemDb();
      await _contact(mem, _peer, blocked: true);
      await _row(mem, 'due', sentAt: 1, burnAt: 1, burnSecs: 5);
      await _row(mem, 'w', sentAt: _now() - 60000, burnSecs: 300);
      final d = _Counted(mem);
      final a = await app();
      useDatabasesForTest(_Rows(MemDb()), Session(d));
      expect(await a.sweepBurns(), 1);
      expect(d.opens, 1);
      expect(_get(mem, 'w')!['burn_unseen'], 1);
    });

    test('a block on the everyday side reaches both of its containers, and '
        'never the decoy, nor the decoy\'s the everyday one', () async {
      final everyday = MemDb();
      final hidden = MemDb();
      final live = _Rows(everyday);
      final vault = _Rows(hidden);
      await _contact(everyday, _peer, blocked: true);
      await _contact(hidden, _other, blocked: true);
      await hidden.insert('groups', {
        'group_id': _g,
        'name': 'g',
        'created_at': 1,
      });
      final ago = _now() - 60000;
      await _row(hidden, 'ing', sentAt: ago, burnSecs: 300, group: _g);
      await _row(everyday, 'dm', sentAt: ago, burnSecs: 300, peer: _other);
      final a = await app();
      useDatabasesForTest(live, await Session.withVault(live, vault));
      await a.sweepBurns();
      expect(_get(hidden, 'ing')!['burn_unseen'], 1);
      expect(_get(everyday, 'dm')!['burn_unseen'], 1);

      // a decoy session: its blocks and the everyday ones stay apart
      const third = 'green-elk-bay';
      final real = MemDb();
      final fake = MemDb();
      await _contact(real, third, blocked: true);
      await _contact(fake, _peer, blocked: true);
      await _row(real, 'r', sentAt: ago, burnSecs: 300);
      await _row(fake, 'f', sentAt: ago, burnSecs: 300, peer: third);
      useDatabasesForTest(_Rows(real), Session(_Counted(fake)));
      await a.sweepBurns();
      expect(_get(real, 'r')!['burn_at'], isNull);
      expect(_get(fake, 'f')!['burn_at'], isNull);
    });

    test('with nothing to start it writes nothing', () async {
      final mem = _Txns();
      await _row(mem, 'young', sentAt: _now() - 60000, burnSecs: 300);
      await _Rows(mem).purgeExpired();
      await _Rows(mem).purgeExpiredBurns();
      expect(mem.txns, 0);
      expect(_get(mem, 'young')!['burn_at'], isNull);
    });
  });

  group('the next look', () {
    // 10250: three quarters of a second to the next whole one
    test('wakes for a row that starts counting before the next second', () {
      expect(
        burnWaitStarts(10250, ghosts: false, starts: [10400]),
        const Duration(milliseconds: 150),
      );
      expect(burnWaitStarts(10250, ghosts: false, starts: const []), isNull);
      expect(
        burnWaitStarts(10250, ghosts: true, soonest: 10300, starts: [10400]),
        const Duration(milliseconds: 50),
      );
    });

    // nothing lit it: the countdown's next second, never at once over and
    // over
    test('one due already takes the next second, never no wait', () {
      expect(
        burnWaitStarts(10250, ghosts: false, starts: [10000]),
        const Duration(milliseconds: 750),
      );
      expect(
        burnWaitStarts(10250, ghosts: false, starts: [10000, 10600]),
        const Duration(milliseconds: 350),
      );
    });
  });

  group('the upgrade to 62', () {
    final sql = RealSqlite.open();
    final skip = sql == null ? 'no sqlite library here' : null;
    final src = File('lib/main.dart').readAsStringSync();
    final create = src.indexOf('onCreate: (db, _) async {');
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    const column = 'burn_unseen INTEGER NOT NULL DEFAULT 0';

    test('a database from 61 keeps its rows and gets the column and the '
        'index', () async {
      final db = sql!;
      // the messages table as 61 made it
      final table = RegExp(
        r"'''\s*(CREATE TABLE messages \(.*?\))\s*'''",
        dotAll: true,
      ).firstMatch(src.substring(create, upgrade))!.group(1)!;
      final v61 = table.replaceFirst(RegExp('\\s*$column,'), '');
      expect(v61, isNot(contains('burn_unseen')));
      db.run(v61);
      db.run(
        'INSERT INTO messages (peer_id, direction, plaintext, sent_at, '
        "msg_uid, burn_secs) VALUES ('p', 'in', 'kept', 5, 'u1', 30)",
      );
      await burnUnseenTables(RealExecutor(db));
      final col = db
          .run('PRAGMA table_info(messages)')
          .singleWhere((c) => c['name'] == 'burn_unseen');
      expect(col['notnull'], '1');
      expect(col['dflt_value'], '0');
      final row = db.run('SELECT * FROM messages').single;
      expect(row['plaintext'], 'kept');
      expect(row['msg_uid'], 'u1');
      expect(row['burn_secs'], '30');
      expect(row['burn_unseen'], '0');
      expect(
        db.run(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_messages_burn'",
        ),
        hasLength(1),
      );
      // the sweep's reads take the index
      for (final where in [
        "direction = 'in' AND burn_secs IS NOT NULL AND burn_at IS NULL",
        'burn_at IS NOT NULL AND burn_at < 99 AND sent = 1',
      ]) {
        final plan = db.run(
          'EXPLAIN QUERY PLAN SELECT id FROM messages WHERE $where',
        );
        expect(
          plan.map((r) => r['detail']).join(' '),
          contains('idx_messages_burn'),
          reason: where,
        );
      }
      // a second run finds it all there and changes nothing
      await burnUnseenTables(RealExecutor(db));
      expect(db.run('SELECT burn_unseen FROM messages').single, {
        'burn_unseen': '0',
      });
    }, skip: skip);

    test('made on create, and on the upgrade after every older step', () {
      final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
      expect(int.parse(version), 64);
      final made = src.substring(create, upgrade);
      expect(made, contains(column));
      expect(made, contains('await burnIndex(db);'));
      final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
      final last = steps.lastIndexOf(RegExp(r'if \(oldV < \d+\) \{'));
      expect(
        RegExp(
          r'^if \(oldV < 62\) \{[^}]*await burnUnseenTables\(db\);',
        ).hasMatch(steps.substring(last)),
        isTrue,
      );
      expect('if (oldV < 62)'.allMatches(steps), hasLength(1));
      final step = bodyOf(src, 'Future<void> burnUnseenTables(');
      expect(step, contains('ADD COLUMN $column'));
      expect(step, contains('await burnIndex(db);'));
    });
  });
}

// a vault shut while the block was made: it cannot be written
class _Throws extends HaloDb {
  _Throws(this.db) : super(HaloContainer.vault);
  final Database db;
  final lit = <String>[];
  @override
  Future<Database> open() async => db;
  @override
  Future<void> lightBurnsFrom(String haloId) async {
    lit.add(haloId);
    throw StateError('${container.dbFile} is shut');
  }
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
