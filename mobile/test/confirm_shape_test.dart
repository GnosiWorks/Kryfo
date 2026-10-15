// SPDX-License-Identifier: GPL-3.0-or-later
// a button that destroys says so by its shape as well as its rose: the red
// accent sits close to it, so colour alone would not tell them apart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/confirm_sheet.dart';

void main() {
  tearDown(() => HaloColors.setAccent(HaloAccent.yellow));

  Future<void> open(WidgetTester t, {required bool rose}) async {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    HaloColors.setAccent(HaloAccent.velvet);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showConfirmSheet(
                ctx,
                title: 'Delete',
                line: 'It goes',
                yes: 'Go on',
                rose: rose,
              ),
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(GestureDetector).first);
    await t.pumpAndSettle();
  }

  testWidgets('the destroying answer carries its warning mark', (t) async {
    await open(t, rose: true);
    final mark = find.byIcon(Icons.warning_amber_rounded);
    expect(mark, findsOneWidget);
    // on the button itself, beside its words
    expect(
      (t.getCenter(mark).dy - t.getCenter(find.text('Go on')).dy).abs(),
      lessThan(4),
    );
  });

  testWidgets('an answer in the accent has none', (t) async {
    await open(t, rose: false);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.text('Go on'), findsOneWidget);
  });
}
