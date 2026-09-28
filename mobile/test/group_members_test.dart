// SPDX-License-Identifier: GPL-3.0-or-later
// a group's frames come from its members and its controls from its admin.
// a message, a poll or a slice with a group id is kept only from a current
// member, as it arrives and when a sealed one is opened. add, remove,
// rename and a new roster for a group here come only from its admin, and
// never past the member cap; leave takes out its sender and no one else. a
// burner room's roster changes only by its creator's key, within the room's
// cap. the databases, signal and the engine are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/polls.dart';
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

class _Engine implements HaloEngine {
  @override
  void roomSubscribeBg(String priv, String peerPub) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<(ArrivalRows, AppState)> _roomWorld({int? cap = 4}) async {
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
  useEngineForTest(_Engine());
  final app = AppState(io: ArrivalIo(), router: router)..myId = 'me';
  useDatabasesForTest(live, Session(live));
  return (live, app);
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

List<String> _keys(int n) => [for (var i = 0; i < n; i++) 'k$i'];

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
}
