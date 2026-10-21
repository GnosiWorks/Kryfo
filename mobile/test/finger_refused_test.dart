// SPDX-License-Identifier: GPL-3.0-or-later
// a phone whose keystore will not keep a fingerprint key for Kryfo, on either
// side of a decoy
import 'dart:async';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/widgets/halo_switch.dart';

import 'pin_flow_fakes.dart';

const Map<int, (String, int)> _withDecoy = {
  ...appOnly,
  PinSlot.decoy: (decoyPin, PinKind.decoy),
};

// a phone with a finger, as local_auth answers. [fingers] false: every
// finger was removed
var _fingers = true;
void _finger() {
  _fingers = true;
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('plugins.flutter.io/local_auth');
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(
    ch,
    (c) async => switch (c.method) {
      'getAvailableBiometrics' => _fingers ? ['fingerprint'] : <String>[],
      'isDeviceSupported' => true,
      _ => null,
    },
  );
  addTearDown(() => m.setMockMethodCallHandler(ch, null));
}

// the keystore as a phone that refuses has it: no key at all, a key that
// comes after [failures] refusals, or one that never answers
class _RefusingBio extends SealBio {
  int failures = 0;
  bool hang = false;
  int asked = 0;

  @override
  Future<String?> seal(String opens) async {
    asked++;
    if (hang) return Completer<String?>().future;
    if (failures > 0) {
      failures--;
      calls.add('refused');
      return null;
    }
    return super.seal(opens);
  }
}

// a drop that never comes back, as a keystore stuck behind a seal
class _StuckDropBio extends SealBio {
  @override
  Future<void> disable() {
    calls.add('disable');
    return Completer<void>().future;
  }
}

Future<void> _card(WidgetTester t, Lock lock) async {
  await t.pumpWidget(
    app(
      PinsScreen(
        lock: lock.state,
        host: FakeHost(lock: lock.state),
      ),
    ),
  );
  await t.pumpAndSettle();
}

bool _switchOn(WidgetTester t) =>
    t.widget<HaloSwitch>(find.byType(HaloSwitch).first).value;

