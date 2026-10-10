// SPDX-License-Identifier: GPL-3.0-or-later
// a message taken back or burned before it was read takes its unread mark
// and its own notification with it. one taken back before it came never
// lands. an unsend or a reaction made with no route queues like an edit
// and goes once one is back. the database methods are the real ones over
// rows kept in maps; the wire and signal are stand-ins
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        kFrameReaction,
        kFrameUnsend,
        queueGap,
        useDatabasesForTest;
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
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
}

// a route that counts what it is asked, and answers when told while slow
class _SlowIo extends ArrivalIo {
  final waits = <Completer<String>>[];
  var asked = 0;
  var slow = false;

  @override
  Future<String> relaySend(String xPub, String cipher) async {
    asked++;
    if (!slow) return super.relaySend(xPub, cipher);
    final c = Completer<String>();
    waits.add(c);
    final r = await c.future;
    if (r == 'ok') sent.add(('relay $xPub', cipher));
    return r;
  }
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

    test('an edit, a reaction and a pin before their message go in once it '
        'lands, and only from someone who may make them', () async {
      live.group(_g, ['me', _bob, _eve]);
      await from(
        _bob,
        await wrapMessage(
          '',
          edit: const EditFrame(targetUid: 'e1', newText: 'call me later'),
          sender: asSender(_bob),
        ),
      );
      // eve may not edit what bob wrote
      await from(
        _eve,
        await wrapMessage(
          '',
          edit: const EditFrame(targetUid: 'e1', newText: 'not bob'),
          sender: asSender(_eve),
        ),
      );
      await from(
        _bob,
        await wrapMessage(
          '',
          reaction: const ReactionFrame(targetUid: 'e1', emoji: '👍'),
          sender: asSender(_bob),
        ),
      );
      await from(
        _bob,
        await wrapMessage(
          '',
          pin: const PinFrame(targetUid: 'e1', pinned: true),
          sender: asSender(_bob),
        ),
      );
      expect(live.msg('e1'), isNull);
      await from(_bob, await said(_bob, 'e1'));
      final m = live.msg('e1')!;
      expect(m['plaintext'], 'call me later');
      expect(m['pinned'], 1);
      expect(live.reactions['e1'], {_bob: '👍'});

      // in a group, another member's reaction waits for the message too
      await from(
        _eve,
        await wrapMessage(
          '',
          groupId: _g,
          reaction: const ReactionFrame(targetUid: 'g9', emoji: '🎉'),
          sender: asSender(_eve),
        ),
      );
      await from(
        _bob,
        await wrapMessage(
          'call me',
          msgUid: 'g9',
          groupId: _g,
          sender: asSender(_bob),
        ),
      );
      expect(live.reactions['g9'], {_eve: '🎉'});
    });

    Future<String> edit(String who, String uid, String text) => wrapMessage(
      '',
      edit: EditFrame(targetUid: uid, newText: text),
      sender: asSender(who),
    );
    Future<String> react(String who, String uid, String emoji) => wrapMessage(
      '',
      reaction: ReactionFrame(targetUid: uid, emoji: emoji),
      sender: asSender(who),
    );

    test('the last of a burst of early edits is the one that shows, in the '
        'chat and the shade', () async {
      for (var i = 0; i < 40; i++) {
        await from(_bob, await edit(_bob, 'b1', 'take $i'));
      }
      await from(_bob, await said(_bob, 'b1'));
      expect(live.msg('b1')!['plaintext'], 'take 39');
      expect(io.shown.last.$2, 'take 39');
    });

    test('early frames keep to a size, and one sender keeps to a share of '
        'it', () async {
      await from(_eve, await react(_eve, 'e0', '👍'));
      for (var i = 0; i < 70; i++) {
        await from(_bob, await react(_bob, 'r$i', '🎉'));
      }
      for (final uid in ['e0', 'r0', 'r69']) {
        await from(
          uid == 'e0' ? _eve : _bob,
          await said(uid == 'e0' ? _eve : _bob, uid),
        );
      }
      expect(live.reactions['e0'], {_eve: '👍'});
      expect(live.reactions['r0'], isNull);
      expect(live.reactions['r69'], {_bob: '🎉'});
      // big ones: the oldest go first
      final big = 'x' * 20000;
      for (var i = 0; i < 60; i++) {
        await from(_eve, await edit(_eve, 'big$i', '$big $i'));
      }
      await from(_eve, await said(_eve, 'big0'));
      await from(_eve, await said(_eve, 'big59'));
      expect(live.msg('big0')!['plaintext'], 'call me');
      expect(live.msg('big59')!['plaintext'], '$big 59');
    });

