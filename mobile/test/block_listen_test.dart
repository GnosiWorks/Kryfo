// SPDX-License-Identifier: GPL-3.0-or-later
// a block keeps listening on the person's relay address, so what they send
// while it holds comes in to be dropped and the relay keeps nothing for an
// unblock. everyone blocked, a stranger too, is listened for when every
// contact is subscribed again, until the block is older than the relays
// keep anything, and never on a key someone else is heard on. the engine
// calls are the app's own stand-in, the rows kept in maps
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, kBlockListenFor, useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _c = 'contact-we-know';
const _o = 'other-contact';

class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.everyday);

  @override
  Future<void> dropHeld(String peerId) async => calls.add('dropHeld:$peerId');

  @override
  Future<Set<String>> blockedIds() async => {
    for (final p in people.values)
      if (p['blocked'] == 1) p['halo_id'] as String,
  };
}

// a vault shut while the block is made: it cannot be written
class _ShutVault extends ArrivalRows {
  _ShutVault() : super(HaloContainer.vault);

  @override
  Future<void> lightBurnsFrom(String haloId) async {
    calls.add('lightBurnsFrom:$haloId');
    throw StateError('shut');
  }
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

  test('a block keeps listening for them', () async {
    final w = await _World.make();
    expect(w.io.listened, containsAll(['x-$_c', 'x-$_o']));
    await w.app.block(_c);
    expect(w.live.people[_c]!['blocked'], 1);
    expect(w.io.unheard, isEmpty);
  });

  // their rows there start a day after they came, or at its next sweep:
  // the block and all that follows it happen here whatever it does
  test('a vault that cannot be written leaves the block whole', () async {
    final w = await _World.make();
    final vault = _ShutVault();
    useDatabasesForTest(w.live, await Session.withVault(w.live, vault));
    await w.app.block(_c);
    expect(vault.calls, contains('lightBurnsFrom:$_c'));
    expect(w.live.people[_c]!['blocked'], 1);
    expect(w.live.calls, contains('dropHeld:$_c'));
    expect(w.io.unheard, isEmpty);
  });

  test('an unblock listens for them', () async {
    final w = await _World.make();
    await w.app.block(_c);
    w.io.listened.clear();
    await w.app.unblock(_c);
    expect(w.live.people[_c]!['blocked'], 0);
    expect(w.io.listened, ['x-$_c']);
  });

  test('a blocked person is listened for when everyone is subscribed '
      'again, a stranger blocked from a request too', () async {
    final w = await _World.make();
    const stranger = 'stranger-blocked-here';
    w.live.person(stranger, accepted: 0, xpub: 'x-$stranger');
    await w.app.block(_c);
    await w.app.block(stranger);
    w.io.listened.clear();
    await w.app.resubscribe();
    expect(w.io.listened, unorderedEquals(['x-$_c', 'x-$_o', 'x-$stranger']));
  });

  test('a block older than the relays keep anything is listened on no '
      'more, and is not taken up again', () async {
    final w = await _World.make();
    await w.app.block(_c);
    final now = DateTime.now().millisecondsSinceEpoch;
    // a day short of the bound: still heard
    w.live.blockSpans[_c] = [(now - kBlockListenFor + 86400000, null)];
    await w.app.unlistenOldBlocks();
    expect(w.io.unheard, isEmpty);
    w.live.blockSpans[_c] = [(now - kBlockListenFor - 1000, null)];
    await w.app.unlistenOldBlocks();
    expect(w.io.unheard, ['x-$_c']);
    w.io.listened.clear();
    await w.app.resubscribe();
    await w.app.subscribePeer(_c);
    expect(w.io.listened, ['x-$_o']);
    // an unblock hears them again
    await w.app.unblock(_c);
    expect(w.io.listened, ['x-$_o', 'x-$_c']);
  });

  test('a blocked row never takes a key someone else is heard on', () async {
    final w = await _World.make();
    w.live.people[_c]!['xpub'] = 'x-$_o';
    await w.app.block(_c);
    await w.app.resubscribe();
    w.io.tries.clear();
    w.io.opens['from-o'] = (_o, 'halo/1:{"m":"hi","u":"o1"}');
    await w.app.receiveRelay([(peer: 'x-$_o', cipher: 'from-o')]);
    expect(w.io.tries.first, '$_o from-o');
  });

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

  test('the call an unlisten makes is one the engine exports', () {
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
