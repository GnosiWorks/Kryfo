// SPDX-License-Identifier: GPL-3.0-or-later
// the pad's looks may move, its timing may not: a wrong pin clears at the
// same moment with or without movement, the backdrop breathes once and
// rests, and the setup's second step comes in from the side reading goes
// towards.
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/screens/lock_setup_screen.dart';
import 'package:kryfo/widgets/pin_pad.dart';
import 'package:kryfo/widgets/tor_boot_splash.dart';

import 'pin_flow_fakes.dart';

Widget framed(Widget home, {bool still = false, bool rtl = false}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
      home: home,
    );

Rect dots(WidgetTester t) => t.getRect(
  find.descendant(of: find.byType(PinDots), matching: find.byType(Row)),
);

int filled(WidgetTester t) => t.widget<PinDots>(find.byType(PinDots)).filled;

// a wrong pin, stepped through: when the dots clear and how far they move
Future<(int, double)> wrong(WidgetTester t, {required bool still}) async {
  phone(t);
  final lock = await makeLock(appOnly);
  await t.pumpWidget(framed(LockScreen(lock: lock.state), still: still));
  await t.pump(const Duration(seconds: 2));
  final rest = dots(t);
  await typePin(t, '4321');
  await enter(t);
  var cleared = -1;
  var moved = 0.0;
  for (var ms = 0; ms <= 1000; ms += 20) {
    final r = dots(t);
    final dx = (r.center.dx - rest.center.dx).abs();
    if (dx > moved) moved = dx;
    if (filled(t) == 0) {
      cleared = ms;
      break;
    }
    await t.pump(const Duration(milliseconds: 20));
  }
  await t.pump(const Duration(seconds: 2));
  await t.pumpWidget(const SizedBox());
  return (cleared, moved);
}

void main() {
  group('the lock screen', () {
    testWidgets('the backdrop breathes in once, then rests', (t) async {
      phone(t);
      final lock = await makeLock(appOnly);
      await t.pumpWidget(framed(LockScreen(lock: lock.state)));
      await t.pump(const Duration(milliseconds: 200));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 1800));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a wrong pin clears at the same moment, moving or not', (
      t,
    ) async {
      final (movingAt, movingBy) = await wrong(t, still: false);
      final (stillAt, stillBy) = await wrong(t, still: true);
      expect(movingAt, greaterThan(0));
      expect(stillAt, movingAt);
      expect(movingBy, greaterThan(1), reason: 'the dots shake');
      expect(stillBy, 0, reason: 'with less movement they hold still');
    });
  });

  group('setting a pin', () {
    // how the confirm step's title is sliding in, mid-way
    Future<double> slide(WidgetTester t, {required bool rtl}) async {
      phone(t);
      await t.pumpWidget(framed(const LockSetupScreen(), rtl: rtl));
      await typePin(t, '1234');
      await enter(t);
      await t.pump(const Duration(milliseconds: 230));
      await t.pump(const Duration(milliseconds: 60));
      final s = t.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text(l10n.lockSetupOnceMore),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      final dx = s.position.value.dx;
      await t.pump(const Duration(milliseconds: 400));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
      return dx;
    }

    testWidgets('the second step comes in from the side reading goes to', (
      t,
    ) async {
      expect(await slide(t, rtl: false), greaterThan(0));
      expect(await slide(t, rtl: true), lessThan(0));
    });

    testWidgets('reduced motion: a mismatch does not shake', (t) async {
      phone(t);
      await t.pumpWidget(framed(const LockSetupScreen(), still: true));
      await typePin(t, '1234');
      await enter(t);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.lockSetupOnceMore), findsOneWidget);
      final rest = dots(t);
      await typePin(t, '9999');
      await enter(t);
      for (var i = 0; i < 10; i++) {
        expect(dots(t).center.dx, rest.center.dx);
        await t.pump(const Duration(milliseconds: 30));
      }
      expect(find.text(l10n.lockSetupSetAPin), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('the boot splash holds still with less movement', (t) async {
    phone(t);
    await t.pumpWidget(framed(const TorBootSplash(), still: true));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpWidget(framed(const TorBootSplash()));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.hasRunningAnimations, isTrue, reason: 'while tor is on its way');
    await t.pumpWidget(const SizedBox());
  });
}
