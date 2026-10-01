// SPDX-License-Identifier: GPL-3.0-or-later
// a file in slices from someone not accepted counts toward the two they
// get into requests, from its first slice. a slice has its place inside
// its file, a file has one sender, and a recall drops only that sender's
// slices. a stranger's unfinished file is kept a day, a contact's a week.
// what waits unfinished has a ceiling, all senders together: past it whole
// files go, the one whose last slice came longest ago first, and a finished
// message is never touched.
// the arrivals run against stand-ins, the database rules against rows kept
// in maps
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, HaloDb, useDatabasesForTest;
import 'package:kryfo/media_resend.dart'
    show kMaxSlices, kUnfinishedBytes, kUnfinishedFiles, sliceWeight;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _c = 'contact-we-know'; // accepted
const _s = 'stranger-in-requests'; // a request, never accepted
const _v = 'plain-member-one'; // accepted, in the group
const _g = 'grp000000001';

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_c, onion: 'o-$_c', xpub: 'x-$_c');
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.live.group(_g, ['me', _c, _v], admin: _c);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<void> from(String who, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> slice(
    String who,
    String mid, {
    int index = 0,
    int total = 100,
    String? group,
  }) async => from(
    who,
    await wrapMessage(
      '',
      msgUid: mid,
      mediaId: mid,
      chunkIndex: index,
      chunkTotal: total,
      groupId: group,
      fileB64: base64Encode(List.filled(300, index % 256)),
      fileName: 'x.bin',
      sender: asSender(who),
    ),
  );

  Future<void> text(String who, String uid) async =>
      from(who, await wrapMessage('hello', msgUid: uid, sender: asSender(who)));
}

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('slice_cap');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('a stranger', () {
    test('keeps no more files in flight than the cap', () async {
      final w = await _World.make();
      for (var m = 0; m < 20; m++) {
        await w.slice(_s, 'big$m', total: 100000);
      }
      expect(w.live.chunks.keys, ['big0', 'big1']);
    });

    test('still sends the rest of a file in flight', () async {
      final w = await _World.make();
      await w.slice(_s, 'f1');
      await w.slice(_s, 'f2');
      await w.slice(_s, 'f1', index: 1);
      expect(w.live.chunks['f1']!.keys, [0, 1]);
    });

    test('with two files in flight, a message is held back', () async {
      final w = await _World.make();
      await w.slice(_s, 'f1');
      await w.slice(_s, 'f2');
      await w.text(_s, 't1');
      expect(w.live.msg('t1'), isNull);
      expect(w.live.held, isNotEmpty);
    });

    test('files they post in a group leave their own chat its two', () async {
      final w = await _World.make();
      const m = 'member-not-added';
      const g = 'grp000000002';
      w.live.person(m, onion: 'o-$m', xpub: 'x-$m', accepted: 0);
      w.live.group(g, ['me', _c, m], admin: _c);
      await w.slice(m, 'gf1', group: g);
      await w.slice(m, 'gf2', group: g);
      expect(w.live.chunks.keys, ['gf1', 'gf2']);
      await w.text(m, 'd1');
      expect(w.live.msg('d1'), isNotNull);
      expect(w.live.held, isEmpty);
    });

    test('with one message kept, one file comes in and no second', () async {
      final w = await _World.make();
      await w.text(_s, 't1');
      await w.slice(_s, 'f1');
      await w.slice(_s, 'f2');
      expect(w.live.msg('t1'), isNotNull);
      expect(w.live.chunks.keys, ['f1']);
    });
  });

  test('a contact has no such cap', () async {
    final w = await _World.make();
    for (var m = 0; m < 5; m++) {
      await w.slice(_c, 'c$m');
    }
    expect(w.live.chunks.length, 5);
  });

  group('past the cap on unfinished files', () {
    // what one slice from [_World.slice] weighs
    final one = sliceWeight(base64Encode(List.filled(300, 0)).length);

    test('the file quiet longest goes, and a finished message stays', () async {
      final w = await _World.make();
      w.live.unfinishedBytes = 3 * one;
      await w.slice(_c, 'done', total: 2);
      await w.slice(_c, 'done', index: 1, total: 2);
      expect(w.live.msg('done'), isNotNull);
      for (var m = 0; m < 4; m++) {
        await w.slice(_c, 'f$m');
      }
      expect(w.live.chunks.keys, ['f1', 'f2', 'f3']);
      expect(w.live.msg('done'), isNotNull);
    });

    test('a file still coming in stays over one that went quiet', () async {
      final w = await _World.make();
      w.live.unfinishedBytes = 3 * one;
      await w.slice(_c, 'f0');
      await w.slice(_c, 'f1');
      await w.slice(_c, 'f0', index: 1);
      await w.slice(_c, 'f2');
      expect(w.live.chunks.keys.toSet(), {'f0', 'f2'});
    });

    test('a file past it on its own does not stay', () async {
      final w = await _World.make();
      w.live.unfinishedBytes = one - 1;
      await w.slice(_c, 'f0');
      expect(w.live.chunks, isEmpty);
    });

    test('from every sender together', () async {
      final w = await _World.make();
      w.live.unfinishedBytes = 2 * one;
      await w.slice(_c, 'a');
      await w.slice(_s, 'b');
      await w.slice(_v, 'c', group: _g);
      expect(w.live.chunks.keys, ['b', 'c']);
    });

    test('is two hundred megabytes', () {
      expect(kUnfinishedBytes, 200 * 1024 * 1024);
    });
  });

  group('a slice', () {
    test('outside its file is dropped', () async {
      final w = await _World.make();
      await w.slice(_c, 'r1', index: 3, total: 3);
      await w.slice(_c, 'r2', index: -1, total: 3);
      await w.slice(_c, 'r3', total: kMaxSlices + 1);
      expect(w.live.chunks, isEmpty);
    });

    test('of a file someone else is sending is dropped', () async {
      final w = await _World.make();
      await w.slice(_c, 'g1', group: _g);
      await w.slice(_v, 'g1', index: 1, group: _g);
      expect(w.live.chunks['g1']!.keys, [0]);
    });

    test('recalled by another sender stays', () async {
      final w = await _World.make();
      await w.slice(_c, 'g1', group: _g);
      await w.from(
        _v,
        await wrapMessage('', unsend: 'g1', groupId: _g, sender: asSender(_v)),
      );
      expect(w.live.chunks['g1'], isNotNull);
      await w.from(
        _c,
        await wrapMessage('', unsend: 'g1', groupId: _g, sender: asSender(_c)),
      );
      expect(w.live.chunks['g1'], isNull);
    });
  });

  test('a receipt names who sent it', () async {
    final w = await _World.make();
    await w.from(
      _c,
      await wrapMessage('', deliveredUid: 'mine1', sender: asSender(_c)),
    );
    expect(w.live.delivered, ['mine1 from $_c']);
  });

  group('the database', () {
    Future<_Rows> rows() async {
      final db = _Rows(MemDb());
      await db.mem.insert('contacts', {
        'halo_id': _c,
        'onion': 'o',
        'xpub': 'x',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
      });
      await db.mem.insert('contacts', {
        'halo_id': _s,
        'onion': 'o',
        'xpub': 'x',
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 0,
      });
      await db.mem.insert('group_members', {
        'group_id': _g,
        'halo_id': _v,
        'joined_at': 1,
      });
      return db;
    }

    Future<void> chunk(
      _Rows db,
      String mid,
      int idx,
      String from,
      int at, {
      int size = 1,
    }) => db.mem.insert('media_chunks', {
      'media_id': mid,
      'idx': idx,
      'slice': 'x' * size,
      'total': 9,
      'at': at,
      'sender': from,
    });

    test('past the cap whole unfinished files go, the one quiet longest '
        'first, and nothing else is touched', () async {
      final db = await rows();
      await chunk(db, 'old', 0, _c, 1, size: 100);
      await chunk(db, 'old', 1, _c, 2, size: 100);
      await chunk(db, 'busy', 0, _c, 1, size: 100);
      await chunk(db, 'busy', 1, _c, 9, size: 100);
      await chunk(db, 'mid', 0, _s, 5, size: 100);
      for (final mid in ['old', 'busy']) {
        await db.mem.insert('media_wants', {
          'media_id': mid,
          'peer_id': _c,
          'total': 9,
          'can_resend': 1,
          'last_at': 1,
        });
      }
      db.mem.log.clear();
      final w = sliceWeight(100);
      expect(await db.trimUnfinishedMedia(bytes: 3 * w), {'old'});
      final left = {
        for (final r in db.mem.rows('media_chunks')) r['media_id'] as String,
      };
      expect(left, {'busy', 'mid'});
      expect(
        [for (final r in db.mem.rows('media_wants')) r['media_id']],
        ['busy'],
      );
      expect(db.mem.log.toSet(), {'delete:media_chunks', 'delete:media_wants'});
      expect(await db.trimUnfinishedMedia(bytes: 3 * w), isEmpty);
      expect(await db.trimUnfinishedMedia(bytes: 3 * w, files: 1), {'mid'});
    });

    test('a file being put together stays past the cap', () async {
      final db = await rows();
      await chunk(db, 'a', 0, _c, 1, size: 100);
      await chunk(db, 'b', 0, _c, 2, size: 100);
      expect(await db.trimUnfinishedMedia(bytes: 0, keep: {'a'}), {'b'});
      expect(db.mem.rows('media_chunks').single['media_id'], 'a');
    });

    test('keeps its count as slices come and go', () async {
      final db = await rows();
      final w = sliceWeight(10);
      // counted once, then kept up
      expect(await db.trimUnfinishedMedia(bytes: 0), isEmpty);
      await db.putMediaChunk('a', 0, 'x' * 10, 9, null, from: _c);
      // a slice sent again weighs once
      await db.putMediaChunk('a', 0, 'x' * 10, 9, null, from: _c);
      await db.putMediaChunk('b', 0, 'x' * 10, 9, null, from: _c);
      expect(await db.trimUnfinishedMedia(bytes: 2 * w), isEmpty);
      await db.dropMediaChunks('a');
      await db.putMediaChunk('c', 0, 'x' * 10, 9, null, from: _c);
      expect(await db.trimUnfinishedMedia(bytes: 2 * w), isEmpty);
      await db.putMediaChunk('d', 0, 'x' * 10, 9, null, from: _c);
      expect(await db.trimUnfinishedMedia(bytes: 2 * w), {'b'});
      final left = {
        for (final r in db.mem.rows('media_chunks')) r['media_id'] as String,
      };
      expect(left, {'c', 'd'});
    });

    test('a sweep holds what is left to the cap', () async {
      final db = await rows();
      final now = DateTime(2026, 9, 28, 12);
      final at = now.millisecondsSinceEpoch;
      for (var m = 0; m <= kUnfinishedFiles; m++) {
        await chunk(
          db,
          'f${m.toString().padLeft(3, '0')}',
          0,
          _c,
          at - 999 + m,
        );
      }
      await db.sweepMediaChunks(now: now);
      final left = {
        for (final r in db.mem.rows('media_chunks')) r['media_id'] as String,
      };
      expect(left, hasLength(kUnfinishedFiles));
      expect(left, isNot(contains('f000')));
    });

    test('counts one sender\'s files in flight', () async {
      final db = await rows();
      await chunk(db, 'a', 0, _s, 1);
      await chunk(db, 'a', 1, _s, 1);
      await chunk(db, 'b', 0, _s, 1);
      await chunk(db, 'c', 0, _c, 1);
      // a file in a group has no want row
      await chunk(db, 'g', 0, _s, 1);
      for (final (id, who) in [('a', _s), ('b', _s), ('c', _c)]) {
        await db.mem.insert('media_wants', {
          'media_id': id,
          'peer_id': who,
          'total': 9,
          'can_resend': 1,
          'last_at': 1,
        });
      }
      expect(await db.filesInFlightFrom(_s), 2);
      expect(await db.filesInFlightFrom(_s, except: 'a'), 1);
      expect(await db.mediaChunkSender('c'), _c);
      expect(await db.mediaChunkSender('none'), isNull);
    });

    test('drops a recalled file only for its own sender', () async {
      final db = await rows();
      await chunk(db, 'a', 0, _c, 1);
      expect(await db.dropMediaChunks('a', from: _s), 0);
      expect(await db.dropMediaChunks('a', from: _c), 1);
    });

    test('keeps a stranger\'s unfinished file a day, a contact\'s or a '
        'member\'s a week', () async {
      final db = await rows();
      final now = DateTime(2026, 9, 28, 12);
      final twoDays = now
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;
      final anHour = now
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      await chunk(db, 'old', 0, _s, twoDays);
      await chunk(db, 'old', 1, _s, anHour);
      await chunk(db, 'new', 0, _s, anHour);
      await chunk(db, 'friend', 0, _c, twoDays);
      await chunk(db, 'member', 0, _v, twoDays);
      await db.sweepMediaChunks(now: now);
      final left = {
        for (final r in db.mem.rows('media_chunks')) r['media_id'] as String,
      };
      expect(left, {'new', 'friend', 'member'});
      final week = now.add(const Duration(days: 6));
      await db.sweepMediaChunks(now: week);
      expect(db.mem.rows('media_chunks'), isEmpty);
    });
  });
}