void main() {
  setUp(() => decoyReady = true);

  testWidgets('a phone that will not make a key: the switch goes back and '
      'the screen says why', (t) async {
    phone(t);
    _finger();
    final bio = _RefusingBio()..failures = 99;
    final lock = await makeLock(appOnly, bio: bio);
    await _card(t, lock);
    expect(_switchOn(t), isFalse);
    await t.tap(find.text(l10n.pinsUnlockWithFingerprint));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.pinsFingerRefused), findsOneWidget);
    await t.pumpAndSettle();
    expect(_switchOn(t), isFalse);
    expect(lock.state.biometric, isFalse);
    expect(lock.store.m['halo.lock.biometric'], isNot('true'));
    expect(lock.store.m.containsKey('halo.lock.biometric.seal'), isFalse);
    // tapped again once the phone takes it: on, and nothing more to say
    bio.failures = 0;
    await t.pump(const Duration(seconds: 5));
    await t.tap(find.text(l10n.pinsUnlockWithFingerprint));
    await t.pumpAndSettle();
    expect(_switchOn(t), isTrue);
    expect(find.text(l10n.pinsFingerRefused), findsNothing);
  });

  testWidgets('a pin whose fingerprint the phone will not take says so '
      'from the setup sheet', (t) async {
    phone(t);
    _finger();
    final bio = _RefusingBio()..failures = 99;
    final lock = await makeLock(appOnly, bio: bio);
    expect(lock.state.fingerOffered, isTrue);
    await _card(t, lock);
    // a changed pin offers the finger, as a new one does
    await t.tap(find.text(l10n.pinsChangePin));
    await t.pumpAndSettle();
    for (final pin in [appPin, '8642', '8642']) {
      await typePin(t, pin);
      await enter(t);
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
    }
    expect(find.text(l10n.lockSetupUnlockWithFingerprint), findsOneWidget);
    await t.tap(find.text(l10n.lockSetupUseFingerprint));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.pinsFingerRefused), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
    expect(lock.state.enabled, isTrue);
    expect(lock.state.biometric, isFalse);
    expect(find.text(l10n.lockSetupUnlockWithFingerprint), findsNothing);
  });

  test('a keystore that never answers leaves no switch busy', () async {
    _finger();
    final bio = _RefusingBio()..hang = true;
    final lock = await makeLock(
      appOnly,
      bio: bio,
      sealWait: const Duration(milliseconds: 50),
    );
    expect(
      await lock.state
          .setBiometric(true)
          .timeout(const Duration(seconds: 5), onTimeout: () => true),
      isFalse,
    );
    expect(lock.state.biometric, isFalse);
  });

  test(
    'a keystore that never answers the drop leaves the switch off',
    () async {
      _finger();
      final bio = _StuckDropBio();
      final lock = await makeLock(
        appOnly,
        bio: bio,
        dropWait: const Duration(milliseconds: 50),
      );
      final s = lock.state;
      expect(await s.setBiometric(true), isTrue);
      expect(
        await s
            .setBiometric(false)
            .timeout(const Duration(seconds: 5), onTimeout: () => false),
        isTrue,
      );
      expect(s.biometric, isFalse);
      expect(lock.store.m['halo.lock.biometric'], 'false');
      // a refused finger says so even while the drop hangs
      expect(await s.setBiometric(true), isTrue);
      s.lock();
      bio.answer = 'refused';
      final tried = s.tryBiometric();
      await Future<void>.delayed(Duration.zero);
      expect(s.fingerNote, FingerNote.refused);
      expect(
        await tried.timeout(const Duration(seconds: 5), onTimeout: () => true),
        isFalse,
      );
    },
  );

  test('after the pin, a phone that still has a finger but will not make a '
      'key turns the finger off and says so, instead of asking again at '
      'every start', () async {
    _finger();
    final bio = _RefusingBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    // an update or a new finger: asleep until the pin
    bio.addFinger();
    s.lock();
    expect(await s.tryBiometric(), isFalse);
    expect(s.bioStale, isTrue);
    bio.failures = 99;
    expect(await s.verifyPin(appPin), PinResult.normal);
    // the reseal, its one retry, and the answer
    for (var i = 0; i < 40 && s.fingerNote == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(bio.calls.where((c) => c == 'refused').length, 2);
    expect(s.fingerNote, FingerNote.refused);
    expect(s.fingerUnlock, isFalse);
    expect(s.biometric, isFalse);
    expect(s.bioStale, isFalse);
    expect(lock.store.m['halo.lock.biometric'], 'false');
    expect(lock.store.m.containsKey('halo.lock.biometric.seal'), isFalse);
    expect(bio.calls.last, 'disable');
    // and a new start does not wake it again
    final again = LockState(
      store: lock.store,
      engine: MemEngine(),
      clock: StillClock(),
      bio: bio,
    );
    await again.load();
    expect(again.fingerUnlock, isFalse);
    expect(again.bioStale, isFalse);
  });

  test('a keystore busy once after the unlock seals on the retry', () async {
    _finger();
    final bio = _RefusingBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    bio.addFinger();
    s.lock();
    await s.tryBiometric();
    bio.failures = 1;
    await s.verifyPin(appPin);
    for (var i = 0; i < 40 && s.bioStale; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(s.bioStale, isFalse);
    expect(s.fingerUnlock, isTrue);
    expect(s.fingerNote, isNull);
    s.lock();
    expect(await s.tryBiometric(), isTrue);
  });

  test('with every finger removed it sleeps as before, and is not turned '
      'off', () async {
    _finger();
    final bio = _RefusingBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    bio.addFinger();
    s.lock();
    await s.tryBiometric();
    _fingers = false;
    bio.failures = 99;
    await s.verifyPin(appPin);
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(s.fingerUnlock, isTrue);
    expect(s.bioStale, isTrue);
    expect(s.fingerNote, isNull);
    expect(lock.store.m['halo.lock.biometric'], 'true');
  });

  test('a finger the phone takes but will not open the seal with turns the '
      'finger off: no loop of finger, pin, finger', () async {
    _finger();
    final bio = _RefusingBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    s.lock();
    bio.answer = 'refused';
    expect(await s.tryBiometric(), isFalse);
    expect(s.locked, isTrue);
    expect(s.fingerUnlock, isFalse);
    expect(s.bioStale, isFalse);
    expect(s.fingerNote, FingerNote.refused);
    expect(bio.calls, ['seal', 'unlock', 'disable']);
    // the pin opens, and nothing makes a key behind it
    expect(await s.verifyPin(appPin), PinResult.normal);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bio.calls, ['seal', 'unlock', 'disable']);
  });

  for (final still in [false, true]) {
    testWidgets('a locked sensor says why on the lock screen, until the next '
        'lock${still ? ', reduced motion' : ''}', (t) async {
      phone(t);
      _finger();
      final bio = SealBio();
      final lock = await makeLock(appOnly, bio: bio);
      final s = lock.state;
      expect(await s.setBiometric(true), isTrue);
      s.lock();
      bio.answer = 'lockout';
      await t.pumpWidget(app(LockScreen(lock: s), still: still));
      await t.pumpAndSettle();
      // the prompt waits for the app to be in front: asked for here
      expect(await s.tryBiometric(), isFalse);
      await t.pumpAndSettle();
      expect(s.fingerNote, FingerNote.lockedOut);
      expect(find.text(l10n.lockFingerLockedOut), findsOneWidget);
      // the finger stays on: the sensor frees itself or with the phone's lock
      expect(find.text(l10n.lockUseFingerprint), findsOneWidget);
      expect(s.fingerUnlock, isTrue);
      bio.answer = 'cancel';
      expect(await s.verifyPin(appPin), PinResult.normal);
      s.lock();
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(LockScreen(lock: s), still: still));
      await t.pumpAndSettle();
      expect(s.fingerNote, isNull);
      expect(find.text(l10n.lockFingerLockedOut), findsNothing);
    });
  }

  testWidgets('a refused finger reads the same in a decoy as in any '
      'install', (t) async {
    phone(t);
    _finger();
    Future<List<String>> shown(LockState s) async {
      await t.pumpWidget(app(LockScreen(lock: s), still: true));
      await t.pumpAndSettle();
      final out = [
        for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? '',
      ];
      await t.pumpWidget(const SizedBox());
      return out;
    }

    final plainBio = SealBio();
    final plain = await makeLock(appOnly, bio: plainBio);
    await plain.state.setBiometric(true);
    plain.state.lock();
    plainBio.answer = 'refused';
    await plain.state.tryBiometric();

    final decoyBio = SealBio();
    final decoy = await makeLock(_withDecoy, bio: decoyBio, inDecoy: true);
    decoy.state.onOutcome = (r, {vaultKey}) async =>
        decoy.state.inDecoy = r == PinResult.decoy;
    await decoy.state.setBiometric(true);
    // the lock comes down inside the decoy
    decoy.state.lock();
    expect(decoy.state.inDecoy, isTrue);
    decoyBio.answer = 'refused';
    await decoy.state.tryBiometric();

    final a = await shown(plain.state);
    expect(a, contains(l10n.lockFingerRefused));
    expect(await shown(decoy.state), a);
  });
}
