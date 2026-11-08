// SPDX-License-Identifier: GPL-3.0-or-later
// every change on App lock that weakens the lock asks for the pin there is
// first, on the page a pin change opens with: a wrong one changes nothing
// and counts as on the lock screen. the decoy asks for its own, alike
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_setup_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';

import 'pin_flow_fakes.dart';

const _dWipePin = '7777';
const _dDecoyPin = '3333';

// a phone with a finger, as local_auth answers
void _finger() {
  const ch = MethodChannel('plugins.flutter.io/local_auth');
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(
    ch,
    (c) async => switch (c.method) {
      'getAvailableBiometrics' => ['fingerprint'],
      'isDeviceSupported' => true,
      _ => null,
    },
  );
  addTearDown(() => m.setMockMethodCallHandler(ch, null));
}

class _Case {
  const _Case(
    this.name, {
    required this.make,
    required this.pin,
    required this.open,
    required this.weakened,
    this.decoy = false,
    this.finger = false,
  });
  final String name;
  final Future<Lock> Function() make;
  final String pin;
  // the taps up to the pin page
  final Future<void> Function(WidgetTester t) open;
  final bool Function(Lock lock, FakeHost host) weakened;
  final bool decoy;
  final bool finger;
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

// Advanced protection, opened if it is not open already
Future<void> _advanced(WidgetTester t) async {
  if (find.text(l10n.pinsWipePin).hitTestable().evaluate().isEmpty) {
    await _tap(t, find.text(l10n.pinsAdvanced));
  }
}

Future<void> _turnOff(WidgetTester t) async {
  await _tap(t, find.text(l10n.pinsTurnOff));
  await _tap(t, find.text(l10n.pinsTurnOff).last);
}

Future<void> _remove(WidgetTester t, String row) async {
  await _advanced(t);
  await _tap(t, find.text(row).first);
  await _tap(t, find.text(l10n.pinsRemove));
  await _tap(t, find.text(l10n.commonRemove).last);
}

Future<void> _pin(WidgetTester t, String pin) async {
  await typePin(t, pin);
  await enter(t);
  await t.pump(const Duration(milliseconds: 300));
  await t.pumpAndSettle();
}

final _everydayAll = {...appOnly, PinSlot.wipe: (wipePin, PinKind.wipe)};

// the decoy's side of a phone holding a decoy, with its own wipe and
// decoy pins. with a decoy of its own its finger opens only that, as in
// any install: the finger case has none
Future<Lock> _decoyLock({LockBio? bio, bool inner = true}) => makeLock(
  {
    ...appOnly,
    PinSlot.decoy: (decoyPin, PinKind.decoy),
    PinSlot.decoyWipe: (_dWipePin, PinKind.wipe),
    if (inner) PinSlot.decoyDecoy: (_dDecoyPin, PinKind.decoy),
  },
  inDecoy: true,
  bio: bio,
  stored: {'halo.lock.d.wipe': 'true', if (inner) 'halo.lock.d.decoy': 'true'},
);

final _cases = [
  _Case(
    'turn off',
    make: () => makeLock(_everydayAll, wipeOn: true),
    pin: appPin,
    open: _turnOff,
    weakened: (l, _) => !l.state.lockOn,
  ),
  _Case(
    'remove the wipe pin',
    make: () => makeLock(_everydayAll, wipeOn: true),
    pin: appPin,
    open: (t) => _remove(t, l10n.pinsWipePin),
    weakened: (l, _) => !l.state.panicEnabled,
  ),
  _Case(
    'remove the decoy pin',
    make: () =>
        makeLock({...appOnly, PinSlot.decoy: (decoyPin, PinKind.decoy)}),
    pin: appPin,
    open: (t) => _remove(t, l10n.pinsDecoyPin),
    weakened: (_, h) => h.calls.contains('removeDecoy'),
  ),
  _Case(
    'fingerprint on',
    make: () => makeLock(appOnly, bio: SealBio()),
    pin: appPin,
    finger: true,
    open: (t) => _tap(t, find.text(l10n.pinsUnlockWithFingerprint)),
    weakened: (l, _) => l.state.biometric,
  ),
  _Case(
    'turn off in the decoy',
    make: _decoyLock,
    pin: decoyPin,
    decoy: true,
    open: _turnOff,
    weakened: (l, _) => !l.state.lockOn,
  ),
  _Case(
    'remove the wipe pin in the decoy',
    make: _decoyLock,
    pin: decoyPin,
    decoy: true,
    open: (t) => _remove(t, l10n.pinsWipePin),
    weakened: (l, _) => !l.state.panicEnabled,
  ),
  _Case(
    'remove the decoy pin in the decoy',
    make: _decoyLock,
    pin: decoyPin,
    decoy: true,
    open: (t) => _remove(t, l10n.pinsDecoyPin),
    weakened: (l, _) => !l.state.decoyPinOn,
  ),
  _Case(
    'fingerprint on in the decoy',
    make: () => _decoyLock(bio: SealBio(), inner: false),
    pin: decoyPin,
    decoy: true,
    finger: true,
    open: (t) => _tap(t, find.text(l10n.pinsUnlockWithFingerprint)),
    weakened: (l, _) => l.state.biometric,
  ),
];

void main() {
  setUp(() => decoyReady = true);

  for (final c in _cases) {
    testWidgets('${c.name}: the pin first, a wrong one or a way back '
        'changes nothing', (t) async {
      phone(t);
      if (c.finger) _finger();
      final lock = await c.make();
      final host = FakeHost(
        lock: lock.state,
        decoy: !c.decoy && lock.state.decoySet,
      );
      if (c.finger) expect(lock.state.fingerOffered, isTrue);
      await t.pumpWidget(app(PinsScreen(lock: lock.state, host: host)));
      await t.pumpAndSettle();
      expect(c.weakened(lock, host), isFalse);

      await c.open(t);
      expect(find.byType(LockSetupScreen), findsOneWidget);
      expect(find.text(l10n.flowEnterYourPin), findsOneWidget);
      expect(find.text(l10n.flowEnterYourPinLine), findsOneWidget);
      // a miss: the same words as any wrong pin, nothing changed
      final wrong = c.decoy ? appPin : '0000';
      await _pin(t, wrong);
      expect(find.text(l10n.lockNotIt), findsOneWidget);
      expect(find.byType(LockSetupScreen), findsOneWidget);
      expect(c.weakened(lock, host), isFalse);
      // back out: still nothing
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(LockSetupScreen), findsNothing);
      expect(c.weakened(lock, host), isFalse);

      await c.open(t);
      await _pin(t, c.pin);
      expect(find.byType(LockSetupScreen), findsNothing);
      expect(c.weakened(lock, host), isTrue);
    });
  }