    test('a stranger\'s early frame is not kept for their message', () async {
      live.person('stray-one-here', accepted: 0, backPaired: 0);
      await from('stray-one-here', await react('stray-one-here', 's1', '👍'));
      await from('stray-one-here', await said('stray-one-here', 's1'));
      expect(live.msg('s1'), isNotNull);
      expect(live.reactions['s1'], isNull);
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
    late _SlowIo io;
    late AppState app;

    setUp(() async {
      mem = MemDb();
      db = _Rows(mem);
      io = _SlowIo()..down = true;
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

    test('one that keeps failing waits longer each time, not every '
        'pass', () async {
      await app.unsendInChat(_bob, 'u6');
      await settle();
      await age();
      final before = io.asked;
      await app.drainOutbox();
      await settle();
      final once = io.asked;
      expect(once, greaterThan(before));
      for (var i = 0; i < 4; i++) {
        await app.drainOutbox();
        await settle();
      }
      expect(io.asked, once);
      // a route back: it still waits its turn, then goes
      io.down = false;
      await app.drainOutbox();
      await settle();
      expect(io.sent, isEmpty);
      app.frameWaitsUpForTest();
      await app.drainOutbox();
      await settle();
      expect(wire().single.unsend, 'u6');
      expect(mem.rows('frames_out'), isEmpty);
    });

    test('the wait doubles from 45 seconds up to ten minutes', () {
      expect(
        [for (var i = 0; i < 7; i++) queueGap(i)],
        [45000, 90000, 180000, 360000, 600000, 600000, 600000],
      );
      expect(queueGap(70), 600000);
    });

    test('an edit made while the one before still goes waits for it, and '
        'the older one landing leaves it queued', () async {
      io
        ..down = false
        ..slow = true;
      await app.editInChat(_bob, 'u7', 'one');
      await settle();
      expect(io.waits, hasLength(1));
      await app.editInChat(_bob, 'u7', 'two');
      await settle();
      // nothing alongside it
      expect(io.waits, hasLength(1));
      expect(mem.rows('edits_out').single['new_text'], 'two');
      io.waits.single.complete('ok');
      await settle();
      expect(mem.rows('edits_out').single['new_text'], 'two');
      // and the newer one goes right after
      expect(io.waits, hasLength(2));
      io.waits.last.complete('ok');
      await settle();
      expect([for (final m in wire()) m.edit!.newText], ['one', 'two']);
      expect(mem.rows('edits_out'), isEmpty);
    });

    test('an older wording that lands leaves a newer one queued', () async {
      await db.queueEdit('u8', _bob, 'one');
      await db.queueEdit('u8', _bob, 'two');
      await db.dropEdit('u8', newText: 'one');
      expect(mem.rows('edits_out').single['new_text'], 'two');
      await db.dropEdit('u8', newText: 'two');
      expect(mem.rows('edits_out'), isEmpty);
    });

    test('a word sent leaves a newer one queued', () async {
      await db.queueFrame('u3', kFrameReaction, _bob, 'x');
      await db.queueFrame('u3', kFrameReaction, _bob, 'y');
      await db.dropFrame('u3', kFrameReaction, _bob, 'x');
      expect(mem.rows('frames_out').single['body'], 'y');
    });

    test('the same uid in two chats queues apart and goes apart', () async {
      // the uid of what came in is its sender's to pick
      const other = 'carol-other-chat';
      await db.queueFrame('u5', kFrameReaction, _bob, 'x');
      await db.queueFrame('u5', kFrameReaction, other, 'x');
      expect(mem.rows('frames_out'), hasLength(2));
      await db.dropFrame('u5', kFrameReaction, _bob, 'x');
      expect(mem.rows('frames_out').single['peer_id'], other);
      await db.queueFrame('u5', kFrameReaction, _bob, 'y');
      await db.queueFrame('u5', kFrameUnsend, _bob, '');
      expect([
        for (final r in mem.rows('frames_out')) (r['peer_id'], r['kind']),
      ], unorderedEquals([(other, kFrameReaction), (_bob, kFrameUnsend)]));
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
