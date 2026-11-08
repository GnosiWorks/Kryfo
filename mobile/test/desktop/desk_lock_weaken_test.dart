// SPDX-License-Identifier: GPL-3.0-or-later
// on a computer App lock asks for the pin there is before the lock is
// turned off or a pin removed, as on a phone, and in the decoy for its own
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_setup_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';

import '../pin_flow_fakes.dart';

void _desk(WidgetTester t) {
  t.view.physicalSize = const Size(1440, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _pin(WidgetTester t, String pin) async {
  await typePin(t, pin);
  await enter(t);
  await t.pump(const Duration(milliseconds: 300));
  await t.pumpAndSettle();
}

void main() {
  setUp(() {
    onDesktop = true;
    decoyReady = true;
  });
  tearDown(() => onDesktop = false);

  for (final decoy in [false, true]) {
    final side = decoy ? 'in the decoy' : 'everyday';
    final pin = decoy ? decoyPin : appPin;
    Future<Lock> make() => makeLock(
      {
        ...appOnly,
        PinSlot.wipe: (wipePin, PinKind.wipe),
        if (decoy) PinSlot.decoy: (decoyPin, PinKind.decoy),
        if (decoy) PinSlot.decoyWipe: ('7777', PinKind.wipe),
      },
      wipeOn: true,
      inDecoy: decoy,
      stored: {if (decoy) 'halo.lock.d.wipe': 'true'},
    );

    testWidgets('$side: turning the lock off asks for the pin, a wrong one '
        'changes nothing', (t) async {
      _desk(t);
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
      expect(find.text(l10n.pinsUnlockWithFingerprint), findsNothing);
      await _tap(t, find.text(l10n.pinsTurnOff));
      await _tap(t, find.text(l10n.pinsTurnOff).last);
      expect(find.byType(LockSetupScreen), findsOneWidget);
      expect(find.text(l10n.flowEnterYourPin), findsOneWidget);
      await _pin(t, decoy ? appPin : '0000');
      expect(find.text(l10n.lockNotIt), findsOneWidget);
      expect(lock.state.lockOn, isTrue);
      await _pin(t, pin);
      expect(find.byType(LockSetupScreen), findsNothing);
      expect(lock.state.lockOn, isFalse);
    });

    testWidgets('$side: removing the wipe pin asks for the pin', (t) async {
      _desk(t);
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
      await _tap(t, find.text(l10n.pinsAdvanced));
      await _tap(t, find.text(l10n.pinsWipePin).first);
      await _tap(t, find.text(l10n.pinsRemove));
      await _tap(t, find.text(l10n.commonRemove).last);
      expect(find.text(l10n.flowEnterYourPin), findsOneWidget);
      await _pin(t, '0000');
      expect(lock.state.panicEnabled, isTrue);
      await _pin(t, pin);
      expect(lock.state.panicEnabled, isFalse);
    });
  }
}
