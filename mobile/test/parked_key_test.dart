// SPDX-License-Identifier: GPL-3.0-or-later
// a deleted contact who writes again is filed under the key their session
// runs on. a frame that names someone else's key opens nothing, and a key
// an accepted chat holds stays that chat's. signal and the database are
// stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        useDatabasesForTest,
        useEngineForTest,
        AppStateReceive;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

// a friend, and someone whose chat was deleted, their session kept
const _v = 'plain-friend-here';
const _p = 'gone-friend-here';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late ArrivalRows live;
  late ArrivalIo io;
  late AppState app;
  var n = 0;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('parked_key');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    live = ArrivalRows(HaloContainer.everyday)
      ..person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    io = ArrivalIo()..sessions = [_v, _p];
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
    await app.subscribeKnown();
  });
  tearDown(() => docs.deleteSync(recursive: true));

  // a frame of [from]'s that says its sender's key is [claims]
  Future<String> frame(String from, {String? claims}) async {
    final cipher = 'cipher-${n++}';
    io.opens[cipher] = (
      from,
      await wrapMessage(
        'hi again',
        msgUid: 'u-$cipher',
        sender: SenderInfo(
          haloId: from,
          edPub: 'ed-$from',
          onion: 'o-$from',
          xPub: claims ?? 'x-$from',
        ),
      ),
    );
    return cipher;
  }

  // who a frame on the friend's lane is tried as first
  Future<String> laneTriedAs() async {
    final c = await frame(_v);
    io.tries.clear();
    await app.receiveRelay([(peer: 'x-$_v', cipher: c)]);
    return io.tries.first.split(' ').first;
  }

  for (final lane in ['onion', 'relay']) {
    test('$lane: one claiming a friend\'s key is not filed', () async {
      final c = await frame(_p, claims: 'x-$_v');
      if (lane == 'onion') {
        await app.receiveOnion([c]);
      } else {
        await app.receiveRelay([(peer: 'x-$_v', cipher: c)]);
      }
      expect(live.people.containsKey(_p), isFalse);
      expect(live.msgs.where((m) => m['peer_id'] == _p), isEmpty);
      expect(await laneTriedAs(), _v);
    });

    test('$lane: one on their own key is filed under the session\'s', () async {
      io.sessionKeys[_p] = 'x-$_p';
      final c = await frame(_p);
      if (lane == 'onion') {
        await app.receiveOnion([c]);
      } else {
        await app.receiveRelay([(peer: 'x-$_v', cipher: c)]);
      }
      expect(live.people[_p]?['xpub'], 'x-$_p');
      expect(live.people[_p]?['accepted'], 0);
      // the friend's lane stays the friend's
      expect(await laneTriedAs(), _v);
    });
  }

  test('a request on a friend\'s key never takes it at start', () async {
    live.person(_p, onion: 'o-$_p', xpub: 'x-$_v', accepted: 0);
    await app.subscribeKnown();
    expect(await laneTriedAs(), _v);
  });
}
