// SPDX-License-Identifier: GPL-3.0-or-later
// the pin on the App lock card. a change asks for the pin there is first,
// as the advanced flows do. inside the decoy a turn off pauses the lock and
// shows its wipe pin gone while its entry stays, a pin set again there
// locks again and drops that wipe pin for good. a finger opens the everyday
// app, so while a decoy pin is set fingerprint unlock is off: no switch and
// no offer in either app, no finger at the lock, and the decoy setup says
// so on a phone with a finger. a long hold reads in minutes and hours, not
// in thousands of seconds
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_setup_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';

import 'pin_flow_fakes.dart';

const _newPin = '8642';
const _decoyWipePin = '7777';

class _Bio implements LockBio {
  final calls = <String>[];
  @override
  Future<bool> ready() async => true;
  @override
  Future<String> state() async => 'ok';
  @override
  Future<bool> enable() async {
    calls.add('enable');
    return true;
  }

  @override
  Future<void> disable() async => calls.add('disable');
  @override
  Future<String> unlock(String title, String cancel) async {
    calls.add('unlock');
    return 'ok';
  }
}

const Map<int, (String, int)> _withDecoy = {
  ...appOnly,
  PinSlot.decoy: (decoyPin, PinKind.decoy),
};

// a phone with a finger, as local_auth answers
void _finger() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

