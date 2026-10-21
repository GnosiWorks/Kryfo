// SPDX-License-Identifier: GPL-3.0-or-later
// the pad stays up a beat after the pin, while the lock fades. a finger that
// becomes ready in that beat never brings up the prompt over the app the pin
// already opened: not after a late answer from android, not after the reseal
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';

import 'pin_flow_fakes.dart';

// local_auth as android answers it: nothing before the app has a screen
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

// the asks run on the test's clock: a few seconds of it
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  await t.pumpAndSettle();
}

int _prompts(SealBio bio) => bio.calls.where((c) => c == 'unlock').length;

void main() {
  setUp(() => decoyReady = true);

  testWidgets('a finger android names only after the pin opened the app '
      'brings up no prompt', (t) async {
    phone(t);
    _finger();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final bio = SealBio();
    final seal = (await bio.seal(HaloContainer.everyday.id))!;
    final made = await makeLock(appOnly, bio: bio);
    made.store.m['halo.lock.biometric'] = 'true';
    made.store.m['halo.lock.biometric.seal'] = seal;
    final s = LockState(
      store: made.store,
      engine: MemEngine(),
      clock: StillClock(),
      bio: bio,
      revealAfter: Duration.zero,
    );
    await s.load();
    bio.answer = 'cancel';
    await t.pumpWidget(app(LockScreen(lock: s), still: true));
    await _settle(t);
    expect(await s.verifyPin(appPin), PinResult.normal);
    expect(s.locked, isFalse);
    // the pad is still up, fading: the late answer comes now
    _screen = true;
    s.returned();
    await _settle(t);
    expect(s.bioSupported, isTrue);
    expect(_prompts(bio), 0);
    expect(await s.tryBiometric(), isFalse);
    expect(_prompts(bio), 0);
  });

  testWidgets('a reseal that ends after the pin opened the app brings up no '
      'prompt', (t) async {
    phone(t);
    _finger();
    _screen = true;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final bio = SealBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    bio.addFinger();
    s.lock();
    await s.tryBiometric();
    expect(s.bioStale, isTrue);
    final before = _prompts(bio);
    bio.answer = 'cancel';
    await t.pumpWidget(app(LockScreen(lock: s), still: true));
    await _settle(t);
    expect(await s.verifyPin(appPin), PinResult.normal);
    await _settle(t);
    expect(s.bioStale, isFalse);
    expect(_prompts(bio), before);
  });
}
