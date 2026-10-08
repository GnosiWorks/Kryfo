// SPDX-License-Identifier: GPL-3.0-or-later
// a frame with no uid and nothing to draw, the ack an accept sends, opens the
// door for the one who sent it and is never kept as a message: a blank row
// counts as unread, and two in one chat share a row key. a text with no uid,
// as an older client sends one, is still kept. the engine calls are the
// app's own stand-in, the rows kept in maps
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _c = 'contact-who-accepted';

Future<(AppState, ArrivalRows, ArrivalIo)> _world() async {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  live.person(_c, onion: 'o-$_c', xpub: 'x-$_c', backPaired: 0);
  final router = VaultRouter(ArrivalStore(), ArrivalSeal());
  await router.load();
  final app = AppState(io: io, router: router)..myId = 'me';
  useDatabasesForTest(live, Session(live));
  return (app, live, io);
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

  test('an accept ack opens the door and leaves no row', () async {
    final (app, live, io) = await _world();
    for (final n in [1, 2]) {
      io.opens['ack-$n'] = (_c, 'halo/1:{"m":"","h":"$_c","o":"o-$_c"}');
      await app.receiveRelay([(peer: 'x-$_c', cipher: 'ack-$n')]);
    }
    expect(live.calls, contains('markBackPaired:$_c'));
    expect(live.msgs, isEmpty);
  });

  test('the face on an empty frame is still taken', () async {
    final (app, live, io) = await _world();
    io.opens['ack'] = (_c, 'halo/1:{"m":"","h":"$_c","av":7}');
    await app.receiveRelay([(peer: 'x-$_c', cipher: 'ack')]);
    expect(live.calls, contains('setContactAvatar:$_c'));
    expect(live.msgs, isEmpty);
  });

  test('a text with no uid is still kept', () async {
    final (app, live, io) = await _world();
    io.opens['old'] = (_c, 'halo/1:{"m":"from an older phone"}');
    await app.receiveRelay([(peer: 'x-$_c', cipher: 'old')]);
    expect(
      [for (final m in live.msgs) m['plaintext']],
      ['from an older phone'],
    );
  });
}
