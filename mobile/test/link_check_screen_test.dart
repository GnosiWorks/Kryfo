// SPDX-License-Identifier: GPL-3.0-or-later
// what a linked computer shows while its start check runs: the gate, in
// every language, on a small window with big text and with reduced
// motion, and pixel for pixel on a computer in dark and light. the chats
// read only: the strip stands where the composer was, and goes once the
// check let it go
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/link_check.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/link_check_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/link_wait_strip.dart';

import 'narrow_settings.dart' show loadAppFonts;

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildHaloTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

void main() {
  tearDown(() {
    linkCheck.value = null;
    setL10nLocale(const Locale('en'));
  });

  testWidgets('the gate says what it waits for, in every language', (t) async {
    final en = <String>{};
    for (final loc in AppLocalizations.supportedLocales) {
      setL10nLocale(loc);
      await t.pumpWidget(
        _app(LinkCheckScreen(key: ValueKey(loc)), locale: loc),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text(l10n.linkCheckTitle), findsOneWidget, reason: '$loc');
      expect(find.text(l10n.linkCheckLine), findsOneWidget, reason: '$loc');
      expect(t.takeException(), isNull, reason: '$loc');
      final words = {
        l10n.linkCheckTitle,
        l10n.linkCheckLine,
        l10n.linkCheckWaitLine,
      };
      if (loc.languageCode == 'en') {
        en.addAll(words);
        // sentence case, no dash
        for (final w in words) {
          expect(w[0], w[0].toUpperCase());
          expect(w.contains('—'), isFalse);
        }
      } else {
        for (final w in words) {
          expect(en.contains(w), isFalse, reason: '$loc $w');
        }
      }
    }
  });

  testWidgets('big text in a small window does not clip, and reduced motion '
      'settles at once', (t) async {
    setL10nLocale(const Locale('de'));
    t.view.physicalSize = const Size(320, 480);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 480),
          textScaler: TextScaler.linear(1.8),
          disableAnimations: true,
        ),
        child: _app(const LinkCheckScreen(), locale: const Locale('de')),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    // nothing runs on with motion off
    await t.pumpAndSettle();
    expect(find.text(l10n.linkCheckTitle), findsOneWidget);
  });

  testWidgets('read only: the strip stands in for the composer until the '
      'check lets it go, and never while nothing is held', (t) async {
    setL10nLocale(const Locale('en'));
    final composer = const Text('composer');
    await t.pumpWidget(
      _app(const Scaffold(body: LinkHeldSwap(child: Text('composer')))),
    );
    expect(find.text('composer'), findsOneWidget);
    expect(find.text(l10n.linkCheckWaitLine), findsNothing);

    linkCheck.value = LinkCheckStage.readOnly;
    await t.pump();
    expect(find.text('composer'), findsNothing);
    expect(find.text(l10n.linkCheckWaitLine), findsOneWidget);

    linkCheck.value = null;
    await t.pump();
    expect(find.text(composer.data!), findsOneWidget);
    expect(find.text(l10n.linkCheckWaitLine), findsNothing);
  });

  group('pixel for pixel', () {
    setUpAll(loadAppFonts);
    for (final (v, light) in [('dark', false), ('light', true)]) {
      testWidgets('the gate on a computer, $v', (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        HaloColors.setLight(light);
        addTearDown(() => HaloColors.setLight(false));
        setL10nLocale(const Locale('en'));
        await t.pumpWidget(_app(const LinkCheckScreen()));
        await t.pump(const Duration(milliseconds: 600));
        await expectLater(
          find.byType(LinkCheckScreen),
          matchesGoldenFile('goldens/link_check_desk_$v.png'),
        );
      });
      testWidgets('the chats read only, the strip on a computer, $v', (
        t,
      ) async {
        t.view.physicalSize = const Size(720, 160);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        HaloColors.setLight(light);
        addTearDown(() => HaloColors.setLight(false));
        setL10nLocale(const Locale('en'));
        linkCheck.value = LinkCheckStage.readOnly;
        await t.pumpWidget(
          _app(
            Scaffold(
              backgroundColor: HaloColors.surface,
              body: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [LinkHeldSwap(child: SizedBox.shrink())],
              ),
            ),
          ),
        );
        await t.pump();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/link_wait_desk_$v.png'),
        );
      });
    }
  });
}