  testWidgets('a miss on the page counts as one on the lock screen', (t) async {
    phone(t);
    final lock = await makeLock(_everydayAll, wipeOn: true);
    final twin = await makeLock(_everydayAll, wipeOn: true);
    await t.pumpWidget(
      app(
        PinsScreen(
          lock: lock.state,
          host: FakeHost(lock: lock.state),
        ),
      ),
    );
    await t.pumpAndSettle();
    await _turnOff(t);
    await _pin(t, '0000');
    expect(await twin.state.verifyPin('0000'), PinResult.invalid);
    expect(lock.store.m['halo.lock.state'], isNotNull);
    expect(lock.store.m['halo.lock.state'], twin.store.m['halo.lock.state']);
    expect(lock.state.lockOn, isTrue);
  });

  testWidgets('the pin page reads the same in the decoy as anywhere', (
    t,
  ) async {
    phone(t);
    final seen = <Set<String>>[];
    for (final make in [
      () => makeLock(_everydayAll, wipeOn: true),
      _decoyLock,
    ]) {
      final lock = await make();
      await t.pumpWidget(
        app(
          PinsScreen(
            lock: lock.state,
            host: FakeHost(lock: lock.state),
          ),
        ),
      );
      await t.pumpAndSettle();
      await _turnOff(t);
      seen.add({
        for (final w in t.widgetList<Text>(find.byType(Text)))
          if (w.data != null) w.data!,
      });
      await t.pumpWidget(const SizedBox());
    }
    expect(seen[1], seen[0]);
  });
}
