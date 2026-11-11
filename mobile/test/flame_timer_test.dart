// SPDX-License-Identifier: GPL-3.0-or-later
// the flame's sheet: a tap picks how long timed messages live, and while a
// timer is on "Off" sits on top. one sheet for chats and groups
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/burn_sheet.dart';

void main() {
  setUp(() => setL10nLocale(const Locale('en')));

  Future<int?> open(
    WidgetTester t, {
    required bool on,
    int secs = 3600,
    bool short = true,
    String? pick,
    double scale = 1,
  }) async {
    int? got;
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                got = await showBurnSheet(c, on: on, secs: secs, short: short);
                done = true;
              },
              child: const Text('flame'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('flame'));
    await t.pumpAndSettle();
    if (pick != null) {
      await t.tap(find.text(pick));
      await t.pumpAndSettle();
      expect(done, isTrue);
    }
    return got;
  }

  double y(WidgetTester t, String s) => t.getTopLeft(find.text(s)).dy;

  testWidgets('off: the times only, shortest first; a pick hands it back', (
    t,
  ) async {
    expect(await open(t, on: false), isNull);
    expect(find.text(l10n.commonOff), findsNothing);
    expect(y(t, l10n.chat30Seconds), lessThan(y(t, l10n.chat1Minute)));
    expect(y(t, l10n.chat1Hour), lessThan(y(t, l10n.chat24Hours)));
    await t.tap(find.text(l10n.chat5Minutes));
    await t.pumpAndSettle();
    expect(find.text(l10n.chat5Minutes), findsNothing, reason: 'closed');
  });

  testWidgets('on: "Off" on top, and picking it turns the timer off', (
    t,
  ) async {
    final got = await open(t, on: true, pick: l10n.commonOff);
    expect(got, kBurnOff);
  });

  testWidgets('on: "Off" above every time', (t) async {
    await open(t, on: true);
    for (final s in [l10n.chat30Seconds, l10n.chat24Hours]) {
      expect(y(t, l10n.commonOff), lessThan(y(t, s)));
    }
  });

  testWidgets('a time picked comes back in seconds', (t) async {
    expect(await open(t, on: false, pick: l10n.chat1Hour), 3600);
  });

  testWidgets('an answer the phone sends offers an hour at least', (t) async {
    await open(t, on: false, short: false);
    expect(find.text(l10n.chat30Seconds), findsNothing);
    expect(find.text(l10n.chat1Hour), findsOneWidget);
  });

  testWidgets('fits at 1.5x text', (t) async {
    t.view.physicalSize = const Size(640, 1200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await open(t, on: true, scale: 1.5);
    expect(t.takeException(), isNull);
  });

  test('both screens open the sheet from a tap on the flame', () {
    final one = File('lib/screens/chat_screen.dart').readAsStringSync();
    final group = File('lib/screens/group_chat_screen.dart').readAsStringSync();
    expect(one, contains('onToggleGhost: _pickBurnDuration,'));
    expect(group, contains('onToggleGhost: _showBurnPicker,'));
    expect(one, contains('showBurnSheet('));
    expect(group, contains('showBurnSheet('));
  });
}
