// SPDX-License-Identifier: GPL-3.0-or-later
// the one sheet: it rises, and with less movement it is simply there
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/halo_sheet.dart';

Widget _app({required bool still}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: c!,
  ),
  home: Builder(
    builder: (ctx) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showHaloSheet<void>(
            ctx,
            builder: (_) => const SizedBox(height: 200, child: Text('inside')),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('it rises', (t) async {
    await t.pumpWidget(_app(still: false));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpAndSettle();
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('with less movement it is there at once, and gone at once', (
    t,
  ) async {
    await t.pumpWidget(_app(still: true));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump();
    expect(find.text('inside'), findsOneWidget);
    // where it rests, on the first frame (the button's own ink may run on)
    final first = t.getTopLeft(find.text('inside'));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('inside')), first);
    await t.tapAt(const Offset(10, 10));
    await t.pump();
    await t.pump();
    expect(find.text('inside'), findsNothing);
  });
}
