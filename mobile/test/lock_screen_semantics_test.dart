// SPDX-License-Identifier: GPL-3.0-or-later
// the lock screen to a screen reader: the dots say how many digits are in
// and never which, a wrong pin is heard once, a hold is heard once and not
// every second, and a right pin of any kind says nothing
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/widgets/pin_pad.dart';

import 'a11y_fakes.dart';
import 'pin_flow_fakes.dart';

const Map<int, (String, int)> _all = {
  ...appOnly,
  PinSlot.decoy: (decoyPin, PinKind.decoy),
  PinSlot.vault: (vaultPin, PinKind.vault),
};

Future<void> _type(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.text(d).last);
    await t.pump();
  }
}

Future<void> _enter(WidgetTester t) async {
  await t.tap(find.bySemanticsLabel(l10n.commonDone));
  await t.pump();
  await t.pump();
}

void main() {
  setUp(() => decoyReady = true);

  testWidgets('the dots say the count of digits, never the digits', (t) async {
    final h = t.ensureSemantics();
    final lock = await makeLock(appOnly);
    lock.state.lock();
    await t.pumpWidget(bare(LockScreen(lock: lock.state), still: true));
    await t.pumpAndSettle();
    expect(t.getSemantics(find.byType(PinDots)).value, l10n.a11yPinDigits(0));
    await _type(t, '739');
    final dots = t.getSemantics(find.byType(PinDots));
    expect(dots.label, l10n.lockYourPin);
    expect(dots.value, l10n.a11yPinDigits(3));
    expect(dots.value, isNot(contains('7')));
    await t.pumpWidget(const SizedBox());
    h.dispose();
  });

  testWidgets('a wrong pin is heard once, as the words on screen', (t) async {
    final heard = hearAnnouncements(t);
    final lock = await makeLock(appOnly);
    lock.state.lock();
    await t.pumpWidget(bare(LockScreen(lock: lock.state), still: true));
    await t.pumpAndSettle();
    await _type(t, '0000');
    await _enter(t);
    await t.pumpAndSettle();
    expect(heard, [l10n.lockNotIt]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a hold is heard once, not every second', (t) async {
    final heard = hearAnnouncements(t);
    final lock = await makeLock(appOnly);
    final s = lock.state;
    s.lock();
    await t.pumpWidget(bare(LockScreen(lock: s), still: true));
    await t.pumpAndSettle();
    var tries = 0;
    while (s.throttleLeft == Duration.zero && tries < 30) {
      await _type(t, '0000');
      await _enter(t);
      await t.pumpAndSettle();
      tries++;
    }
    expect(s.throttleLeft, greaterThan(Duration.zero));
    // one line per wrong pin, the last the hold's own
    expect(heard.length, tries);
    expect(heard.last, isNot(l10n.lockNotIt));
    final n = heard.length;
    await t.pump(const Duration(seconds: 3));
    expect(heard.length, n);
    await t.pumpWidget(const SizedBox());
  });

  for (final (name, pin) in [
    ('everyday', appPin),
    ('decoy', decoyPin),
    ('hidden chats', vaultPin),
  ]) {
    testWidgets('the $name pin says nothing', (t) async {
      final heard = hearAnnouncements(t);
      final lock = await makeLock(_all);
      final s = lock.state;
      s.onOutcome = (r, {vaultKey}) async {};
      s.lock();
      await t.pumpWidget(bare(LockScreen(lock: s), still: true));
      await t.pumpAndSettle();
      await _type(t, pin);
      await _enter(t);
      await t.pumpAndSettle();
      expect(heard, isEmpty);
      await t.pumpWidget(const SizedBox());
    });
  }
}
