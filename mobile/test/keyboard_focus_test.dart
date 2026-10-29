// SPDX-License-Identifier: GPL-3.0-or-later
// the house's buttons by keyboard: tab finds them, enter and space press
// them, a ring shows while the keyboard is in use and never for touch. the
// pin pad takes digits, backspace and enter from a hardware keyboard
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/pass_pad.dart';
import 'package:kryfo/widgets/pin_pad.dart';
import 'package:kryfo/widgets/press_scale.dart';

import 'a11y_fakes.dart';
import 'pin_flow_fakes.dart';

final _ring = find.byKey(const ValueKey('key ring'));

void main() {
  testWidgets('tab reaches a button, enter and space press it', (t) async {
    var taps = 0;
    await t.pumpWidget(
      bare(
        Scaffold(
          body: Center(
            child: PressScale(onTap: () => taps++, child: const Text('Save')),
          ),
        ),
        still: true,
      ),
    );
    expect(_ring, findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_ring, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(taps, 2);
  });

  testWidgets('the ring goes when touch comes back', (t) async {
    await t.pumpWidget(
      bare(
        Scaffold(
          body: Center(
            child: PressScale(onTap: () {}, child: const Text('Save')),
          ),
        ),
        still: true,
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_ring, findsOneWidget);
    await t.tap(find.text('Save'));
    await t.pump();
    expect(_ring, findsNothing);
  });

  testWidgets('a button with nothing to do takes no focus', (t) async {
    await t.pumpWidget(
      bare(
        const Scaffold(
          body: Center(child: PressScale(child: Text('Info'))),
        ),
        still: true,
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_ring, findsNothing);
  });

  testWidgets('space turns a switch', (t) async {
    var on = false;
    await t.pumpWidget(
      bare(
        StatefulBuilder(
          builder: (_, set) => Scaffold(
            body: Center(
              child: HaloSwitch(value: on, onChanged: (v) => set(() => on = v)),
            ),
          ),
        ),
        still: true,
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(on, isTrue);
  });

  testWidgets('the lock screen takes a typed pin and enter', (t) async {
    decoyReady = true;
    final lock = await makeLock(appOnly);
    final s = lock.state;
    final seen = <PinResult>[];
    s.onOutcome = (r, {vaultKey}) async => seen.add(r);
    s.lock();
    await t.pumpWidget(bare(LockScreen(lock: s), still: true));
    await t.pumpAndSettle();
    for (final k in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.digit9,
    ]) {
      await t.sendKeyEvent(k);
      await t.pump();
    }
    expect(t.getSemantics(find.byType(PinDots)).value, l10n.a11yPinDigits(3));
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(t.getSemantics(find.byType(PinDots)).value, l10n.a11yPinDigits(2));
    // the rest of the pin, then enter
    // a frame between keys, as between any two a person types
    await t.sendKeyEvent(LogicalKeyboardKey.digit3);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.digit4);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(seen, [PinResult.normal]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('back from letters, the pad takes typed digits again', (t) async {
    final letters = ValueNotifier(false);
    final typed = <String>[];
    await t.pumpWidget(
      bare(
        Scaffold(
          body: Center(
            child: ValueListenableBuilder(
              valueListenable: letters,
              builder: (_, on, _) => PassPad(
                letters: on,
                onLetters: (v) => letters.value = v,
                onDigit: typed.add,
                onBack: () {},
                onText: (_) {},
                text: '',
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    letters.value = true;
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    // off the field to the 123 key, and pressed
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pumpAndSettle();
    expect(letters.value, isFalse);
    expect(find.byType(TextField), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.digit7);
    await t.pump();
    expect(typed, ['7']);
    await t.pumpWidget(const SizedBox());
  });
}
