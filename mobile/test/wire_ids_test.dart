// SPDX-License-Identifier: GPL-3.0-or-later
// an id that comes over the wire to stand for someone has the shape of
// one: three words, or the id of one filed on their own key, and in a room
// a room key. anything else in a member list, a participant card, an
// admin's roster or an introduction is left out. the databases, signal and
// the engine are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, unboundIdOf, useDatabasesForTest, wireIdShaped;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _a = 'admin-of-group';
const _v = 'plain-member-one';
const _g = 'grp000000001';
const _odd = ['group:grp000000001', 'Not An Id', 'a-b', 'x-y-z-w', ''];

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_a, onion: 'o-$_a', xpub: 'x-$_a');
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.live.group(_g, ['me', _a, _v], admin: _a);
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
}

List<Map<String, String>> _cards(List<String> ids) => [
  for (final h in ids) {'h': h, 'o': 'o-$h', 'x': 'x-$h'},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('wire_ids');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test('the shapes an id takes', () {
    expect(wireIdShaped('amber-still-river', room: false), isTrue);
    expect(wireIdShaped(unboundIdOf([5, 1, 2]), room: false), isTrue);
    for (final h in _odd) {
      expect(wireIdShaped(h, room: false), isFalse, reason: h);
    }
    expect(wireIdShaped('ab' * 32, room: true), isTrue);
    expect(wireIdShaped('amber-still-river', room: true), isFalse);
    expect(wireIdShaped('ab' * 33, room: true), isFalse);
  });

  test('a new group keeps only members and cards shaped as ids', () async {
    final w = await _World.make();
    const g = 'grp000000002';
    await w.control(
      _a,
      GroupControl(
        type: 'create',
        name: 'lunch',
        members: ['me', _a, 'new-face-here', ..._odd],
        participants: _cards(['new-face-here', ..._odd]),
      ),
      g: g,
    );
    expect(w.live.members[g], ['me', _a, 'new-face-here']);
    expect(w.live.people.keys, {_a, _v, 'new-face-here'});
  });

  test('an add and an admin\'s roster take only ids', () async {
    final w = await _World.make();
    await w.control(
      _a,
      GroupControl(
        type: 'add',
        members: ['new-face-here', ..._odd],
        participants: _cards(['new-face-here', ..._odd]),
      ),
    );
    expect(w.live.members[_g], ['me', _a, _v, 'new-face-here']);
    await w.from(
      _a,
      await wrapMessage(
        'hi',
        msgUid: 'r1',
        groupId: _g,
        roster: ['me', _a, _v, ..._odd],
        rosterParticipants: _cards(_odd),
        sender: asSender(_a),
      ),
    );
    expect(w.live.members[_g], ['me', _a, _v]);
    expect(w.live.people.keys, {_a, _v, 'new-face-here'});
  });

  test('an introduction of something that is not an id is dropped', () async {
    final w = await _World.make();
    await w.from(
      _a,
      await wrapMessage(
        '',
        intro: const IntroFrame(
          haloId: 'group:grp000000001',
          onion: 'o-x',
          xPub: 'x-x',
        ),
        sender: asSender(_a),
      ),
    );
    expect(w.live.people.keys, {_a, _v});
    expect(w.live.vouches, isEmpty);
  });
}
