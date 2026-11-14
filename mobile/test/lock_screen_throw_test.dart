// SPDX-License-Identifier: GPL-3.0-or-later
// a pin check that throws (the store will not write, the engine's table
// will not read) gives the pad back: never stuck on its stars until the
// app is killed
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/widgets/pin_pad.dart';

import 'a11y_fakes.dart';
import 'pin_flow_fakes.dart';

class _Flaky extends MemStore {
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('store full');
    return super.write(key, value);
  }
}

Future<void> _type(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.text(d).last);
    await t.pump();
  }
}

void main() {
  setUp(() => decoyReady = true);

  testWidgets('a check that throws gives the pad back', (t) async {
    final h = t.ensureSemantics();
    final base = await makeLock(appOnly);
    final store = _Flaky()..m.addAll(base.store.m);
    final s = LockState(
      store: store,
      engine: MemEngine(),
      clock: StillClock(),
      bio: NoBio(),
      revealAfter: Duration.zero,
      sealWait: const Duration(seconds: 30),
      dropWait: const Duration(seconds: 5),
    );
    await s.load();
    s.lock();
    await t.pumpWidget(bare(LockScreen(lock: s), still: true));
    await t.pumpAndSettle();
    store.fail = true;
    await _type(t, '0000');
    await t.tap(find.bySemanticsLabel(l10n.commonDone));
    await t.pumpAndSettle();
    // the stars went and the pad takes digits again
    expect(t.getSemantics(find.byType(PinDots)).value, l10n.a11yPinDigits(0));
    await _type(t, '73');
    expect(t.getSemantics(find.byType(PinDots)).value, l10n.a11yPinDigits(2));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    h.dispose();
  });
}
