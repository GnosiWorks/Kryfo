// SPDX-License-Identifier: GPL-3.0-or-later
// the startup screen sits on the middle of the screen, to the pixel, on the
// phone sizes people have: with a cutout or a navigation bar on one edge,
// at a large text size, in either orientation and right to left
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/onion_loader.dart';
import 'package:kryfo/widgets/tor_boot_splash.dart';

import 'narrow_settings.dart' show loadAppFonts;

// a phone in physical pixels, and the insets android gives it
typedef _Phone = ({
  String name,
  Size px,
  double ratio,
  ({double left, double top, double right, double bottom}) pad,
});

const _none = (left: 0.0, top: 0.0, right: 0.0, bottom: 0.0);

List<_Phone> _phones() {
  final out = <_Phone>[];
  // 360x800, 412x915 and a 6.7 inch 1080x2400 at 394 ppi
  final sizes = [
    (name: '360x800', px: const Size(1080, 2400), ratio: 3.0),
    (name: '412x915', px: const Size(412 * 2.625, 915 * 2.625), ratio: 2.625),
    (name: '1080x2400 394ppi', px: const Size(1080, 2400), ratio: 394 / 160),
  ];
  for (final s in sizes) {
    final r = s.ratio;
    out.addAll([
      (name: '${s.name} bare', px: s.px, ratio: r, pad: _none),
      // a punch hole up top and a gesture bar below
      (
        name: '${s.name} cutout',
        px: s.px,
        ratio: r,
        pad: (left: 0.0, top: 44 * r, right: 0.0, bottom: 24 * r),
      ),
      // turned: the cutout on one side, three buttons on the other
      (
        name: '${s.name} landscape cutout',
        px: s.px.flipped,
        ratio: r,
        pad: (left: 32 * r, top: 24 * r, right: 0.0, bottom: 0.0),
      ),
      (
        name: '${s.name} landscape buttons',
        px: s.px.flipped,
        ratio: r,
        pad: (left: 0.0, top: 24 * r, right: 48 * r, bottom: 0.0),
      ),
    ]);
  }
  return out;
}

Future<void> _open(
  WidgetTester t,
  _Phone p, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  t.view.physicalSize = p.px;
  t.view.devicePixelRatio = p.ratio;
  final pad = FakeViewPadding(
    left: p.pad.left,
    top: p.pad.top,
    right: p.pad.right,
    bottom: p.pad.bottom,
  );
  t.view.padding = pad;
  t.view.viewPadding = pad;
  addTearDown(t.view.reset);
  setL10nLocale(locale);
  addTearDown(() => setL10nLocale(const Locale('en')));
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: const TorBootSplash(),
    ),
  );
  await t.pump(const Duration(seconds: 1));
}

// how far each part's middle is from the screen's, in physical pixels
Map<String, double> _offMiddle(WidgetTester t, _Phone p) {
  final mid = p.px.width / p.ratio / 2;
  double off(Finder f) => (t.getRect(f).center.dx - mid).abs() * p.ratio;
  return {
    'onion': off(find.byType(OnionLoader)),
    'title': off(find.text(l10n.torBootSplashNoShortcutsNoTraces)),
    'line': off(find.text(l10n.torBootSplashMadeOnThisPhone)),
    // the middle hop's dot sits over its name
    'middle hop': off(find.text(l10n.torBootSplashHopMiddle)),
    'hops': off(
      find.ancestor(
        of: find.text(l10n.torBootSplashHopMiddle),
        matching: find.byType(FittedBox),
      ),
    ),
    'first launch': off(find.text(l10n.torBootSplashFirstLaunchTakesA)),
  };
}

void _centred(WidgetTester t, _Phone p, String why) {
  expect(t.takeException(), isNull, reason: why);
  for (final e in _offMiddle(t, p).entries) {
    expect(e.value, lessThanOrEqualTo(1), reason: '$why: ${e.key}');
  }
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  for (final p in _phones()) {
    testWidgets('on the middle: ${p.name}', (t) async {
      await _open(t, p);
      _centred(t, p, p.name);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('on the middle at a large text size', (t) async {
    for (final p in _phones()) {
      await _open(t, p, scale: 1.6);
      _centred(t, p, '${p.name} x1.6');
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('on the middle right to left', (t) async {
    for (final lang in ['ar', 'fa']) {
      for (final p in _phones()) {
        await _open(t, p, locale: Locale(lang));
        _centred(t, p, '${p.name} $lang');
        // the first hop is on the right
        final entry = t.getCenter(find.text(l10n.torBootSplashHopEntry));
        final exit = t.getCenter(find.text(l10n.torBootSplashHopExit));
        expect(entry.dx, greaterThan(exit.dx), reason: '${p.name} $lang');
      }
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the hops sit evenly about the middle one', (t) async {
    final p = _phones().first;
    for (final loc in AppLocalizations.supportedLocales) {
      await _open(t, p, locale: loc);
      final names = find.descendant(
        of: find.byType(FittedBox),
        matching: find.byType(Text),
      );
      expect(names, findsNWidgets(3), reason: '$loc');
      final x = [
        for (final e in names.evaluate())
          t.getCenter(find.byWidget(e.widget)).dx,
      ];
      expect(
        ((x[1] - x[0]).abs() - (x[2] - x[1]).abs()).abs() * p.ratio,
        lessThan(1),
        reason: '$loc',
      );
      expect(
        (x[1] - p.px.width / p.ratio / 2).abs() * p.ratio,
        lessThan(1),
        reason: '$loc',
      );
    }
    await t.pumpWidget(const SizedBox());
  });
}
