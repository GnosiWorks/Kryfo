// SPDX-License-Identifier: GPL-3.0-or-later
// after an update or a boot the service starts the app before any screen,
// and android says there is no finger until there is one. the finger then
// shows once the screen is there: on the lock screen, with its prompt, and
// as the switch on App lock, without leaving the app first
import 'dart:async';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';

import 'pin_flow_fakes.dart';

// local_auth as android answers it: nothing before the app has a screen
var _screen = false;
// answers still "none" after the screen came, as android does for a beat
var _lag = 0;
void _finger() {
  _screen = false;
  _lag = 0;
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('plugins.flutter.io/local_auth');
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(
    ch,
    (c) async => switch (c.method) {
      'getAvailableBiometrics' =>
        _screen && _lag-- <= 0 ? ['fingerprint'] : <String>[],
      'isDeviceSupported' => true,
      _ => null,
    },
  );
  addTearDown(() => m.setMockMethodCallHandler(ch, null));
}

// the key's state is asked last in the load: held here, the screen can come
// while the load still runs
class _HeldBio extends SealBio {
  Completer<void>? hold;
  @override
  Future<String> state() async {
    await hold?.future;
    return super.state();
  }
}

// a lock with the everyday finger on, from before this start
Future<(LockState, _HeldBio, MemStore)> _withFinger({bool held = false}) async {
  final bio = _HeldBio();
  final seal = (await bio.seal(HaloContainer.everyday.id))!;
  final made = await makeLock(appOnly, bio: bio);
  made.store.m['halo.lock.biometric'] = 'true';
  made.store.m['halo.lock.biometric.seal'] = seal;
  if (held) bio.hold = Completer<void>();
  final s = LockState(
    store: made.store,
    engine: MemEngine(),
    clock: StillClock(),
    bio: bio,
    revealAfter: Duration.zero,
  );
  return (s, bio, made.store);
}

// the asks run on the test's clock: a few seconds of it
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  await t.pumpAndSettle();
}

void main() {
  setUp(() => decoyReady = true);

  test('a screen that came while the load ran is asked about once it is '
      'done', () async {
    _finger();
    final (s, bio, _) = await _withFinger(held: true);
    final loading = s.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // the activity is up now, and the app came to the front
    _screen = true;
    s.returned();
    bio.hold!.complete();
    await loading;
    for (var i = 0; i < 20 && !s.bioSupported; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(s.bioSupported, isTrue);
    expect(s.fingerUnlock, isTrue);
  });

  testWidgets('App lock asks again as it opens, so the switch is there', (
    t,
  ) async {
    phone(t);
    _finger();
    final (s, _, _) = await _withFinger();
    await s.load();
    expect(s.bioSupported, isFalse);
    _screen = true;
    await t.pumpWidget(
      app(
        PinsScreen(
          lock: s,
          host: FakeHost(lock: s),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(l10n.pinsUnlockWithFingerprint), findsOneWidget);
    expect(s.biometric, isTrue);
  });

  testWidgets('a finger the phone only names after the pad is up brings the '
      'prompt by itself, once', (t) async {
    phone(t);
    _finger();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final (s, bio, _) = await _withFinger();
    await s.load();
    bio.answer = 'cancel';
    expect(s.locked, isTrue);
    await t.pumpWidget(app(LockScreen(lock: s), still: true));
    await _settle(t);
    expect(find.text(l10n.lockUseFingerprint), findsNothing);
    expect(bio.calls.where((c) => c == 'unlock'), isEmpty);
    _screen = true;
    s.returned();
    await _settle(t);
    expect(find.text(l10n.lockUseFingerprint), findsOneWidget);
    expect(bio.calls.where((c) => c == 'unlock'), hasLength(1));
    // a cancelled prompt is not asked for again by itself
    s.returned();
    await _settle(t);
    expect(bio.calls.where((c) => c == 'unlock'), hasLength(1));
  });

  testWidgets('a phone that names its finger only a beat after the screen '
      'came is asked again while the app is in front', (t) async {
    phone(t);
    _finger();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final (s, bio, _) = await _withFinger();
    await s.load();
    bio.answer = 'cancel';
    await t.pumpWidget(app(LockScreen(lock: s), still: true));
    await _settle(t);
    _screen = true;
    _lag = 1;
    s.returned();
    await t.pump();
    expect(find.text(l10n.lockUseFingerprint), findsNothing);
    await _settle(t);
    expect(s.bioSupported, isTrue);
    expect(find.text(l10n.lockUseFingerprint), findsOneWidget);
    expect(bio.calls.where((c) => c == 'unlock'), hasLength(1));
  });

  // whatever else moves the lock while it is up, the prompt came once
  testWidgets('a prompt cancelled once is not asked for again by other '
      'changes to the lock', (t) async {
    phone(t);
    _finger();
    _screen = true;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final (s, bio, _) = await _withFinger();
    await s.load();
    bio.answer = 'cancel';
    await t.pumpWidget(app(LockScreen(lock: s), still: true));
    await _settle(t);
    expect(bio.calls.where((c) => c == 'unlock'), hasLength(1));
    for (var i = 0; i < 5; i++) {
      // a lockout answer, then a new try, each notify the lock
      bio.answer = 'lockout';
      await s.tryBiometric();
      bio.answer = 'cancel';
      await _settle(t);
    }
    // the five asked for here, none of its own
    expect(bio.calls.where((c) => c == 'unlock'), hasLength(6));
  });

  testWidgets('the lock screen asks again itself once it is up', (t) async {
    phone(t);
    _finger();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final (s, bio, _) = await _withFinger();
    await s.load();
    expect(s.bioSupported, isFalse);
    bio.answer = 'cancel';
    // android answers now, and nothing else asks
    _screen = true;
    await t.pumpWidget(app(LockScreen(lock: s), still: true));
    await _settle(t);
    expect(s.bioSupported, isTrue);
    expect(find.text(l10n.lockUseFingerprint), findsOneWidget);
  });
}
