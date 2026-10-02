// SPDX-License-Identifier: GPL-3.0-or-later
// a message taken back or burned before it was read takes its unread mark
// and its own notification with it. one taken back before it came never
// lands. an unsend or a reaction made with no route queues like an edit
// and goes once one is back. the database methods are the real ones over
// rows kept in maps; the wire and signal are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, kFrameReaction, kFrameUnsend, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _bob = 'bob-who-writes';
const _eve = 'eve-who-writes';
const _g = 'grp000000001';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => const [];
}

int _unread(MemDb mem, String table, String key, String id) =>
    mem.rows(table).singleWhere((r) => r[key] == id)['unread'] as int;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('take_back');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('the unread mark', () {
    late MemDb mem;
    late _Rows db;

    Future<void> came(String uid, {String? group, int? burnAt}) =>
        mem.insert('messages', {
          'peer_id': _bob,
          'direction': 'in',
          'plaintext': uid,
          'sent_at': 1,
          'msg_uid': uid,
          'group_id': group,
          'burn_at': burnAt,
        });

    setUp(() async {
      mem = MemDb();
      db = _Rows(mem);
      await mem.insert('contacts', {
        'halo_id': _bob,
        'onion': 'o',
        'xpub': 'x',
        'first_seen': 1,
        'last_seen': 1,
        'unread': 2,
      });
      await mem.insert('groups', {
        'group_id': _g,
        'name': 'family',
        'created_at': 1,
        'unread': 1,
      });
      await came('read');
      await came('g1', group: _g);
      await came('new1');
      await came('new2');
    });

    test('an unread one taken back takes its mark', () async {
      await db.deleteMessage('new2');
      expect(_unread(mem, 'contacts', 'halo_id', _bob), 1);
      await db.deleteMessage('new1');
      expect(_unread(mem, 'contacts', 'halo_id', _bob), 0);
    });

    test('one already read leaves the count as it is', () async {
      await db.deleteMessage('read');
      expect(_unread(mem, 'contacts', 'halo_id', _bob), 2);
    });

    test('a group\'s goes from the group, not the person', () async {
      await db.deleteMessage('g1');
      expect(_unread(mem, 'groups', 'group_id', _g), 0);
      expect(_unread(mem, 'contacts', 'halo_id', _bob), 2);
    });

    test('one that burns unread takes its mark and says which', () async {
      await came('burns', burnAt: 1);
      await mem.update(
        'contacts',
        {'unread': 3},
        where: 'halo_id = ?',
        whereArgs: [_bob],
      );
      final gone = <String>[];
      expect(await db.purgeExpired(gone: gone.add), 1);
      expect(gone, ['burns']);
      expect(_unread(mem, 'contacts', 'halo_id', _bob), 2);
    });
  });

  group('arriving', () {
    late ArrivalRows live;
    late ArrivalIo io;
    late AppState app;
    var n = 0;

    setUp(() async {
      live = ArrivalRows(HaloContainer.everyday);
      io = ArrivalIo();
      live.person(_bob, onion: 'o-$_bob', xpub: 'x-$_bob');
      live.person(_eve, onion: 'o-$_eve', xpub: 'x-$_eve');
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      app = AppState(io: io, router: router)..myId = 'me';
      useDatabasesForTest(live, Session(live));
    });

    Future<void> from(String who, String plain) async {
      final c = 'c${n++}';
      io.opens[c] = (who, plain);
      await app.receiveOnion([c]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    Future<String> said(String who, String uid) =>
        wrapMessage('call me', msgUid: uid, sender: asSender(who));
    Future<String> unsaid(String who, String uid) =>
        wrapMessage('', unsend: uid, sender: asSender(who));

    test('taken back, its notification goes too', () async {
      await from(_bob, await said(_bob, 'u1'));
      expect(io.rang, [_bob]);
      await from(_bob, await unsaid(_bob, 'u1'));
      expect(live.msg('u1'), isNull);
      expect(io.unrangMessages, ['u1']);
    });

    test('taken back before it came, it never lands', () async {
      await from(_bob, await unsaid(_bob, 'u2'));
      await from(_bob, await said(_bob, 'u2'));
      expect(live.msg('u2'), isNull);
      expect(io.rang, isEmpty);
    });

    test('only its sender takes it back', () async {
      await from(_eve, await unsaid(_eve, 'u3'));
      await from(_bob, await said(_bob, 'u3'));
      expect(live.msg('u3'), isNotNull);
    });

    test('in a group: one taken back late goes, one taken back before it '
        'came never lands, and only its sender takes it back', () async {
      live.group(_g, ['me', _bob, _eve]);
      Future<String> saidIn(String who, String uid) => wrapMessage(
        'call me',
        msgUid: uid,
        groupId: _g,
        sender: asSender(who),
      );
      Future<String> unsaidIn(String who, String uid) =>
          wrapMessage('', unsend: uid, groupId: _g, sender: asSender(who));

      await from(_bob, await saidIn(_bob, 'g1'));
      expect(live.msg('g1')?['group_id'], _g);
      await from(_bob, await unsaidIn(_bob, 'g1'));
      expect(live.msg('g1'), isNull);
      // a second copy of it, as a retry would bring, changes nothing
      await from(_bob, await unsaidIn(_bob, 'g1'));
      expect(live.msg('g1'), isNull);

      await from(_bob, await unsaidIn(_bob, 'g2'));
      await from(_bob, await saidIn(_bob, 'g2'));
      expect(live.msg('g2'), isNull);

      await from(_eve, await unsaidIn(_eve, 'g3'));
      await from(_bob, await saidIn(_bob, 'g3'));
      expect(live.msg('g3'), isNotNull);
      await from(_eve, await unsaidIn(_eve, 'g3'));
      expect(live.msg('g3'), isNotNull);
    });
  });

  group('queued', () {
    late MemDb mem;
    late _Rows db;
    late ArrivalIo io;
    late AppState app;

    setUp(() async {
      mem = MemDb();
      db = _Rows(mem);
      io = ArrivalIo()..down = true;
      await mem.insert('contacts', {
        'halo_id': _bob,
        'onion': '',
        'xpub': 'x-$_bob',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
        'back_paired': 1,
      });
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      app = AppState(io: io, router: router)
        ..myId = 'me'
        ..sendModeForTest = 'fast';
      useDatabasesForTest(db, Session(db));
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    // what was queued long enough ago for the outbox to try it again
    Future<void> age() async {
      for (final r in mem.rows('frames_out')) {
        await mem.update(
          'frames_out',
          {'at': 1},
          where: 'msg_uid = ? AND kind = ?',
          whereArgs: [r['msg_uid'], r['kind']],
        );
      }
    }

    List<UnwrappedMessage> wire() => [
      for (final (_, c) in io.sent)
        unwrapMessage(c.substring('to $_bob '.length)),
    ];

    test('an unsend with no route waits, and goes when one is back', () async {
      await app.unsendInChat(_bob, 'u1');
      await settle();
      expect(io.sent, isEmpty);
      expect(mem.rows('frames_out').single['kind'], kFrameUnsend);
      io.down = false;
      await age();
      await app.drainOutbox();
      await settle();
      expect(wire().single.unsend, 'u1');
      expect(mem.rows('frames_out'), isEmpty);
    });

    test('a reaction too, and the latest word is the one that goes', () async {
      await app.reactInChat(_bob, 'u2', 'x');
      await settle();
      await app.reactInChat(_bob, 'u2', '');
      await settle();
      final q = mem.rows('frames_out').single;
      expect((q['kind'], q['body']), (kFrameReaction, ''));
      io.down = false;
      await age();
      await app.drainOutbox();
      await settle();
      expect(wire().single.reaction!.emoji, '');
      expect(mem.rows('frames_out'), isEmpty);
    });

    test('a word sent leaves a newer one queued', () async {
      await db.queueFrame('u3', kFrameReaction, _bob, 'x');
      await db.queueFrame('u3', kFrameReaction, _bob, 'y');
      await db.dropFrame('u3', kFrameReaction, 'x');
      expect(mem.rows('frames_out').single['body'], 'y');
    });

    test('taken back, nothing else queued for it goes', () async {
      await db.queueEdit('u4', _bob, 'edited');
      await db.queuePin('u4', _bob, true);
      await db.queueFrame('u4', kFrameReaction, _bob, 'x');
      await db.queueFrame('u4', kFrameUnsend, _bob, '');
      expect(mem.rows('edits_out'), isEmpty);
      expect(mem.rows('pins_out'), isEmpty);
      expect(mem.rows('frames_out').single['kind'], kFrameUnsend);
    });
  });
}
