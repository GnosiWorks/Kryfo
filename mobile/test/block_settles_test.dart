// SPDX-License-Identifier: GPL-3.0-or-later
// a block settles what was queued for them: an edit, a pin, a reaction or
// a receipt goes, in the container that holds them and in the other one, a
// decoy's own too, and in a vault opened later. a take-back only withdraws
// and still goes. while it holds an edit or a pin stays here, nobody
// blocked is introduced, and a text or a file waits and goes nowhere. the
// queues read the block list in the database, never as a list of
// variables. a receipt from them ticks only what went before the block,
// and a back-pair leaves their row as the block left it but for a new
// key's warning. the database methods are the real ones over rows kept in
// maps; the wire and signal are stand-ins
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        appState,
        kNotBlocked,
        kFrameReaction,
        kFrameReceipt,
        kFrameUnsend,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/media_send.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'sqlite_ffi.dart';

const _bob = 'bob-who-writes';
const _amy = 'amy-who-stays';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  // the most ids the outbox was handed to leave out
  var mostSkipped = 0;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read: the same rule, in dart
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async {
    mostSkipped = max(mostSkipped, skip.length);
    final blocked = {
      for (final c in mem.rows('contacts'))
        if (c['blocked'] == 1) c['halo_id'],
    };
    return [
      for (final r in mem.rows('messages'))
        if (r['direction'] == 'out' &&
            r['sent'] == 0 &&
            r['msg_uid'] != null &&
            r['group_id'] == null &&
            !skip.contains(r['peer_id']) &&
            !blocked.contains(r['peer_id']))
          r,
    ];
  }
}

// the most variables any one read was handed
class _Counted extends MemDb {
  var most = 0;
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
  }) {
    most = max(most, whereArgs?.length ?? 0);
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

// nothing reaches the engine
class _Engine implements HaloEngine {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

Future<void> _person(MemDb mem, String id, {bool blocked = false}) =>
    mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o-$id',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': blocked ? 1 : 0,
    });

Future<void> _queueAll(HaloDb db, String peer) async {
  await db.queueEdit('e-$peer', peer, 'changed');
  await db.queuePin('p-$peer', peer, true);
  await db.queueFrame('r-$peer', kFrameReaction, peer, 'x');
  await db.queueFrame('u-$peer', kFrameUnsend, peer, '');
  await db.queueFrame('d-$peer', kFrameReceipt, peer, '');
}

List<String> _queued(MemDb mem, String peer) => [
  for (final t in ['edits_out', 'pins_out', 'frames_out'])
    for (final r in mem.rows(t))
      if (r['peer_id'] == peer) '$t ${r['msg_uid']}',
];

