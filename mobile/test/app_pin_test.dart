// SPDX-License-Identifier: GPL-3.0-or-later
// the pin on the App lock card. a change asks for the pin there is first,
// as the advanced flows do. inside the decoy a turn off pauses the lock and
// shows its wipe pin gone while its entry stays, a pin set again there
// locks again and drops that wipe pin for good, and the fingerprint switch
// is the decoy's own: the everyday app's fingerprint key is never touched
// from there. a long hold reads in minutes and hours, not in thousands of
// seconds
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_setup_screen.dart';
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
  Future<String> unlock(String title, String cancel) async => 'none';
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

  test('in the decoy the fingerprint switch is its own', () async {
    final store = MemStore();
    final bio = _Bio();
    final s = LockState(
      store: store,
      engine: MemEngine(),
      clock: StillClock(),
      bio: bio,
      revealAfter: Duration.zero,
    );
    await s.load();
    s.inDecoy = true;
    expect(await s.setBiometric(true), isTrue);
    expect(s.biometricShown, isTrue);
    expect(s.biometric, isFalse);
    expect(store.m.containsKey('halo.lock.biometric'), isFalse);
    await s.setBiometric(false);
    expect(s.biometricShown, isFalse);
    expect(bio.calls, isEmpty);

    // the everyday session's switch is the real one
    s.inDecoy = false;
    await s.setBiometric(true);
    expect(bio.calls, ['enable']);
    expect(store.m['halo.lock.biometric'], 'true');
    expect(s.biometricShown, isTrue);
  });

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
