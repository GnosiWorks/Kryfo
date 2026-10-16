// SPDX-License-Identifier: GPL-3.0-or-later
// what a chat that blocks screenshots keeps out of everywhere else, and how
// it stands up to a phone that pushes it. the shade, the list and the
// search show none of it. someone blocked holds nothing. a phone flipping
// the block fast moves the window and the line at an even pace. a chat shut
// away in the vault still says what an open one would. the stamp is one
// width whatever it is, and none from far ahead is taken. a decoy's switch
// works as anyone's, on its own phone
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show AppState, HaloDb, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _c = 'calm-orbit-lantern';

// the receive path's rows, with the block read off the person's row
class _Arrivals extends ArrivalRows {
  _Arrivals(super.container);
  var shotsReads = 0;
  @override
  Future<ChatShots> shotsOf(String peer) async {
    shotsReads++;
    return ChatShots.ofRow(people[peer], quiet: container.quiet);
  }

  @override
  Future<bool> takeShots(
    String peer,
    ShotsWord? word, {
    required bool counts,
    int? written,
  }) async => false;
}

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

Future<void> _person(MemDb mem, String id, {int can = 0, int blocked = 0}) =>
    mem.insert('contacts', {
      'halo_id': id,
      'onion': 'o-$id',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': blocked,
      'shots_can': can,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('chat_shots_review');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<(AppState, _Arrivals, ArrivalIo)> world({bool blocks = true}) async {
    final live = _Arrivals(HaloContainer.everyday);
    final io = ArrivalIo();
    live.person(_c, onion: 'o-$_c', xpub: 'x-$_c');
    live.people[_c]!
      ..['shots_on'] = blocks ? 1 : 0
      ..['shots_at'] = 5
      ..['shots_can'] = 9;
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
    return (app, live, io);
  }

  group('nothing of a blocking chat outside it', () {
    for (final blocks in [true, false]) {
      test(
        blocks
            ? 'the shade says only that a message came'
            : 'a chat that does not block rings as before',
        () async {
          final (app, _, io) = await world(blocks: blocks);
          final w = await wrapMessage(
            'the plan for friday',
            msgUid: 'm1',
            sender: asSender(_c),
          );
          io.opens['c1'] = (_c, w);
          await app.receiveRelay([(peer: 'x-$_c', cipher: 'c1')]);
          final (title, body) = io.shown.single;
          if (blocks) {
            expect((title, body), ('Kryfo', l10n.notificationsNewMessage));
          } else {
            expect(body, 'the plan for friday');
          }
        },
      );

      test(
        blocks
            ? 'the list shows a plain line, and knows it blocks'
            : 'the list shows the words of a chat that does not block',
        () async {
          final (app, live, io) = await world(blocks: blocks);
          final w = await wrapMessage(
            'the plan for friday',
            msgUid: 'm1',
            sender: asSender(_c),
          );
          io.opens['c1'] = (_c, w);
          await app.receiveRelay([(peer: 'x-$_c', cipher: 'c1')]);
          await app.refreshContacts();
          final row = app.contacts.single;
          expect(
            row.preview,
            blocks ? l10n.notificationsNewMessage : 'the plan for friday',
          );
          expect(row.shotsBlocking, blocks);
          expect(app.shotsBlocksChat(_c), blocks);
        },
      );
    }

    test('someone blocked holds nothing, on any screen', () async {
      final (app, live, _) = await world();
      live.people[_c]!['blocked'] = 1;
      await app.refreshContacts();
      expect(app.shotsBlocksChat(_c), isFalse);
      expect(ChatShots.ofRow(live.people[_c]).blocking, isFalse);
      // and the switch does nothing for them
      await app.setChatShots(_c, false);
      expect(live.people[_c]!['shots_on'], 1);
    });
  });

  group('the wire', () {
    test('a group\'s frame is never read for', () async {
      final (app, live, _) = await world();
      final g = await wrapMessage('hi', groupId: 'g1', sender: asSender('me'));
      expect(await app.shotsOnWire(_c, g), g);
      expect(await app.shotsOnWire(_c, 'plain'), 'plain');
      expect(live.shotsReads, 0);
      final one = await wrapMessage('hi', sender: asSender('me'));
      await app.shotsOnWire(_c, one);
      expect(live.shotsReads, 1);
    });

    test('and the last word sent, once its rows are shut away', () async {
      final (app, live, _) = await world();
      final w = await wrapMessage('', sender: asSender('me'));
      final open = unwrapMessage(await app.shotsOnWire(_c, w)).shots!;
      expect((open.on, open.at), (true, 5));
      live.people.remove(_c);
      final shut = unwrapMessage(await app.shotsOnWire(_c, w)).shots!;
      expect((shut.on, shut.at), (true, 5));
    });

    test('the stamp is one width, set or not', () {
      String ss(ShotsWord w) => shotsStamped('halo/1:{"m":""}', w);
      final never = ss(const ShotsWord(on: false, at: 0));
      final set = ss(const ShotsWord(on: true, at: 1760000000000));
      expect(never.length, set.length);
      // what every 1:1 envelope grows by
      expect(never.length - 'halo/1:{"m":""}'.length, 33);
      expect(ShotsWord.fromWire({'o': 1, 'a': 1760000000000}), isNull);
      expect(ShotsWord.fromWire({'o': 1, 'a': '176000000000'}), isNull);
    });

    test('a change never stamps past what the wire carries', () {
      expect(shotsNextStamp(kShotsStampMost, 5), kShotsStampMost);
      expect(shotsNextStamp(kShotsStampMost + 9, 5), kShotsStampMost);
    });
  });

  group('a phone that pushes it', () {
    test('a stamp more than a day ahead of this clock is not taken', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      await _person(mem, _c, can: 9);
      final now = DateTime.now().millisecondsSinceEpoch;
      final ahead = now + const Duration(days: 2).inMilliseconds;
      await db.takeShots(
        _c,
        ShotsWord(on: true, at: ahead),
        counts: true,
        written: now,
      );
      expect((await db.shotsOf(_c)).on, isFalse);
      await db.takeShots(
        _c,
        ShotsWord(on: true, at: now + 1000),
        counts: true,
        written: now,
      );
      expect((await db.shotsOf(_c)).on, isTrue);
    });

    test('a burst of theirs keeps one line, saying where it ended', () async {
      final mem = MemDb();
      final db = _Rows(mem);
      await _person(mem, _c, can: 9);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.takeShots(_c, ShotsWord(on: true, at: now), counts: false);
      final first = await db.shotsOf(_c);
      expect(first.by, kShotsByThem);
      await mem.update('contacts', {'shots_when': first.when - 1000});
      await db.takeShots(_c, ShotsWord(on: false, at: now + 1), counts: false);
      await db.takeShots(_c, ShotsWord(on: true, at: now + 2), counts: false);
      await db.takeShots(_c, ShotsWord(on: false, at: now + 3), counts: false);
      final s = await db.shotsOf(_c);
      expect((s.on, s.by, s.when), (false, kShotsByThem, first.when - 1000));
      // past the minute, the next change has a line of its own
      await mem.update('contacts', {
        'shots_when': now - const Duration(minutes: 2).inMilliseconds,
      });
      await db.takeShots(_c, ShotsWord(on: true, at: now + 4), counts: false);
      expect((await db.shotsOf(_c)).when, greaterThanOrEqualTo(now));
    });

    test('on covers the window at once, off waits out the gap, and the '
        'last word wins', () async {
      final told = <bool>[];
      final pacer = ShotsPacer(
        told.add,
        gap: const Duration(milliseconds: 300),
      );
      Future<void> wait(int ms) =>
          Future<void>.delayed(Duration(milliseconds: ms));
      pacer.want(true);
      expect(told, [true]);
      // their phone flips it fast
      pacer.want(false);
      pacer.want(true);
      pacer.want(false);
      await wait(100);
      expect(told, [true]);
      await wait(350);
      expect(told, [true, false]);
      // on again comes at once
      pacer.want(true);
      expect(told, [true, false, true]);
      // a tap of this phone's own goes at once both ways
      pacer.want(false, now: true);
      expect(told, [true, false, true, false]);
      // and the screen going lets go at once
      pacer.want(true);
      pacer.release();
      expect(told, [true, false, true, false, true, false]);
      await wait(500);
      expect(told, hasLength(6));
    });
  });

  test(
    'a decoy\'s switch works on its own phone, and nothing leaves',
    () async {
      final mem = MemDb();
      final decoy = _Rows(mem, HaloContainer.decoy);
      await _person(mem, _c);
      final io = ArrivalIo();
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      final app = AppState(io: io, router: router)..myId = 'me';
      useDatabasesForTest(_Rows(MemDb()), Session(decoy));
      final s = await decoy.shotsOf(_c);
      expect(s.peerCan, isTrue);
      await app.setChatShots(_c, true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((await decoy.shotsOf(_c)).blocking, isTrue);
      expect(io.sent, isEmpty);
    },
  );

  group('a chat shut away in the vault', () {
    // a phone whose hidden chat with h is on the router's list, its card
    // as the vault left it at the close, and no row of it here
    Future<(AppState, ArrivalIo, ArrivalStore)> shut({ShotsWord? card}) async {
      final live = _Arrivals(HaloContainer.everyday);
      final io = ArrivalIo();
      final store = ArrivalStore();
      await store.putHidden(
        'h',
        kHiddenPeer,
        peerCard(RouterCard('h', 'o-h', 'x-h', backPaired: true, shots: card)),
        1,
      );
      await store.putMeta('pub', 'pub-A');
      final router = VaultRouter(store, ArrivalSeal());
      await router.load();
      final app = AppState(io: io, router: router)..myId = 'me';
      useDatabasesForTest(live, Session(live));
      return (app, io, store);
    }

    Future<ShotsWord> wire(AppState app) async => unwrapMessage(
      await app.shotsOnWire(
        'h',
        await wrapMessage('', deliveredUid: 'r', sender: asSender('me')),
      ),
    ).shots!;

    test('a fresh start says what the card kept at the close, even when '
        'their phone leaves the block out', () async {
      final (app, io, store) = await shut(
        card: const ShotsWord(on: true, at: 1760000000000),
      );
      io.opens['c1'] = (
        'h',
        await wrapMessage('hi', msgUid: 'm1', sender: asSender('h')),
      );
      await app.receiveOnion(['c1']);
      expect(store.inbox, hasLength(1));
      final w = await wire(app);
      expect((w.on, w.at), (true, 1760000000000));
    });

    test(
      'a newer word that came sealed goes, one from far ahead does not',
      () async {
        final (app, io, store) = await shut(
          card: const ShotsWord(on: false, at: 5),
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        final far = now + const Duration(days: 3).inMilliseconds;
        io.opens['c1'] = (
          'h',
          shotsStamped(
            await wrapMessage('hi', msgUid: 'm1', sender: asSender('h')),
            ShotsWord(on: true, at: far),
          ),
        );
        await app.receiveOnion(['c1']);
        var w = await wire(app);
        expect((w.on, w.at), (false, 5));
        io.opens['c2'] = (
          'h',
          shotsStamped(
            await wrapMessage('again', msgUid: 'm2', sender: asSender('h')),
            ShotsWord(on: true, at: now),
          ),
        );
        await app.receiveOnion(['c2']);
        w = await wire(app);
        expect((w.on, w.at), (true, now));
      },
    );

    test('the card keeps the word, one width set or not', () {
      final set = peerCard(
        const RouterCard('h', 'o', 'x', shots: ShotsWord(on: true, at: 9)),
      );
      final none = peerCard(const RouterCard('h', 'o', 'x'));
      expect(set.length, none.length);
      final back = RouterCard.fromJson(jsonDecode(set))!.shots!;
      expect((back.on, back.at), (true, 9));
      expect(RouterCard.fromJson(jsonDecode(none))!.shots!.at, 0);
    });
  });

  test('a word refused by their row never goes back out', () async {
    final (app, live, io) = await world(blocks: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final far = now + const Duration(days: 3).inMilliseconds;
    io.opens['c1'] = (
      _c,
      shotsStamped(
        await wrapMessage('hi', msgUid: 'm1', sender: asSender(_c)),
        ShotsWord(on: true, at: far),
      ),
    );
    await app.receiveRelay([(peer: 'x-$_c', cipher: 'c1')]);
    final out = unwrapMessage(
      await app.shotsOnWire(_c, await wrapMessage('', sender: asSender('me'))),
    ).shots!;
    expect((out.on, out.at), (false, 5));
  });

  test('a room says nothing of itself in the shade', () async {
    final (app, live, io) = await world(blocks: false);
    for (final (g, room) in [('room-1', true), ('group-1', false)]) {
      live.group(g, ['me', _c]);
      if (room) live.groupRows[g]!['room_pub'] = 'pub-room';
      io.opens['g-$g'] = (
        _c,
        await wrapMessage(
          'the plan in $g',
          msgUid: 'm-$g',
          groupId: g,
          sender: asSender(_c),
        ),
      );
      await app.receiveRelay([(peer: 'x-$_c', cipher: 'g-$g')]);
    }
    final bodies = [for (final (_, b) in io.shown) b];
    // not even its name
    expect([for (final (t, _) in io.shown) t], contains('Kryfo'));
    expect([for (final (t, _) in io.shown) t], isNot(contains('room-1')));
    expect(bodies.where((b) => b.contains('the plan in room-1')), isEmpty);
    expect(bodies, contains(l10n.notificationsNewMessage));
    expect(
      bodies.where((b) => b.contains('the plan in group-1')),
      hasLength(1),
    );
  });
}
