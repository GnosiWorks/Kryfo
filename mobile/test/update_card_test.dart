// SPDX-License-Identifier: GPL-3.0-or-later
// the update card: what it says, that a tap opens the download page and the
// cross puts it away for that version, and that it holds still when the
// phone asks for no movement
import 'dart:convert';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/open_outside.dart';
import 'package:kryfo/update_check.dart';
import 'package:kryfo/widgets/update_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<Uri> opened;
  late String served;
  late DateTime now;
  final k = ed.generateKey();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    opened = [];
    served = '0.5.1';
    now = DateTime(2026, 10, 11, 9);
    openOutsideForTest = (u) async {
      opened.add(u);
      return true;
    };
  });

  tearDown(() {
    openOutsideForTest = null;
    updateNoticeForTest = null;
  });

  UpdateNotice notice() => UpdateNotice(
    get: (url) async {
      final body = '{"app":"kryfo","version":"$served"}\n';
      return url == kVersionUrl
          ? body
          : base64.encode(ed.sign(k.privateKey, utf8.encode(body)));
    },
    torUp: () => true,
    quiet: () => false,
    container: () => HaloContainer.everyday,
    playBuild: false,
    install: () async => const InstallInfo(version: '0.5.0'),
    now: () => now,
    pubKeyB64: base64.encode(k.publicKey.bytes),
  );

  Widget app(Widget child, {bool still = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Scaffold(body: Column(children: [child])),
    ),
  );

  testWidgets('says what is new and opens the download page', (t) async {
    final n = notice();
    updateNoticeForTest = n;
    await t.runAsync(n.check);
    await t.pumpWidget(app(const UpdateHint()));
    await t.pumpAndSettle();
    expect(find.text(l10n.updateAvailable), findsOneWidget);
    expect(find.text(l10n.updateReady('0.5.1')), findsOneWidget);
    await t.tap(find.text(l10n.updateAvailable));
    await t.pumpAndSettle();
    expect(opened, [Uri.parse('https://kryfo.app/download')]);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('nothing to show: no card', (t) async {
    served = '0.5.0';
    final n = notice();
    updateNoticeForTest = n;
    await t.runAsync(n.check);
    await t.pumpWidget(app(const UpdateHint()));
    await t.pumpAndSettle();
    expect(find.text(l10n.updateAvailable), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the cross puts it away until the next version', (t) async {
    final n = notice();
    updateNoticeForTest = n;
    await t.runAsync(n.check);
    await t.pumpWidget(app(const UpdateHint()));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel(l10n.homeNotNow));
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pumpAndSettle();
    expect(find.text(l10n.updateAvailable), findsNothing);
    expect(opened, isEmpty);
    served = '0.5.2';
    now = now.add(const Duration(days: 1));
    await t.runAsync(n.check);
    await t.pumpAndSettle();
    expect(find.text(l10n.updateReady('0.5.2')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the arrow drops in, then rests', (t) async {
    await t.pumpWidget(app(UpdateMark(color: Colors.green)));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion: the arrow is at rest from the start', (t) async {
    await t.pumpWidget(app(UpdateMark(color: Colors.green), still: true));
    await t.pump();
    expect(t.binding.hasScheduledFrame, isFalse);
  });
}
