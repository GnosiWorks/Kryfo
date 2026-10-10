// SPDX-License-Identifier: GPL-3.0-or-later
// a tapped link goes to another app without asking canLaunchUrl first: on
// android 11 and later that answers no for every scheme the manifest does
// not list, and the tap did nothing
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/open_outside.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/link_stub.dart';

Widget framed(Widget child) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() => openOutsideForTest = null);

  testWidgets('a tapped link card goes to the app that takes it', (t) async {
    final asked = <Uri>[];
    openOutsideForTest = (u) async {
      asked.add(u);
      return true;
    };
    await t.pumpWidget(
      framed(const LinkStub(url: 'https://kryfo.app/testers', isOut: false)),
    );
    await t.tap(find.byType(LinkStub));
    await t.pumpAndSettle();
    expect(asked, [Uri.parse('https://kryfo.app/testers')]);
    expect(find.text(l10n.linkNoAppOpens), findsNothing);
  });

  testWidgets('a link no app takes says so', (t) async {
    openOutsideForTest = (u) async => false;
    await t.pumpWidget(
      framed(const LinkStub(url: 'https://omaps.app/abc', isOut: true)),
    );
    await t.tap(find.byType(LinkStub));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.linkNoAppOpens), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  test('a launch that throws reads as not taken', () async {
    openOutsideForTest = (u) async => throw StateError('no activity');
    expect(await openOutside(Uri.parse('geo:0,0')), isFalse);
  });

  test('nothing in the app asks canLaunchUrl', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('canLaunchUrl('))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
  });
}
