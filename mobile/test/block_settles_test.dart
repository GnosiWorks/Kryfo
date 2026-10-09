// SPDX-License-Identifier: GPL-3.0-or-later
// a block settles what was queued for them: an edit, a pin, a reaction, an
// unsend or a receipt goes, in the container that holds them and in the
// other one, a decoy's own too. what they still have queued, a text or a
// file, waits and goes nowhere while the block holds, wherever they are
// blocked. a receipt from them ticks only what went before the block, and
// a back-pair leaves their row as the block left it. the database methods
// are the real ones over rows kept in maps; the wire and signal are
// stand-ins
import 'dart:io';

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

const _bob = 'bob-who-writes';
const _amy = 'amy-who-stays';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read: the same rule, in dart
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => [
    for (final r in mem.rows('messages'))
      if (r['direction'] == 'out' &&
          r['sent'] == 0 &&
          r['msg_uid'] != null &&
          r['group_id'] == null &&
          !skip.contains(r['peer_id']))
        r,
  ];
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
      test('a block in the $name drops what was queued for them, and '
          'no one else\'s', () async {
        final mem = MemDb();
        final db = _Rows(mem, c);
        await _person(mem, _bob);
        await _person(mem, _amy);
        await _queueAll(db, _bob);
        await _queueAll(db, _amy);
        await db.setBlocked(_bob, true);
        expect(_queued(mem, _bob), isEmpty);
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
      expect(_queued(hidden, _bob), isEmpty);
      expect(_queued(everyday, _bob), isEmpty);
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
        (bob['onion'], bob['xpub'], bob['last_seen'], bob['key_changed']),
        ('o-$_bob', 'x-$_bob', 1, 0),
      );
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

    Future<void> age() async {
      for (final t in ['edits_out', 'pins_out', 'frames_out']) {
        for (final r in mem.rows(t)) {
          await mem.update(
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

    test('nothing queued for them goes while the block holds, and it goes '
        'once it ends', () async {
      await db.setBlocked(_bob, true);
      await _out(mem, 't1', _bob);
      await db.queueEdit('t0', _bob, 'changed');
      await db.queuePin('t0', _bob, true);
      await age();
      await app.drainOutbox();
      await settle();
      expect(io.sent, isEmpty);

      await db.setBlocked(_bob, false);
      await app.drainOutbox();
      await settle();
      final w = wire();
      expect(w.map((m) => m.msgUid), contains('t1'));
      expect(w.any((m) => m.edit?.targetUid == 't0'), isTrue);
      expect(w.any((m) => m.pin?.targetUid == 't0'), isTrue);
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