Future<void> _out(MemDb mem, String uid, String peer, {int at = 1}) =>
    mem.insert('messages', {
      'peer_id': peer,
      'direction': 'out',
      'plaintext': 'text $uid',
      'sent_at': at,
      'msg_uid': uid,
      'sent': 0,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('block_settles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('the queue', () {
    for (final (name, c) in [
      ('everyday', HaloContainer.everyday),
      ('decoy', HaloContainer.decoy),
    ]) {
      test('a block in the $name drops what was queued for them but a '
          'take-back, and no one else\'s', () async {
        final mem = MemDb();
        final db = _Rows(mem, c);
        await _person(mem, _bob);
        await _person(mem, _amy);
        await _queueAll(db, _bob);
        await _queueAll(db, _amy);
        await db.setBlocked(_bob, true);
        expect(_queued(mem, _bob), ['frames_out u-$_bob']);
        expect(_queued(mem, _amy), hasLength(5));
      });
    }

    test('a block in the vault drops what the everyday side queued for '
        'them too', () async {
      final everyday = MemDb();
      final hidden = MemDb();
      final live = _Rows(everyday);
      final vault = _Rows(hidden, HaloContainer.vault);
      await _person(hidden, _bob);
      await _queueAll(live, _bob);
      await _queueAll(vault, _bob);
      final s = await Session.withVault(live, vault);
      await s.setBlocked(_bob, true);
      expect(hidden.rows('contacts').single['blocked'], 1);
      expect(_queued(hidden, _bob), ['frames_out u-$_bob']);
      expect(_queued(everyday, _bob), ['frames_out u-$_bob']);
    });

    test('the queues read the block list in the database, however long it '
        'is', () async {
      final sql = SqliteMem.open();
      if (sql == null) return markTestSkipped('no sqlite on this host');
      await sql.execute(
        'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, blocked INTEGER)',
      );
      await sql.execute('CREATE TABLE edits_out (msg_uid TEXT, peer_id TEXT)');
      await sql.execute('BEGIN');
      for (var i = 0; i < 40000; i++) {
        await sql.execute('INSERT INTO contacts VALUES (?, 1)', ['b$i']);
        await sql.execute('INSERT INTO edits_out VALUES (?, ?)', [
          'e$i',
          'b$i',
        ]);
      }
      await sql.execute('INSERT INTO contacts VALUES (?, 0)', [_amy]);
      await sql.execute('INSERT INTO edits_out VALUES (?, ?)', ['ea', _amy]);
      await sql.execute('COMMIT');
      final left = await sql.rawQuery(
        'SELECT msg_uid FROM edits_out WHERE $kNotBlocked',
      );
      expect([for (final r in left) r['msg_uid']], ['ea']);
    });

    test('a receipt from them ticks only what was written before', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      await _out(mem, 'old', _bob, at: 100);
      await _out(mem, 'new', _bob, at: 300);
      await db.markDelivered('old', from: _bob, before: 200);
      await db.markDelivered('new', from: _bob, before: 200);
      final r = {
        for (final m in mem.rows('messages')) m['msg_uid']: m['delivered'],
      };
      expect(r, {'old': 1, 'new': 0});
    });
  });

  group('their row', () {
    test('a back-pair leaves a blocked row as the block left it', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      await _person(mem, _bob, blocked: true);
      await _person(mem, _amy);
      for (final id in [_bob, _amy]) {
        await db.upsertContact(id, 'o-new', 'x-new', accepted: 0);
      }
      final rows = {for (final r in mem.rows('contacts')) r['halo_id']: r};
      final bob = rows[_bob]!;
      expect(
        (bob['onion'], bob['xpub'], bob['last_seen']),
        ('o-$_bob', 'x-$_bob', 1),
      );
      // the new key still warns once the block ends
      await db.setBlocked(_bob, false);
      expect(await db.keyChanged(_bob), isTrue);
      expect(await db.isVerified(_bob), isFalse);
      // someone not blocked is filed as before
      expect((rows[_amy]!['xpub'], rows[_amy]!['key_changed']), ('x-new', 1));
    });
  });

  group('the wire', () {
    late MemDb mem;
    late _Rows db;
    late ArrivalIo io;
    late AppState app;

    Future<AppState> make() async {
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      return AppState(io: io, router: router)
        ..myId = 'me'
        ..sendModeForTest = 'fast';
    }

    setUp(() async {
      mem = MemDb();
      db = _Rows(mem);
      io = ArrivalIo();
      await _person(mem, _bob);
      app = await make();
      useDatabasesForTest(db, Session(db));
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    Future<void> age([MemDb? of]) async {
      final m = of ?? mem;
      for (final t in ['edits_out', 'pins_out', 'frames_out']) {
        for (final r in m.rows(t)) {
          await m.update(
            t,
            {'at': 1},
            where: 'msg_uid = ?',
            whereArgs: [r['msg_uid']],
          );
        }
      }
    }

    List<UnwrappedMessage> wire() => [
      for (final (_, c) in io.sent)
        unwrapMessage(c.substring('to $_bob '.length)),
    ];

    test('while the block holds an edit or a pin stays here and is never '
        'queued, a take-back goes at once, and a text waits for the '
        'unblock', () async {
      await db.setBlocked(_bob, true);
      await _out(mem, 't1', _bob);
      await app.editInChat(_bob, 't0', 'changed');
      await app.pinInChat(_bob, 't0', true);
      await app.unsendInChat(_bob, 'u9');
      await settle();
      expect(mem.rows('edits_out'), isEmpty);
      expect(mem.rows('pins_out'), isEmpty);
      expect(mem.rows('frames_out'), isEmpty);
      expect([for (final m in wire()) m.unsend], ['u9']);
      io.sent.clear();
      await app.drainOutbox();
      await settle();
      expect(io.sent, isEmpty);

      await db.setBlocked(_bob, false);
      await app.drainOutbox();
      await settle();
      final w = wire();
      expect([for (final m in w) m.msgUid], ['t1']);
      expect(w.any((m) => m.edit != null || m.pin != null), isFalse);
    });

    test('a take-back queued before the block still goes while it '
        'holds', () async {
      io.down = true;
      await app.unsendInChat(_bob, 'u8');
      await settle();
      await db.setBlocked(_bob, true);
      expect(mem.rows('frames_out').single['kind'], kFrameUnsend);
      io.down = false;
      await age();
      await app.drainOutbox();
      await settle();
      expect(wire().single.unsend, 'u8');
      expect(mem.rows('frames_out'), isEmpty);
    });

    test('what a vault queued for someone the everyday side blocked goes '
        'unsent when it opens, but a take-back', () async {
      await db.setBlocked(_bob, true);
      final hidden = MemDb();
      final vault = _Rows(hidden, HaloContainer.vault);
      await _person(hidden, _bob);
      await _queueAll(vault, _bob);
      await age(hidden);
      useDatabasesForTest(db, await Session.withVault(db, vault));
      await app.drainOutbox();
      await settle();
      expect([for (final m in wire()) m.unsend], ['u-$_bob']);
      expect(_queued(hidden, _bob), isEmpty);
    });

    test('someone blocked is neither introduced nor introduced to', () async {
      await _person(mem, _amy);
      await db.setBlocked(_bob, true);
      for (final (a, b) in [(_bob, _amy), (_amy, _bob)]) {
        final r = await app.introduce(a, b);
        expect((r.toFirst, r.toSecond), (false, false));
      }
      expect(io.sent, isEmpty);
    });

    test('a long block list is never handed to the queues as '
        'variables', () async {
      final counted = _Counted();
      final rows = _Rows(counted);
      for (var i = 0; i < 2000; i++) {
        await _person(counted, 'blocked-$i', blocked: true);
      }
      await _person(counted, _amy);
      await rows.queueEdit('e1', _amy, 'changed');
      useDatabasesForTest(rows, Session(rows));
      await app.drainOutbox();
      await settle();
      expect(counted.most, lessThan(10));
      expect(rows.mostSkipped, lessThan(10));
    });

    test('blocked in the open vault, nothing goes to them one to one, even '
        'where the everyday side knows them', () async {
      final hidden = MemDb();
      final vault = _Rows(hidden, HaloContainer.vault);
      await _person(hidden, _bob, blocked: true);
      useDatabasesForTest(db, await Session.withVault(db, vault));
      expect(await app.sendEdit(_bob, 'u1', 'changed'), isFalse);
      await app.reactInChat(_bob, 'u1', 'x');
      await settle();
      expect(io.sent, isEmpty);
      expect(_queued(hidden, _bob), isEmpty);
      expect(_queued(mem, _bob), isEmpty);
    });

    test('a file to someone blocked stops before a slice goes', () async {
      await db.setBlocked(_bob, true);
      useEngineForTest(_Engine());
      appState.sendModeForTest = 'fast';
      final f = File('${docs.path}/a.bin')..writeAsBytesSync([1, 2, 3]);
      final r = await sendChunkedMediaTo(
        peerId: _bob,
        peerOnion: 'o-$_bob',
        peerXPub: 'x-$_bob',
        backPaired: true,
        needPow: false,
        path: f.path,
        msgUid: 'f1',
        fileName: 'a.bin',
        sender: asSender('me'),
        progressKey: _bob,
      );
      expect(r, 'parked');
    });
  });
}
