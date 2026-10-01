// SPDX-License-Identifier: GPL-3.0-or-later
// a block stops listening on the person's relay address, which also takes
// that address's files; an unblock listens again. a blocked person is not
// listened for when every contact is subscribed again, and a key someone
// else is heard on stays. the engine calls are the app's own stand-in, the
// rows kept in maps
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _c = 'contact-we-know';
const _o = 'other-contact';

class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.everyday);

  @override
  Future<void> setBlocked(String haloId, bool blocked) async {
    calls.add('setBlocked:$haloId');
    people[haloId]!['blocked'] = blocked ? 1 : 0;
  }

  @override
  Future<void> dropHeld(String peerId) async => calls.add('dropHeld:$peerId');

  @override
  Future<Set<String>> blockedIds() async => {
    for (final p in people.values)
      if (p['blocked'] == 1) p['halo_id'] as String,
  };
}

class _World {
  final live = _Rows();
  final io = ArrivalIo();
  late AppState app;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_c, onion: 'o-$_c', xpub: 'x-$_c');
    w.live.person(_o, onion: 'o-$_o', xpub: 'x-$_o');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    await w.app.resubscribe();
    return w;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a block stops listening for them, and only them', () async {
    final w = await _World.make();
    expect(w.io.listened, containsAll(['x-$_c', 'x-$_o']));
    await w.app.block(_c);
    expect(w.live.people[_c]!['blocked'], 1);
    expect(w.io.unheard, ['x-$_c']);
  });

  test('an unblock listens for them again', () async {
    final w = await _World.make();
    await w.app.block(_c);
    w.io.listened.clear();
    await w.app.unblock(_c);
    expect(w.live.people[_c]!['blocked'], 0);
    expect(w.io.listened, ['x-$_c']);
  });

  test(
    'a blocked person is left out when everyone is subscribed again',
    () async {
      final w = await _World.make();
      await w.app.block(_c);
      w.io.listened.clear();
      await w.app.resubscribe();
      expect(w.io.listened, ['x-$_o']);
    },
  );

  test('the blocked page lists everyone blocked, a stranger blocked from '
      'a request too, and an unblock takes them off it', () async {
    final w = await _World.make();
    const stranger = 'stranger-asked-once';
    const member = 'member-key-only';
    w.live.person(stranger, accepted: 0);
    w.live.person(member, accepted: 0);
    w.live.people[member]!['nickname'] = 'Theo';
    await w.app.block(_c);
    await w.app.block(stranger);
    await w.app.block(member);
    final list = await w.app.blockedContacts();
    expect([for (final b in list) b.haloId], [_c, member, stranger]);
    expect(list[1].nickname, 'Theo');
    await w.app.unblock(stranger);
    expect(
      [for (final b in await w.app.blockedContacts()) b.haloId],
      [_c, member],
    );
  });

  test('a key someone else is heard on stays', () async {
    final w = await _World.make();
    // their row names a key the other one is heard on
    w.live.people[_c]!['xpub'] = 'x-$_o';
    await w.app.block(_c);
    expect(w.io.unheard, ['x-$_c']);
  });

  test('the call a block makes is one the engine exports', () {
    final app = File('lib/main.dart').readAsStringSync();
    final call = RegExp(
      r"void nostrUnsubscribeBg\(String \w+\) => _background\(\s*"
      r"_roomFfiOnIsolate\('(\w+)'",
    ).firstMatch(app)?.group(1);
    expect(call, 'HaloNostrUnsubscribe');
    final engine = [
      for (final f in Directory('../engine').listSync())
        if (f is File && f.path.endsWith('.go')) f.readAsStringSync(),
    ].join('\n');
    expect(engine, contains('//export $call\nfunc $call('));
  });
}