// a pin and its enter key, then the beat before the next step
Future<void> _pin(WidgetTester t, String pin) async {
  await typePin(t, pin);
  await enter(t);
  await t.pump(const Duration(milliseconds: 300));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a change asks for the pin there is first', (t) async {
    phone(t);
    final lock = await makeLock(appOnly);
    await _card(t, lock);
    await t.tap(find.text(l10n.pinsChangePin));
    await t.pumpAndSettle();
    expect(find.byType(LockSetupScreen), findsOneWidget);
    expect(find.text(l10n.flowEnterYourPin), findsOneWidget);

    // a wrong one is a miss and leads nowhere
    await _pin(t, '0000');
    expect(find.text(l10n.lockNotIt), findsOneWidget);
    expect(find.text(l10n.flowEnterYourPin), findsOneWidget);
    expect(lock.entries['${PinSlot.app}']['p'], appPin);

    await _pin(t, appPin);
    expect(find.text(l10n.lockSetupSetAPin), findsOneWidget);
    await _pin(t, _newPin);
    await _pin(t, _newPin);
    expect(find.byType(LockSetupScreen), findsNothing);
    expect(lock.entries['${PinSlot.app}']['p'], _newPin);
  });

  testWidgets('with no pin yet setting one asks for nothing first', (t) async {
    phone(t);
    final lock = await makeLock(null);
    await _card(t, lock);
    await t.tap(find.text(l10n.pinsSetAPin));
    await t.pumpAndSettle();
    expect(find.text(l10n.lockSetupSetAPin), findsOneWidget);
    expect(find.text(l10n.flowEnterYourPin), findsNothing);
  });

  testWidgets('in the decoy a turn off keeps its wipe pin, shows it gone, '
      'and a pin set again locks again', (t) async {
    phone(t);
    final lock = await makeLock({
      ...appOnly,
      PinSlot.decoy: (decoyPin, PinKind.decoy),
      PinSlot.decoyWipe: (_decoyWipePin, PinKind.wipe),
    });
    lock.store.m['halo.lock.d.wipe'] = 'true';
    await lock.state.load();
    lock.state.inDecoy = true;
    expect(lock.state.panicEnabled, isTrue);

    await _card(t, lock);
    await t.tap(find.text(l10n.pinsTurnOff));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pinsTurnOff).last);
    await t.pumpAndSettle();
    expect(lock.state.lockOn, isFalse);
    // as a turn off reads anywhere, while the owner's entry stays
    expect(lock.state.panicEnabled, isFalse);
    expect(lock.entries['${PinSlot.decoyWipe}']['p'], _decoyWipePin);
    expect(lock.store.m['halo.lock.d.wipe'], 'true');

    await t.tap(find.text(l10n.pinsSetAPin));
    await t.pumpAndSettle();
    await _pin(t, _newPin);
    await _pin(t, _newPin);
    expect(lock.state.lockOn, isTrue);
    expect(find.text(l10n.pinsChangePin), findsOneWidget);
    expect(lock.entries['${PinSlot.decoy}']['p'], _newPin);
    expect(lock.state.panicEnabled, isFalse);
  });

  testWidgets('in the decoy a pin set again after a turn off may be the '
      'wipe pin that showed as gone, and it wipes nothing', (t) async {
    phone(t);
    final lock = await makeLock({
      ...appOnly,
      PinSlot.decoy: (decoyPin, PinKind.decoy),
      PinSlot.decoyWipe: (_decoyWipePin, PinKind.wipe),
    });
    lock.store.m['halo.lock.d.wipe'] = 'true';
    await lock.state.load();
    lock.state.inDecoy = true;

    await _card(t, lock);
    await t.tap(find.text(l10n.pinsTurnOff));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pinsTurnOff).last);
    await t.pumpAndSettle();
    expect(lock.state.panicEnabled, isFalse);

    await t.tap(find.text(l10n.pinsSetAPin));
    await t.pumpAndSettle();
    await _pin(t, _decoyWipePin);
    await _pin(t, _decoyWipePin);
    expect(find.byType(LockSetupScreen), findsNothing);
    expect(lock.state.lockOn, isTrue);
    expect(lock.entries['${PinSlot.decoy}']['p'], _decoyWipePin);
    expect(lock.entries.containsKey('${PinSlot.decoyWipe}'), isFalse);
    expect(lock.store.m.containsKey('halo.lock.d.wipe'), isFalse);
    expect(lock.state.panicEnabled, isFalse);
    expect(await lock.state.confirmPin(_decoyWipePin), PinResult.normal);
  });

  testWidgets('while a decoy pin is set neither app shows the fingerprint '
      'switch, and it comes back off once the decoy goes', (t) async {
    phone(t);
    _finger();
    final lock = await makeLock(_withDecoy, bio: _Bio());
    final s = lock.state;
    expect(s.bioSupported, isTrue);
    expect(s.decoySet, isTrue);
    await _card(t, lock);
    expect(find.text(l10n.pinsYourPin), findsOneWidget);
    expect(find.text(l10n.pinsUnlockWithFingerprint), findsNothing);
    s.inDecoy = true;
    await t.pumpAndSettle();
    expect(find.text(l10n.pinsYourPin), findsOneWidget);
    expect(find.text(l10n.pinsUnlockWithFingerprint), findsNothing);

    s.inDecoy = false;
    await s.clearDecoyPins();
    await t.pumpAndSettle();
    expect(find.text(l10n.pinsUnlockWithFingerprint), findsOneWidget);
    expect(s.biometric, isFalse);
  });

  for (final (name, pins, decoy, offered) in [
    ('with no decoy', appOnly, false, true),
    ('with a decoy, in the everyday app,', _withDecoy, false, false),
    ('in the decoy', _withDecoy, true, false),
  ]) {
    testWidgets('a new pin $name '
        '${offered ? 'offers the' : 'offers no'} fingerprint', (t) async {
      phone(t);
      _finger();
      final lock = await makeLock(pins, bio: _Bio(), inDecoy: decoy);
      await _card(t, lock);
      await t.tap(find.text(l10n.pinsChangePin));
      await t.pumpAndSettle();
      await _pin(t, decoy ? decoyPin : appPin);
      await _pin(t, _newPin);
      await _pin(t, _newPin);
      final offer = find.text(l10n.lockSetupUnlockWithFingerprint);
      if (!offered) {
        expect(offer, findsNothing);
        expect(find.byType(LockSetupScreen), findsNothing);
        expect(
          lock.entries['${decoy ? PinSlot.decoy : PinSlot.app}']['p'],
          _newPin,
        );
        return;
      }
      expect(offer, findsOneWidget);
      await t.tap(find.text(l10n.lockSetupPinOnly));
      await t.pumpAndSettle();
      expect(find.byType(LockSetupScreen), findsNothing);
    });
  }

  test('setting a decoy pin turns fingerprint unlock off', () async {
    _finger();
    final bio = _Bio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    expect(s.biometric, isTrue);
    expect(await s.setupDecoyPin(decoyPin), isTrue);
    expect(s.decoySet, isTrue);
    expect(s.biometric, isFalse);
    expect(s.fingerOffered, isFalse);
    expect(lock.store.m['halo.lock.biometric'], 'false');
    expect(bio.calls, ['enable', 'disable']);
    expect(await s.setBiometric(true), isFalse);
    expect(bio.calls, ['enable', 'disable']);
  });

  test('an install with a decoy and fingerprint on turns it off at start, '
      'and an old decoy switch is dropped', () async {
    _finger();
    final bio = _Bio();
    final lock = await makeLock(
      _withDecoy,
      bio: bio,
      stored: {'halo.lock.biometric': 'true', 'halo.lock.d.bio': 'true'},
    );
    expect(lock.store.m['halo.lock.biometric'], 'false');
    expect(lock.store.m.containsKey('halo.lock.d.bio'), isFalse);
    expect(bio.calls, ['disable']);
    expect(lock.state.biometric, isFalse);
  });

  test('a finger opens nothing while a decoy pin is set', () async {
    _finger();
    final bio = _Bio();
    final lock = await makeLock(
      appOnly,
      bio: bio,
      stored: {'halo.lock.biometric': 'true'},
    );
    final s = lock.state;
    // a decoy session counts as a set decoy pin
    s.inDecoy = true;
    expect(s.biometric, isFalse);
    expect(await s.tryBiometric(), isFalse);
    expect(bio.calls, isEmpty);
    s.inDecoy = false;
    expect(s.biometric, isTrue);
    expect(await s.tryBiometric(), isTrue);
    expect(bio.calls, ['unlock']);
  });

  for (final finger in [true, false]) {
    testWidgets('the decoy setup and the how sheet '
        '${finger ? 'say' : 'skip'} that fingerprint unlock turns off', (
      t,
    ) async {
      phone(t);
      if (finger) _finger();
      final lock = await makeLock(appOnly, bio: finger ? _Bio() : null);
      expect(lock.state.bioSupported, finger);
      final note = find.text(l10n.flowDecoyFingerOff);
      await t.pumpWidget(
        app(
          PinFlowScreen(
            flow: PinFlow.decoy,
            lock: lock.state,
            host: FakeHost(lock: lock.state),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.flowDecoy1), findsOneWidget);
      expect(note, finger ? findsOneWidget : findsNothing);

      await t.pumpWidget(const SizedBox());
      await _card(t, lock);
      await t.tap(find.text(l10n.pinsAdvanced));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(l10n.pinsHowThisWorks));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.pinsHowThisWorks));
      await t.pumpAndSettle();
      expect(find.text(l10n.howDecoy), findsOneWidget);
      expect(note, finger ? findsOneWidget : findsNothing);
    });
  }

  test('a long hold reads in minutes and hours', () {
    expect(
      tooManyTriesLine(const Duration(seconds: 29)),
      l10n.lockTooManyTriesS('30'),
    );
    expect(
      tooManyTriesLine(const Duration(seconds: 89)),
      l10n.lockTooManyTriesS('90'),
    );
    expect(
      tooManyTriesLine(const Duration(seconds: 299)),
      l10n.lockTooManyTriesFor('5:00'),
    );
    expect(
      tooManyTriesLine(const Duration(seconds: 3664)),
      l10n.lockTooManyTriesFor('1:01:05'),
    );
    expect(
      tooManyTriesLine(const Duration(hours: 8) - const Duration(seconds: 1)),
      l10n.lockTooManyTriesFor('8:00:00'),
    );
  });
}
