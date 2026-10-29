// SPDX-License-Identifier: GPL-3.0-or-later
// a pin set blocks no screenshots on its own: it keeps the app out of
// recents. the lock screen and every screen a pin is typed on block, a
// chat that blocks keeps blocking after an unlock, and the decoy does the
// same as the everyday app
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show AppState, AppStateScreen;
import 'package:kryfo/pin_shield.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/lock_setup_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/update_pins_screen.dart';

import 'arrival_fakes.dart';
import 'pin_flow_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // what was sent in this test, and what the window has now: one app
  // for the file, since each one made listens to the same lock
  late List<bool> secure;
  late List<bool> recents;
  bool? shotsOff;
  bool? hiddenNow;
  AppState? shared;

  setUp(() {
    secure = [];
    recents = [];
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
          call,
        ) async {
          final on = (call.arguments as Map?)?['on'];
          if (call.method == 'setSecure') {
            secure.add(on as bool);
            shotsOff = on;
          }
          if (call.method == 'setRecentsHidden') {
            recents.add(on as bool);
            hiddenNow = on;
          }
          return null;
        });
    addTearDown(() {
      lockState.inDecoy = false;
      lockState.openForTest();
      pinShieldHold = null;
    });
  });

  Future<AppState> make() async {
    var app = shared;
    if (app == null) {
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      app = shared = AppState(io: ArrivalIo(), router: router);
    }
    await app.loadScreenSecure();
    return app;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('a pin set', () {
    test('hides the app in recents and blocks no screenshots', () async {
      lockState.openForTest(enabled: true);
      final app = await make();
      expect(app.recentsHidden, isTrue);
      expect(app.windowSecure, isFalse);
      expect((hiddenNow, shotsOff), (true, false));
      expect(secure, isNot(contains(true)));
    });

    test('no pin: recents shows the app', () async {
      lockState.openForTest();
      final app = await make();
      expect(app.recentsHidden, isFalse);
      expect((hiddenNow, shotsOff), (false, false));
    });

    test('a pin turned on later hides the app in recents at once', () async {
      lockState.openForTest();
      final app = await make();
      lockState.openForTest(enabled: true);
      lockState.liftForTest();
      await settle();
      expect(app.recentsHidden, isTrue);
      expect((hiddenNow, shotsOff), (true, false));
    });
  });

  group('the lock screen', () {
    test('blocks while it is up and lets go as it lifts', () async {
      lockState.openForTest(enabled: true);
      final app = await make();
      secure.clear();
      lockState.lock();
      await settle();
      expect(app.windowSecure, isTrue);
      expect(shotsOff, isTrue);
      lockState.liftForTest();
      await settle();
      expect(app.windowSecure, isFalse);
      expect(secure, [true, false]);
      // recents stays hidden throughout
      expect(hiddenNow, isTrue);
    });

    test('over a chat that blocks: the chat keeps blocking after the '
        'unlock', () async {
      lockState.openForTest(enabled: true);
      final app = await make();
      secure.clear();
      await app.forceSecure(true);
      lockState.lock();
      await settle();
      lockState.liftForTest();
      await settle();
      expect(app.windowSecure, isTrue);
      expect(secure, [true]);
      await app.forceSecure(false);
      expect(secure, [true, false]);
    });

    test('the decoy\'s lock screen blocks the same way', () async {
      lockState.openForTest(enabled: true);
      lockState.inDecoy = true;
      final app = await make();
      expect(app.recentsHidden, isTrue);
      expect(app.windowSecure, isFalse);
      lockState.lock();
      await settle();
      expect(shotsOff, isTrue);
      lockState.liftForTest();
      await settle();
      expect((hiddenNow, shotsOff), (true, false));
    });

    test('settings hear only a pin set or not, not every lock', () async {
      lockState.openForTest(enabled: true);
      final app = await make();
      // the app has seen this lock once
      lockState.lock();
      lockState.liftForTest();
      await settle();
      var heard = 0;
      void count() => heard++;
      app.addListener(count);
      addTearDown(() => app.removeListener(count));
      lockState.lock();
      lockState.liftForTest();
      await settle();
      expect(heard, 0);
    });
  });

  group('pin screens hold the window while open', () {
    Future<void> holds(WidgetTester t, Widget screen) async {
      phone(t);
      final held = <bool>[];
      pinShieldHold = held.add;
      await t.pumpWidget(app(screen, still: true));
      await t.pump();
      expect(held, [true]);
      await t.pumpWidget(const SizedBox());
      expect(held, [true, false]);
    }

    testWidgets('setting or changing the pin', (t) async {
      final lock = await makeLock(appOnly);
      await holds(t, LockSetupScreen(lock: lock.state, check: true));
    });

    testWidgets('a decoy or wipe pin', (t) async {
      final lock = await makeLock(appOnly);
      for (final flow in [PinFlow.decoy, PinFlow.wipe]) {
        await holds(
          t,
          PinFlowScreen(
            flow: flow,
            lock: lock.state,
            host: FakeHost(lock: lock.state),
          ),
        );
      }
    });

    testWidgets('the security update', (t) async {
      final lock = await makeLock(appOnly);
      await holds(t, UpdatePinsScreen(lock: lock.state));
    });

    testWidgets('the app\'s hold reaches android', (t) async {
      lockState.openForTest(enabled: true);
      final made = await t.runAsync(make);
      phone(t);
      final lock = await t.runAsync(() => makeLock(appOnly));
      await t.pumpWidget(app(LockSetupScreen(lock: lock!.state), still: true));
      await t.pump();
      expect(made!.windowSecure, isTrue);
      expect(secure.last, isTrue);
      await t.pumpWidget(const SizedBox());
      expect(made.windowSecure, isFalse);
      expect(secure.last, isFalse);
    });
  });
}
