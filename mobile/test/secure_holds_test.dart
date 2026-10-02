// SPDX-License-Identifier: GPL-3.0-or-later
// the shield is held once per screen that wants it. a room opened over
// another room lets go of its own hold when it closes, and the room under
// it stays shielded until it closes too
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show AppState;
import 'package:kryfo/router.dart';

import 'arrival_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<bool> told;

  setUp(() {
    told = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
          call,
        ) async {
          if (call.method == 'setSecure') {
            told.add((call.arguments as Map)['on'] as bool);
          }
          return null;
        });
  });

  Future<AppState> make() async {
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    return AppState(io: ArrivalIo(), router: router);
  }

  test('a room closing over another keeps the shield on', () async {
    final app = await make();
    // room a, then room b over it
    await app.forceSecure(true);
    await app.forceSecure(true);
    expect(told, [true]);
    // b closes: a is still on screen
    await app.forceSecure(false);
    expect(app.secureForced, isTrue);
    expect(told, [true]);
    // a closes
    await app.forceSecure(false);
    expect(app.secureForced, isFalse);
    expect(told, [true, false]);
  });

  test('a release nobody holds takes no one else\'s', () async {
    final app = await make();
    await app.forceSecure(false);
    await app.forceSecure(true);
    expect(app.secureForced, isTrue);
    await app.forceSecure(false);
    expect(app.secureForced, isFalse);
  });
}
