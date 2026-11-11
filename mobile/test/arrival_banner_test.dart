// SPDX-License-Identifier: GPL-3.0-or-later
// a message for another chat while the app is in front: the banner is asked
// for with what the notification says, and the shade's copy goes without
// sound. no banner, it rings as before. the chat on screen asks for
// neither. the databases, signal and the engine are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show AppState, claimChat, releaseChat, useDatabasesForTest, AppStateReceive;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _x = 'calm-river-lamp';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late ArrivalRows live;
  late ArrivalIo io;
  late AppState app;
  var n = 0;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('arrival_banner');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    lockState.openForTest();
    live = ArrivalRows(HaloContainer.everyday)
      ..person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    live.people[_x]!['nickname'] = 'Lena';
    io = ArrivalIo();
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
  });

  tearDown(() {
    releaseChat(_x);
    docs.deleteSync(recursive: true);
  });

  Future<void> text(String uid) async {
    final c = 'c${n++}';
    io.opens[c] = (
      _x,
      await wrapMessage('see you', msgUid: uid, sender: asSender(_x)),
    );
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('in front, on another chat: a banner, and the shade quietly', () async {
    io.bannerShows = true;
    await text('m1');
    expect(io.banners, hasLength(1));
    final b = io.banners.single;
    expect(b.chat, _x);
    expect(b.title, 'Lena');
    expect(b.body, 'see you');
    expect(b.avatarSeed, _x);
    expect(io.rang, [_x]);
    expect(io.silents, [true]);
  });

  test('no banner: it rings as before', () async {
    await text('m1');
    expect(io.banners, isEmpty);
    expect(io.rang, [_x]);
    expect(io.silents, [false]);
  });

  test('the chat on screen asks for neither', () async {
    io.bannerShows = true;
    claimChat(_x);
    await text('m1');
    expect(io.banners, isEmpty);
    expect(io.rang, isEmpty);
  });
}
