// SPDX-License-Identifier: GPL-3.0-or-later
// a fingerprint answer that changes the lock while a pin is being typed
// keeps every digit and the done key: the pin typed through it unlocks
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';

import 'pin_flow_fakes.dart';

var _screen = false;
void _finger() {
  _screen = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('plugins.flutter.io/local_auth');
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(
    ch,
    (c) async => switch (c.method) {
      'getAvailableBiometrics' => _screen ? ['fingerprint'] : <String>[],
      'isDeviceSupported' => true,
      _ => null,
    },
  );
  addTearDown(() => m.setMockMethodCallHandler(ch, null));
}

void main() {
  setUp(() => decoyReady = true);

  for (final fingerOn in [false, true]) {
    testWidgets('a re-probe that answers mid-entry loses no digit '
        '(finger ${fingerOn ? 'on' : 'off'})', (t) async {
      phone(t);
      _finger();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final bio = SealBio()..answer = 'cancel';
      final lock = await makeLock(appOnly, bio: bio);
      final s = lock.state;
      if (fingerOn) {
        _screen = true;
        await s.recheckFinger();
        expect(await s.setBiometric(true), isTrue);
        _screen = false;
        // as after a start with no screen: the phone says no finger
        await s.load();
      }
      s.lock();
      await t.pumpWidget(app(LockScreen(lock: s), still: true));
      await t.pumpAndSettle();
      await typePin(t, appPin.substring(0, 2));
      // android answers now: the lock changes under the pad
      _screen = true;
      s.returned();
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      await typePin(t, appPin.substring(2));
      await enter(t);
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(s.locked, isFalse);
    });
  }
}
