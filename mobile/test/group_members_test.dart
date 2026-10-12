// SPDX-License-Identifier: GPL-3.0-or-later
// a group's frames come from its members and its controls from its admin.
// a message, a poll or a slice with a group id is kept only from a current
// member, as it arrives and when a sealed one is opened. add, remove,
// rename and a new roster for a group here come only from its admin, and
// never past the member cap; leave takes out its sender and no one else. a
// burner room's roster changes only by its creator's key, within the room's
// cap. someone a list names under words held here on another key is seated
// as someone else, and whoever holds the words gets no seat from it. the
// databases, signal and the engine are stand-ins
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        unboundIdOf,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/rooms.dart'
    show
        roomEntry,
        roomFileBody,
        roomFrame,
        roomFramePlace,
        roomSliceDigest,
        roomTextBody;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _a = 'admin-of-group'; // made the group
const _v = 'plain-member-one'; // a member, not the admin
const _x = 'contact-not-member'; // an accepted contact outside the group
const _s = 'request-not-member'; // a request, never accepted
const _h = 'hidden-wreck-tone'; // the hidden group's other member
const _g = 'grp000000001';
const _g2 = 'g2hidden0001';

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final vault = ArrivalRows(HaloContainer.vault);
  final store = ArrivalStore();
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make({bool hidden = false}) async {
    final w = _World();
    w.live.person(_a, onion: 'o-$_a', xpub: 'x-$_a');
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.live.person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.live.group(_g, ['me', _a, _v], admin: _a);
    if (hidden) {
      w.vault.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
      w.vault.group(_g2, ['me', _h], admin: _h);
      await w.store.putHidden(
        _h,
        kHiddenPeer,
        peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
        1,
      );
      await w.store.putHidden(_g2, kHiddenGroup, groupCard(const []), 1);
      await w.store.putMeta('pub', 'pub-A');
    }
    final router = VaultRouter(w.store, ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  // a frame on the onion lane, opened under [who]
  Future<void> from(String who, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await _settle();
  }

  Future<void> control(String who, GroupControl gc, {String g = _g}) async =>
      from(
        who,
        await wrapMessage(
          '',
          groupId: g,
          groupControl: gc,
          sender: asSender(who),
        ),
      );

  List<String> get members => live.members[_g] ?? const [];
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

// a room: my key, the creator's and one more member's
const _roomPub = 'aa';
const _creator = 'cc';
const _m1 = 'ee';
const _room = 'room00000001';

// the room lanes the app opens and drops, and what it sends into a room
class _Engine implements HaloEngine {
  final listens = <String>[];
  final dropBoxes = <String>[];
  final unlistened = <String>[];
  final unlistenedKeys = <String>[];
  final forgotKeys = <String>[];
  final roomSent = <String>[];
  // what went into the room, by member key
  final roomMsgs = <(String, String)>[];

  @override
  void roomSubscribeBg(String priv, String peerPub) => listens.add(peerPub);
  @override
  void roomSubscribeFcBg(String priv) => dropBoxes.add(priv);
  @override
  void roomUnsubscribeBg(String pub) => unlistened.add(pub);
  @override
  void roomUnlistenBg(String priv, String peerPub) =>
      unlistenedKeys.add(peerPub);
  @override
  void roomForgetBg(String priv, List<String> members) =>
      forgotKeys.addAll(members);
  @override
  Future<String> roomSend(String priv, String peerPub, String msg) async {
    roomSent.add(peerPub);
    roomMsgs.add((peerPub, msg));
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

late _Engine _engine;

Future<(ArrivalRows, AppState)> _roomWorld({
  int? cap = 4,
  ArrivalIo? io,
}) async {
  final live = ArrivalRows(HaloContainer.everyday);
  live.group(_room, [_roomPub, _creator, _m1], admin: _creator);
  live.groupRows[_room]!.addAll({
    'room_priv': 'priv',
    'room_pub': _roomPub,
    'expires_at': DateTime.now().millisecondsSinceEpoch + 3600000,
    'creator_pub': _creator,
    'member_cap': cap,
  });
  final router = VaultRouter(ArrivalStore(), ArrivalSeal());
  await router.load();
  useEngineForTest(_engine = _Engine());
  final app = AppState(io: io ?? ArrivalIo(), router: router)..myId = 'me';
  useDatabasesForTest(live, Session(live));
  return (live, app);
}

// a room this phone made, its own key [_mine], with [n] keys besides
final _mine = 'a1' * 32;
String _hexKey(int i) => i.toRadixString(16).padLeft(64, 'b');

Future<(ArrivalRows, AppState)> _myRoom(int n, {int? cap}) async {
  final live = ArrivalRows(HaloContainer.everyday);
  live.group(_room, [_mine, for (var i = 0; i < n; i++) _hexKey(i)]);
  live.groupRows[_room]!.addAll({
    'is_admin': 1,
    'admin_id': _mine,
    'room_priv': 'priv',
    'room_pub': _mine,
    'expires_at': DateTime.now().millisecondsSinceEpoch + 3600000,
    'creator_pub': _mine,
    'member_cap': cap,
  });
  final router = VaultRouter(ArrivalStore(), ArrivalSeal());
  await router.load();
  useEngineForTest(_engine = _Engine());
  final app = AppState(io: ArrivalIo(), router: router)..myId = 'me';
  useDatabasesForTest(live, Session(live));
  return (live, app);
}

// someone off the link knocking on the drop box of the room above
Future<void> _knock(AppState app, String who) async {
  final plain = await wrapMessage(
    '',
    groupId: _room,
    groupControl: const GroupControl(type: 'join'),
    sender: SenderInfo(haloId: who, edPub: '', onion: '', xPub: ''),
  );
  await app.receiveRelay([(peer: 'roomfc:$_mine', cipher: plain)]);
  await _settle();
}

// a frame off the room's lane from the member key [from]
Future<void> _inRoom(AppState app, String from, GroupControl gc) async {
  final plain = await wrapMessage(
    '',
    groupId: _room,
    groupControl: gc,
    sender: SenderInfo(haloId: from, edPub: '', onion: '', xPub: ''),
  );
  await app.receiveRelay([(peer: 'room:$_roomPub:$from', cipher: plain)]);
  await _settle();
}

// a frame off a member's lane of the room above, the one this phone made
Future<void> _inMyRoom(AppState app, String from, GroupControl gc) async {
  final plain = await wrapMessage(
    '',
    groupId: _room,
    groupControl: gc,
    sender: SenderInfo(haloId: from, edPub: '', onion: '', xPub: ''),
  );
  await app.receiveRelay([(peer: 'room:$_mine:$from', cipher: plain)]);
  await _settle();
}

// [n] ids in the shape of three words
List<String> _keys(int n) => [
  for (var i = 0; i < n; i++)
    'member-${String.fromCharCodes([for (final c in i.toRadixString(26).codeUnits) c < 97 ? c + 49 : c + 10])}-here',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('group_members');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('frames with a group id', () {
    test('a message from a contact outside the group is not kept', () async {
      final w = await _World.make();
      await w.from(
        _x,
        await wrapMessage(
          'hi all',
          groupId: _g,
          msgUid: 'n1',
          sender: asSender(_x),
        ),
      );
      expect(w.live.msg('n1'), isNull);
    });

    test('a message from a request outside the group is not kept', () async {
      final w = await _World.make();
      await w.from(
        _s,
        await wrapMessage(
          'hi all',
          groupId: _g,
          msgUid: 'n2',
          sender: asSender(_s),
        ),
      );
      expect(w.live.msg('n2'), isNull);
    });

    test('a poll or a slice from outside the group is not kept', () async {
      final w = await _World.make();
      await w.from(
        _x,
        await wrapMessage(
          'lunch?',
          groupId: _g,
          msgUid: 'p1',
          poll: const PollSpec(options: ['yes', 'no']).toWire(),
          sender: asSender(_x),
        ),
      );
      await w.from(
        _x,
        await wrapMessage(
          '',
          groupId: _g,
          msgUid: 'm1',
          mediaId: 'm1',
          chunkIndex: 0,
          chunkTotal: 2,
          imageB64: base64Encode([1, 2, 3]),
          sender: asSender(_x),
        ),
      );
      expect(w.live.msg('p1'), isNull);
      expect(w.live.chunks, isEmpty);
    });

    test('a member\'s message, poll and slices are kept', () async {
      final w = await _World.make();
      await w.from(
        _v,
        await wrapMessage(
          'hi',
          groupId: _g,
          msgUid: 'k1',
          sender: asSender(_v),
        ),
      );
      await w.from(
        _v,
        await wrapMessage(
          'lunch?',
          groupId: _g,
          msgUid: 'k2',
          poll: const PollSpec(options: ['yes', 'no']).toWire(),
          sender: asSender(_v),
        ),
      );
      await w.from(
        _v,
        await wrapMessage(
          '',
          groupId: _g,
          msgUid: 'k3',
          mediaId: 'k3',
          chunkIndex: 0,
          chunkTotal: 2,
          imageB64: base64Encode([1, 2, 3]),
          sender: asSender(_v),
        ),
      );
      expect(w.live.msg('k1'), isNotNull);
      expect(w.live.msg('k2')?['poll'], isNotNull);
      expect(w.live.chunks.keys, ['k3']);
      // filed under its group, so the group's end takes it
      expect(w.live.chunkGroup['k3'], _g);
    });

    test('a sealed one is kept, once its vault opens, only from a '
        'member', () async {
      final w = await _World.make(hidden: true);
      await w.from(
        _v,
        await wrapMessage(
          'in g2',
          groupId: _g2,
          msgUid: 's1',
          sender: asSender(_v),
        ),
      );
      await w.from(
        _h,
        await wrapMessage(
          'in g2 too',
          groupId: _g2,
          msgUid: 's2',
          sender: asSender(_h),
        ),
      );
      expect(w.store.inbox, hasLength(2));
      useDatabasesForTest(w.live, await Session.withVault(w.live, w.vault));
      await w.app.drainSealed(w.vault, 'priv-A');
      expect(w.vault.msg('s1'), isNull);
      expect(w.vault.msg('s2'), isNotNull);
    });
  });

  group('group controls', () {
    test('a member removes no one, me included', () async {
      final w = await _World.make();
      await w.control(_v, const GroupControl(type: 'remove', members: ['me']));
      await w.control(_v, const GroupControl(type: 'remove', members: [_a]));
      expect(w.live.groupRows.containsKey(_g), isTrue);
      expect(w.members, containsAll(['me', _a, _v]));
    });

    test('the admin removes a member, and me', () async {
      final w = await _World.make();
      await w.control(_a, const GroupControl(type: 'remove', members: [_v]));
      expect(w.members, ['me', _a]);
      await w.control(_a, const GroupControl(type: 'remove', members: ['me']));
      expect(w.live.groupRows.containsKey(_g), isFalse);
    });

    test('a rename is taken from the admin only', () async {
      final w = await _World.make();
      await w.control(_s, const GroupControl(type: 'rename', name: 'other'));
      await w.control(_v, const GroupControl(type: 'rename', name: 'other'));
      expect(w.live.groupRows[_g]!['name'], _g);
      await w.control(_a, const GroupControl(type: 'rename', name: 'lunch'));
      expect(w.live.groupRows[_g]!['name'], 'lunch');
    });

    test('an add is taken from the admin only', () async {
      final w = await _World.make();
      const card = [
        {'h': 'new-face-here', 'o': 'o-new', 'x': 'x-new'},
      ];
      await w.control(
        _v,
        const GroupControl(
          type: 'add',
          members: ['new-face-here'],
          participants: card,
        ),
      );
      expect(w.members, isNot(contains('new-face-here')));
      expect(w.live.people.containsKey('new-face-here'), isFalse);
      await w.control(
        _a,
        const GroupControl(
          type: 'add',
          members: ['new-face-here'],
          participants: card,
        ),
      );
      expect(w.members, contains('new-face-here'));
      expect(w.live.people['new-face-here'], containsPair('xpub', 'x-new'));
    });

    test('words held here on another key: the list\'s person is seated as '
        'someone else, and the holder stays as they were', () async {
      final w = await _World.make();
      const held = 'held-words-here';
      final mine = 'a1' * 32, theirs = 'b2' * 32;
      w.live.person(held, onion: 'o-held', xpub: mine, accepted: 0);
      final other = unboundIdOf([
        5,
        for (var i = 0; i < 64; i += 2)
          int.parse(theirs.substring(i, i + 2), radix: 16),
      ]);
      await w.control(
        _a,
        GroupControl(
          type: 'add',
          members: const [held],
          participants: [
            {'h': held, 'o': 'o-real', 'x': theirs},
          ],
        ),
      );
      expect(w.members, isNot(contains(held)));
      expect(w.members, contains(other));
      expect(w.live.people[other], containsPair('xpub', theirs));
      expect(w.live.people[held], containsPair('xpub', mine));
      expect(w.live.people[held], containsPair('onion', 'o-held'));
      // a new roster seats them the same way
      await w.control(
        _a,
        GroupControl(
          type: 'create',
          name: 'two',
          members: const ['me', _a, held],
          participants: [
            {'h': held, 'o': 'o-real', 'x': theirs},
          ],
        ),
      );
      expect(w.members, ['me', _a, other]);
      // on the key held here, the words are theirs
      await w.control(
        _a,
        GroupControl(
          type: 'add',
          members: const [held],
          participants: [
            {'h': held, 'o': 'o-held', 'x': mine},
          ],
        ),
      );
      expect(w.members, contains(held));
    });

    test('an add past the member cap is not taken', () async {
      final w = await _World.make();
      await w.control(
        _a,
        GroupControl(type: 'add', members: _keys(AppState.kGroupMemberCap)),
      );
      expect(w.members, ['me', _a, _v]);
      await w.control(
        _a,
        GroupControl(type: 'add', members: _keys(AppState.kGroupMemberCap - 3)),
      );
      expect(w.members, hasLength(AppState.kGroupMemberCap));
    });

    test(
      'a new roster for a group here is taken from its admin only',
      () async {
        final w = await _World.make();
        await w.control(
          _x,
          const GroupControl(type: 'create', name: 'mine', members: [_x, 'me']),
        );
        await w.control(
          _v,
          const GroupControl(type: 'create', name: 'mine', members: [_v, 'me']),
        );
        expect(w.members, ['me', _a, _v]);
        expect(w.live.groupRows[_g]!['name'], _g);
        expect(w.live.groupRows[_g]!['admin_id'], _a);
        await w.control(
          _a,
          const GroupControl(type: 'create', name: 'two', members: ['me', _a]),
        );
        expect(w.members, ['me', _a]);
        expect(w.live.groupRows[_g]!['name'], 'two');
      },
    );

    test('a roster past the cap is not taken, even from the admin', () async {
      final w = await _World.make();
      final many = ['me', _a, ..._keys(AppState.kGroupMemberCap)];
      await w.control(
        _a,
        GroupControl(type: 'create', name: 'big', members: many),
      );
      await w.from(
        _a,
        await wrapMessage(
          'hi',
          groupId: _g,
          msgUid: 'r1',
          roster: many,
          sender: asSender(_a),
        ),
      );
      expect(w.members, ['me', _a, _v]);
      // and a new group that big is not made
      await w.control(
        _x,
        GroupControl(type: 'create', name: 'big', members: many),
        g: 'grp000000009',
      );
      expect(w.live.groupRows.containsKey('grp000000009'), isFalse);
    });

    test('a roster without its admin is not taken', () async {
      final w = await _World.make();
      for (final (uid, roster) in [
        ('r1', <String>[]),
        ('r2', ['me', _v]),
      ]) {
        await w.from(
          _a,
          await wrapMessage(
            'still here',
            groupId: _g,
            msgUid: uid,
            roster: roster,
            sender: asSender(_a),
          ),
        );
        expect(w.members, ['me', _a, _v], reason: uid);
      }
      // a list with the admin on it is taken as before
      await w.from(
        _a,
        await wrapMessage(
          'hi',
          groupId: _g,
          msgUid: 'r3',
          roster: ['me', _a],
          sender: asSender(_a),
        ),
      );
      expect(w.members, ['me', _a]);
    });

    test('leave takes out its sender and no one else', () async {
      final w = await _World.make();
      await w.control(_v, const GroupControl(type: 'leave', members: [_a]));
      expect(w.members, ['me', _a]);
    });
  });

  group('a burner room', () {
    test('a member changes nothing of the roster', () async {
      final (live, app) = await _roomWorld();
      await _inRoom(
        app,
        _m1,
        const GroupControl(type: 'remove', members: [_creator]),
      );
      await _inRoom(app, _m1, const GroupControl(type: 'add', members: ['f1']));
      await _inRoom(app, _m1, const GroupControl(type: 'rename', name: 'x'));
      expect(live.members[_room], [_roomPub, _creator, _m1]);
      expect(live.groupRows[_room]!['name'], _room);
    });

    test('its creator adds within the room\'s cap and not past it', () async {
      final (live, app) = await _roomWorld();
      await _inRoom(
        app,
        _creator,
        const GroupControl(type: 'add', members: ['f1', 'f2']),
      );
      expect(live.members[_room], [_roomPub, _creator, _m1]);
      await _inRoom(
        app,
        _creator,
        const GroupControl(type: 'add', members: ['f1']),
      );
      expect(live.members[_room], [_roomPub, _creator, _m1, 'f1']);
      await _inRoom(
        app,
        _creator,
        const GroupControl(
          type: 'create',
          name: _room,
          members: [_roomPub, _creator, _m1, 'f1', 'f2'],
        ),
      );
      expect(live.members[_room], hasLength(4));
    });
  });

  group('a room\'s rosters out of order', () {
    GroupControl roster(int stamp, List<String> keys) =>
        GroupControl(type: 'create', name: _room, members: keys, stamp: stamp);

    test('an older one never replaces a newer one', () async {
      final (live, app) = await _roomWorld(cap: 6);
      await _inRoom(
        app,
        _creator,
        roster(300, [_roomPub, _creator, _m1, 'f1']),
      );
      expect(live.members[_room], [_roomPub, _creator, _m1, 'f1']);
      // the catch-up hands back the roster from before f1 came in
      await _inRoom(app, _creator, roster(200, [_roomPub, _creator, _m1]));
      expect(live.members[_room], [_roomPub, _creator, _m1, 'f1']);
      // and the same one again changes nothing either
      await _inRoom(app, _creator, roster(300, [_roomPub, _creator]));
      expect(live.members[_room], [_roomPub, _creator, _m1, 'f1']);
      // a newer one is taken, whatever it holds
      await _inRoom(app, _creator, roster(400, [_roomPub, _creator, 'f1']));
      expect(live.members[_room], [_roomPub, _creator, 'f1']);
    });

    test(
      'a key that left is not brought back by a roster made before',
      () async {
        final (live, app) = await _roomWorld(cap: 6);
        await _inRoom(app, _m1, const GroupControl(type: 'leave'));
        expect(live.members[_room], [_roomPub, _creator]);
        await _inRoom(
          app,
          _creator,
          roster(100, [_roomPub, _creator, _m1, 'f1']),
        );
        expect(live.members[_room], [_roomPub, _creator, 'f1']);
        // nor one the creator took out
        await _inRoom(
          app,
          _creator,
          const GroupControl(type: 'remove', members: ['f1']),
        );
        await _inRoom(app, _creator, roster(200, [_roomPub, _creator, 'f1']));
        expect(live.members[_room], [_roomPub, _creator]);
      },
    );

    test(
      'the creator stamps every roster it sends, each above the last',
      () async {
        final (live, app) = await _myRoom(1, cap: 6);
        await _knock(app, _hexKey(7));
        await app.ctlPassForTest;
        await _knock(app, _hexKey(8));
        await app.ctlPassForTest;
        final stamps = [
          for (final (to, msg) in _engine.roomMsgs)
            if (to == _hexKey(0)) unwrapMessage(msg).groupControl!.stamp,
        ];
        expect(stamps, hasLength(2));
        expect(stamps.first, isNotNull);
        expect(stamps.last!, greaterThan(stamps.first!));
        expect(live.ctlOut, isEmpty);
      },
    );
    test('a key that left or was taken out does not join again', () async {
      final (live, app) = await _myRoom(1, cap: 6);
      await _knock(app, _hexKey(7));
      await app.ctlPassForTest;
      expect(live.members[_room], [_mine, _hexKey(0), _hexKey(7)]);
      await _inMyRoom(app, _hexKey(7), const GroupControl(type: 'leave'));
      expect(live.members[_room], [_mine, _hexKey(0)]);
      await app.ctlPassForTest;
      final sent = _engine.roomMsgs.length;
      // its join again, off the drop box's catch-up
      await _knock(app, _hexKey(7));
      await app.ctlPassForTest;
      expect(live.members[_room], [_mine, _hexKey(0)]);
      expect(_engine.roomMsgs, hasLength(sent));
      // one the creator took out stays out the same way
      await app.removeMembersFromGroup(_room, [_hexKey(0)]);
      await app.ctlPassForTest;
      await _knock(app, _hexKey(0));
      await app.ctlPassForTest;
      expect(live.members[_room], [_mine]);
      // a new key still comes in
      await _knock(app, _hexKey(8));
      expect(live.members[_room], [_mine, _hexKey(8)]);
    });
  });

  group('a room\'s catch-up out of order', () {
    // a frame as it comes off [from]'s lane, numbered [n] by its sender
    Future<({String peer, String cipher})> frame(
      String from,
      int? n, {
      String text = '',
      String? uid,
      GroupControl? gc,
    }) async => (
      peer: 'room:$_roomPub:$from',
      cipher: roomFrame(
        await wrapMessage(
          text,
          groupId: _room,
          msgUid: uid,
          groupControl: gc,
          sender: SenderInfo(haloId: from, edPub: '', onion: '', xPub: ''),
        ),
        from,
        number: n,
      )!,
    );

    List<String> said(ArrivalRows live) => [
      for (final m in live.msgs)
        if (m['group_id'] == _room) m['plaintext'] as String,
    ];

    test(
      'a member\'s last words land though their leave comes first',
      () async {
        final (live, app) = await _roomWorld();
        await app.receiveRelay([
          await frame(_m1, 3, gc: const GroupControl(type: 'leave')),
          await frame(_m1, 2, text: 'bye', uid: 'u2'),
          await frame(_m1, 1, text: 'thanks all', uid: 'u1'),
        ]);
        await _settle();
        expect(said(live), ['thanks all', 'bye']);
        expect(live.members[_room], [_roomPub, _creator]);
        expect(await live.rosterGone(_room), {_m1});
      },
    );

    // only within one batch: the creator's lane and the member's are walked
    // apart, and a removal handed over first still drops what comes after
    test('what a member wrote before being taken out, in the same batch, '
        'is kept', () async {
      final (live, app) = await _roomWorld();
      await app.receiveRelay([
        await frame(
          _creator,
          4,
          gc: const GroupControl(type: 'remove', members: [_m1]),
        ),
        // from a version that numbers nothing
        await frame(_m1, null, text: 'last one', uid: 'u9'),
      ]);
      await _settle();
      expect(said(live), ['last one']);
      expect(live.members[_room], [_roomPub, _creator]);
    });

    test('each member\'s words in the order they wrote them', () async {
      final (live, app) = await _roomWorld();
      await app.receiveRelay([
        await frame(_m1, 3, text: 'three', uid: 'm3'),
        await frame(_creator, 2, text: 'b', uid: 'c2'),
        await frame(_m1, 1, text: 'one', uid: 'm1'),
        await frame(_creator, 1, text: 'a', uid: 'c1'),
        await frame(_m1, 2, text: 'two', uid: 'm2'),
      ]);
      await _settle();
      // each lane sorted in the places it had, the lanes as they came
      expect(said(live), ['one', 'a', 'two', 'b', 'three']);
    });

    test('this phone numbers its frames, one number to every member', () async {
      final (live, app) = await _myRoom(2);
      await app.sendToGroup(_room, 'first');
      await app.sendToGroup(_room, 'second');
      final numbers = <String, Set<int?>>{};
      for (final (_, msg) in _engine.roomMsgs) {
        numbers
            .putIfAbsent(unwrapMessage(msg).message, () => {})
            .add(roomFramePlace(msg).number);
      }
      expect(numbers.keys, ['first', 'second']);
      expect(_engine.roomMsgs, hasLength(4));
      expect(numbers['first'], {1});
      expect(numbers['second'], {2});
      expect(live.roomSeqs[_room], 2);
    });
  });

  group('taken out, or leaving', () {
    Future<void> said(_World w, String uid) async => w.from(
      _v,
      await wrapMessage('hi', groupId: _g, msgUid: uid, sender: asSender(_v)),
    );

    test('the admin taking me out takes the group and all it held, and the '
        'open screen hears it once', () async {
      final w = await _World.make();
      await said(w, 'h1');
      expect(w.live.msg('h1'), isNotNull);
      await w.control(_a, const GroupControl(type: 'remove', members: ['me']));
      expect(w.live.groupRows.containsKey(_g), isFalse);
      expect(w.live.msgs.where((m) => m['group_id'] == _g), isEmpty);
      expect(w.io.unrang, contains('group:$_g'));
      expect(w.app.takeRemovedFrom(_g), _g);
      expect(w.app.takeRemovedFrom(_g), isNull);
    });

    test('the admin\'s roster without me takes the group, as a remove '
        'would', () async {
      final w = await _World.make();
      await said(w, 'h3');
      await w.from(
        _a,
        await wrapMessage(
          'bye',
          groupId: _g,
          msgUid: 'r9',
          roster: [_a, _v],
          sender: asSender(_a),
        ),
      );
      expect(w.live.groupRows.containsKey(_g), isFalse);
      expect(w.live.msg('r9'), isNull);
      expect(w.live.msgs.where((m) => m['group_id'] == _g), isEmpty);
      expect(w.app.takeRemovedFrom(_g), _g);
    });

    test('a member\'s roster without me takes nothing', () async {
      final w = await _World.make();
      await w.from(
        _v,
        await wrapMessage(
          'hi',
          groupId: _g,
          msgUid: 'r8',
          roster: [_a, _v],
          sender: asSender(_v),
        ),
      );
      expect(w.live.groupRows.containsKey(_g), isTrue);
      expect(w.members, ['me', _a, _v]);
      expect(w.app.takeRemovedFrom(_g), isNull);
    });

    test('leaving with no route still takes the group at once, and the '
        'rest hear it once the route is back', () async {
      final w = await _World.make();
      w.app.sendModeForTest = 'fast';
      w.io.down = true;
      await w.app.leaveGroupAndAnnounce(_g);
      expect(w.live.groupRows.containsKey(_g), isFalse);
      await w.app.ctlPassForTest;
      expect(w.io.sent, isEmpty);
      expect(w.live.ctlTo(_a), ['leave']);
      expect(w.live.ctlTo(_v), ['leave']);
      w.io.down = false;
      for (final r in w.live.ctlOut) {
        r['next_at'] = 0;
      }
      await w.app.drainOutbox();
      await w.app.ctlPassForTest;
      final leaves = [
        for (final (to, c) in w.io.sent)
          if (unwrapMessage(
                c.substring(c.indexOf(' ', 3) + 1),
              ).groupControl?.type ==
              'leave')
            to,
      ];
      expect(leaves, hasLength(2));
      expect(w.live.ctlOut, isEmpty);
    });

    test('someone else taken out leaves nothing to say here', () async {
      final w = await _World.make();
      await w.control(_a, const GroupControl(type: 'remove', members: [_v]));
      expect(w.app.takeRemovedFrom(_g), isNull);
      expect(w.io.unrang, isEmpty);
    });

    test(
      'leaving takes the group and all it held, and tells the rest',
      () async {
        final w = await _World.make();
        await said(w, 'h2');
        w.io.sent.clear();
        await w.app.leaveGroupAndAnnounce(_g);
        expect(w.live.groupRows.containsKey(_g), isFalse);
        expect(w.live.msgs.where((m) => m['group_id'] == _g), isEmpty);
        expect(w.io.unrang, contains('group:$_g'));
        await w.app.ctlPassForTest;
        expect(w.io.sent, hasLength(2));
        expect(w.live.ctlOut, isEmpty);
        // leaving is not being taken out
        expect(w.app.takeRemovedFrom(_g), isNull);
      },
    );

    test('a send into a group no longer here keeps nothing', () async {
      final w = await _World.make();
      await w.live.deleteGroup(_g);
      expect(await w.app.sendToGroup(_g, 'anyone?'), isFalse);
      expect(w.live.msgs, isEmpty);
    });

    test('the creator taking my room key out ends the room here', () async {
      final io = ArrivalIo();
      final (live, app) = await _roomWorld(io: io);
      await _inRoom(
        app,
        _creator,
        const GroupControl(type: 'remove', members: [_roomPub]),
      );
      expect(live.groupRows.containsKey(_room), isFalse);
      expect(_engine.unlistened, [_roomPub]);
      expect(io.unrang, contains('group:$_room'));
      expect(app.takeRemovedFrom(_room), _room);
    });

    test('the creator taking another key out keeps the room', () async {
      final (live, app) = await _roomWorld();
      await _inRoom(
        app,
        _creator,
        const GroupControl(type: 'remove', members: [_m1]),
      );
      expect(live.members[_room], [_roomPub, _creator]);
      expect(app.takeRemovedFrom(_room), isNull);
    });
  });

  group('a burner room\'s life', () {
    test(
      'a room past its end goes from the decoy too, and from its shade',
      () async {
        final io = ArrivalIo();
        final (live, app) = await _roomWorld(io: io);
        final decoy = ArrivalRows(HaloContainer.decoy);
        decoy.group('decoyroom001', ['dd']);
        decoy.groupRows['decoyroom001']!.addAll({
          'room_priv': 'p2',
          'room_pub': 'dd',
          'expires_at': DateTime.now().millisecondsSinceEpoch - 1000,
        });
        useDatabasesForTest(live, Session(decoy));
        await app.sweepRooms();
        expect(decoy.groupRows, isEmpty);
        expect(io.unrang, ['group:decoyroom001']);
        // the everyday room has time left; a quiet room never was listened to
        expect(live.groupRows.containsKey(_room), isTrue);
        expect(_engine.unlistened, isEmpty);
      },
    );

    // a restore or a removal closed it to put other files in its place:
    // opened again here it would be an empty database the session keeps
    test('a decoy shut while its files are swapped is left shut', () async {
      final io = ArrivalIo();
      final (live, app) = await _roomWorld(io: io);
      final decoy = ArrivalRows(HaloContainer.decoy)..shut = true;
      decoy.group('decoyroom001', ['dd']);
      decoy.groupRows['decoyroom001']!.addAll({
        'room_priv': 'p2',
        'room_pub': 'dd',
        'expires_at': DateTime.now().millisecondsSinceEpoch - 1000,
      });
      useDatabasesForTest(live, Session(decoy));
      await app.sweepRooms();
      expect(decoy.groupRows.keys, ['decoyroom001']);
      expect(io.unrang, isEmpty);
    });

    test(
      'a decoy opening after the rooms were counted still ends its rooms',
      () async {
        final live = ArrivalRows(HaloContainer.everyday);
        final router = VaultRouter(ArrivalStore(), ArrivalSeal());
        await router.load();
        useEngineForTest(_engine = _Engine());
        final app = AppState(io: ArrivalIo(), router: router)..myId = 'me';
        useDatabasesForTest(live, Session(live));
        await app.subscribeRoomsAtBoot();
        expect(app.roomTimerArmed, isFalse);
        final decoy = ArrivalRows(HaloContainer.decoy);
        decoy.group('decoyroom001', ['dd']);
        decoy.groupRows['decoyroom001']!.addAll({
          'room_priv': 'p2',
          'room_pub': 'dd',
          'expires_at': DateTime.now().millisecondsSinceEpoch + 3600000,
        });
        useDatabasesForTest(live, Session(decoy));
        app.containersOpenedForTest();
        await pumpEventQueue();
        expect(app.roomTimerArmed, isTrue);
      },
    );

    test('a new mode lands its relays before any runner starts again', () {
      final src = File('lib/main.dart').readAsStringSync();
      final mode = src.substring(src.indexOf('Future<void> setSendMode('));
      final init = mode.indexOf('engine.nostrInit(relaysFor(m));');
      expect(init, isNonNegative);
      expect(init, lessThan(mode.indexOf('await resubscribe();')));
    });

    test('a new mode listens to every room again', () async {
      final (_, app) = await _myRoom(2);
      await app.resubscribe();
      await app.resubscribe();
      expect(_engine.listens, [_hexKey(0), _hexKey(1), _hexKey(0), _hexKey(1)]);
      expect(_engine.dropBoxes, ['priv', 'priv']);
    });

    test(
      'a room with no cap of its own takes no one past a group\'s cap',
      () async {
        final (live, app) = await _myRoom(AppState.kGroupMemberCap - 2);
        final last = _hexKey(900);
        await _knock(app, last);
        expect(live.members[_room], hasLength(AppState.kGroupMemberCap));
        expect(_engine.roomSent, isNotEmpty);
        _engine.roomSent.clear();
        await _knock(app, _hexKey(901));
        expect(live.members[_room], hasLength(AppState.kGroupMemberCap));
        expect(live.members[_room], isNot(contains(_hexKey(901))));
        // only the one turned away hears, and only that it is full
        expect(_engine.roomSent, [_hexKey(901)]);
      },
    );
  });
  group('a room key gone', () {
    // a frame as it comes off [from]'s lane
    Future<({String peer, String cipher})> frame(
      String from, {
      String text = '',
      String? uid,
      GroupControl? gc,
      String room = _roomPub,
    }) async => (
      peer: 'room:$room:$from',
      cipher: roomFrame(
        await wrapMessage(
          text,
          groupId: _room,
          msgUid: uid,
          groupControl: gc,
          sender: SenderInfo(haloId: from, edPub: '', onion: '', xPub: ''),
        ),
        from,
      )!,
    );

    Future<void> take(AppState app, ({String peer, String cipher}) f) async {
      await app.receiveRelay([f]);
      await _settle();
    }

    List<String> said(ArrivalRows live) => [
      for (final m in live.msgs)
        if (m['group_id'] == _room) m['plaintext'] as String,
    ];

    // how a remove names a message whole in one frame
    String said1(String uid, String words) =>
        roomEntry(_room, uid, roomTextBody(message: words));

    // the creator's remove of [_m1], naming the messages it had from them
    GroupControl remove(List<String> entries) => GroupControl(
      type: 'remove',
      members: const [_m1],
      lateUids: entries.isEmpty ? null : {_m1: entries},
    );

    test('one that leaves is no longer listened to, and the room\'s end '
        'forgets every key it listened to', () async {
      final (live, app) = await _roomWorld();
      await app.subscribeRoomsAtBoot();
      expect(_engine.listens, [_creator, _m1]);
      await take(app, await frame(_m1, gc: const GroupControl(type: 'leave')));
      expect(live.members[_room], [_roomPub, _creator]);
      expect(_engine.unlistenedKeys, [_m1]);
      expect(live.roomKeys[_room]![_m1]!.out, 2);
      // the creator ends it here: the key that left is forgotten too
      await take(
        app,
        await frame(
          _creator,
          gc: const GroupControl(type: 'remove', members: [_roomPub]),
        ),
      );
      expect(live.groupRows.containsKey(_room), isFalse);
      expect(_engine.forgotKeys.toSet(), containsAll([_creator, _m1]));
      expect(live.roomKeys[_room], isNull);
    });

    test('one taken out with nothing owed here is no longer listened to at '
        'once', () async {
      final (live, app) = await _roomWorld();
      await app.subscribeRoomsAtBoot();
      await take(app, await frame(_m1, text: 'hi', uid: 'u1'));
      await take(app, await frame(_creator, gc: remove([said1('u1', 'hi')])));
      expect(_engine.unlistenedKeys, [_m1]);
      expect(live.roomKeys[_room]![_m1]!.owed, isEmpty);
    });

    test('what the creator had from one taken out still lands, each once and '
        'in any order, and nothing else of theirs does', () async {
      final (live, app) = await _roomWorld();
      await app.subscribeRoomsAtBoot();
      await take(app, await frame(_m1, text: 'one', uid: 'u1'));
      await take(
        app,
        await frame(
          _creator,
          gc: remove([
            said1('u1', 'one'),
            said1('u2', 'two'),
            said1('u3', 'three'),
          ]),
        ),
      );
      expect(live.members[_room], [_roomPub, _creator]);
      expect(await live.rosterGone(_room), {_m1});
      // two of theirs are still on the way: still listened to
      expect(_engine.unlistenedKeys, isEmpty);
      await take(app, await frame(_m1, text: 'three', uid: 'u3'));
      // a uid that came already, again with other words
      await take(app, await frame(_m1, text: 'changed', uid: 'u3'));
      // a new one in a gap the creator never named, as a changed app sends
      await take(app, await frame(_m1, text: 'forged', uid: 'u9'));
      // only messages: a control of theirs changes nothing
      await take(
        app,
        await frame(
          _m1,
          gc: const GroupControl(type: 'rename', name: 'x'),
        ),
      );
      expect(_engine.unlistenedKeys, isEmpty);
      // a named uid with other words, before the real one came
      await take(app, await frame(_m1, text: 'not two', uid: 'u2'));
      expect(said(live), ['one', 'three']);
      await take(app, await frame(_m1, text: 'two', uid: 'u2'));
      expect(said(live), ['one', 'three', 'two']);
      expect(live.members[_room], [_roomPub, _creator]);
      // the last one owed is in
      expect(_engine.unlistenedKeys, [_m1]);
      // and once stopped nothing more comes, a named one neither
      await take(app, await frame(_m1, text: 'late', uid: 'u2'));
      expect(said(live), ['one', 'three', 'two']);
    });

    test('a file the creator had from one taken out still lands as it was, '
        'and one under a named uid with other bytes does not', () async {
      final (live, app) = await _roomWorld();
      await app.subscribeRoomsAtBoot();
      final real = [
        base64Encode([1, 2, 3]),
        base64Encode([4, 5, 6]),
      ];
      final other = [
        real[0],
        base64Encode([6, 6, 6]),
      ];
      Future<String> named(String uid) async => roomEntry(
        _room,
        uid,
        roomFileBody(
          total: 2,
          slices: await roomSliceDigest(2, (i) async => real[i]),
          caption: '',
        ),
      );
      Future<void> slices(String uid, List<String> b64) async {
        for (var i = 0; i < 2; i++) {
          await take(app, (
            peer: 'room:$_roomPub:$_m1',
            cipher: roomFrame(
              await wrapMessage(
                '',
                groupId: _room,
                msgUid: uid,
                mediaId: uid,
                chunkIndex: i,
                chunkTotal: 2,
                imageB64: b64[i],
                sender: SenderInfo(haloId: _m1, edPub: '', onion: '', xPub: ''),
              ),
              _m1,
            )!,
          ));
        }
      }

      await take(
        app,
        await frame(
          _creator,
          gc: remove([await named('f1'), await named('f2')]),
        ),
      );
      // f2 again with one slice changed: held until whole, then not taken
      await slices('f2', other);
      expect(live.msg('f2'), isNull);
      expect(live.chunks['f2'] ?? const {}, isEmpty);
      await slices('f1', real);
      expect(live.msg('f1'), isNotNull);
      // and once filed, the same again is not a second one
      await slices('f1', real);
      expect(live.msgs.where((m) => m['msg_uid'] == 'f1'), hasLength(1));
    });

    test('a remove from a version before it lets nothing more in', () async {
      final (live, app) = await _roomWorld();
      await app.subscribeRoomsAtBoot();
      await take(app, await frame(_m1, text: 'one', uid: 'u1'));
      await take(app, await frame(_creator, gc: remove(const [])));
      expect(_engine.unlistenedKeys, [_m1]);
      await take(app, await frame(_m1, text: 'two', uid: 'u2'));
      expect(said(live), ['one']);
    });

    test('messages owed that never come are not waited on for long, and the '
        'room is read again when the wait ends', () async {
      final (live, app) = await _roomWorld();
      app.roomLateWait = const Duration(milliseconds: 50);
      await app.subscribeRoomsAtBoot();
      await take(app, await frame(_creator, gc: remove([said1('u5', 'five')])));
      expect(_engine.unlistenedKeys, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _settle();
      expect(_engine.unlistenedKeys, [_m1]);
      expect(live.roomKeys[_room]![_m1]!.out, 2);
      await take(app, await frame(_m1, text: 'five', uid: 'u5'));
      expect(said(live), isEmpty);
    });

    test(
      'a lane still open at a stop has its files gone at the next start',
      () async {
        final (live, app) = await _roomWorld();
        await app.subscribeRoomsAtBoot();
        await take(
          app,
          await frame(_creator, gc: remove([said1('u5', 'five')])),
        );
        expect(_engine.unlistenedKeys, isEmpty);
        // the app stopped before the wait ended, and starts again
        final router = VaultRouter(ArrivalStore(), ArrivalSeal());
        await router.load();
        final again = AppState(io: ArrivalIo(), router: router)..myId = 'me';
        await again.subscribeRoomsAtBoot();
        expect(_engine.unlistenedKeys, [_m1]);
        expect(live.roomKeys[_room]![_m1]!.out, 2);
        await take(again, await frame(_m1, text: 'five', uid: 'u5'));
        expect(said(live), isEmpty);
      },
    );

    test(
      'the creator\'s remove names the last messages it took from each key',
      () async {
        final (live, app) = await _myRoom(2);
        await app.subscribeRoomsAtBoot();
        for (var n = 1; n <= 4; n++) {
          await take(
            app,
            await frame(_hexKey(0), text: 'm$n', uid: 'k$n', room: _mine),
          );
        }
        await app.removeMembersFromGroup(_room, [_hexKey(0), _hexKey(1)]);
        final sent = [
          for (final r in live.ctlOut)
            GroupControl.fromWire(jsonDecode(r['ctl'] as String))!,
        ];
        expect(sent, isNotEmpty);
        for (final gc in sent) {
          expect(gc.type, 'remove');
          // a key nothing was taken from names nothing
          expect(gc.lateUids, {
            _hexKey(0): [
              for (var n = 1; n <= 4; n++)
                roomEntry(_room, 'k$n', roomTextBody(message: 'm$n')),
            ],
          });
        }
        expect(await live.rosterGone(_room), {_hexKey(0), _hexKey(1)});
        // nothing owed here: both stop at once
        expect(_engine.unlistenedKeys, [_hexKey(0), _hexKey(1)]);
      },
    );

    test('a message taken while the creator takes its sender out is named in '
        'the remove', () async {
      final (live, app) = await _myRoom(1);
      await app.subscribeRoomsAtBoot();
      live.saveGate = Completer<void>();
      final coming = take(
        app,
        await frame(_hexKey(0), text: 'last', uid: 'k9', room: _mine),
      );
      // the message is past the door and about to be kept
      await _settle();
      expect(live.msg('k9'), isNull);
      await app.removeMembersFromGroup(_room, [_hexKey(0)]);
      // the remove as it waits to go, or as it went
      final gcs = [
        for (final r in live.ctlOut)
          GroupControl.fromWire(jsonDecode(r['ctl'] as String))!,
        for (final (_, msg) in _engine.roomMsgs)
          if (unwrapMessage(msg).groupControl?.type == 'remove')
            unwrapMessage(msg).groupControl!,
      ];
      live.saveGate!.complete();
      await coming;
      expect(live.msg('k9'), isNotNull);
      expect(gcs, isNotEmpty);
      final gc = gcs.first;
      expect(gc.lateUids?[_hexKey(0)], [
        roomEntry(_room, 'k9', roomTextBody(message: 'last')),
      ]);
    });
  });
}
