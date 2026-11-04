// SPDX-License-Identifier: GPL-3.0-or-later
// what a linked device shows once it unlinked: why, in plain words, that
// the phone keeps the chats, and a way to close. every reason in every
// language, big text on a small screen, reduced motion
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/linked_lock.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/unlinked_screen.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

void main() {
  testWidgets('each reason says what happened, and closing asks nothing', (
    t,
  ) async {
    setL10nLocale(const Locale('en'));
    for (final why in LinkedEnd.values) {
      var closed = 0;
      await t.pumpWidget(
        _app(
          UnlinkedScreen(key: ValueKey(why), why: why, onClose: () => closed++),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.unlinkedTitle), findsOneWidget);
      expect(find.text(unlinkedLine(why)), findsOneWidget);
      expect(find.text(l10n.unlinkedAgainLine), findsOneWidget);
      await t.tap(find.text(l10n.unlinkedClose));
      expect(closed, 1);
    }
    // five reasons, five lines
    expect({for (final w in LinkedEnd.values) unlinkedLine(w)}, hasLength(5));
  });

  testWidgets('every language has its own words for it', (t) async {
    final en = <String>{};
    setL10nLocale(const Locale('en'));
    for (final w in LinkedEnd.values) {
      en.add(unlinkedLine(w));
    }
    for (final loc in AppLocalizations.supportedLocales) {
      if (loc.languageCode == 'en') continue;
      setL10nLocale(loc);
      for (final w in LinkedEnd.values) {
        expect(en.contains(unlinkedLine(w)), isFalse, reason: '$loc $w');
      }
      expect(l10n.unlinkedTitle, isNot('This device is unlinked'));
    }
    setL10nLocale(const Locale('en'));
  });

  testWidgets('big text on a small phone does not clip, and reduced motion '
      'settles at once', (t) async {
    setL10nLocale(const Locale('en'));
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.6),
          disableAnimations: true,
        ),
        child: _app(UnlinkedScreen(why: LinkedEnd.broken, onClose: () {})),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text(l10n.unlinkedClose), findsOneWidget);
  });
}
