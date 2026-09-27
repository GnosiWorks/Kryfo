// SPDX-License-Identifier: GPL-3.0-or-later
// the wallpaper picker: each swatch shows its atmosphere, the one picked
// gets its ring and tick with a pop that comes to rest, the tick sits at
// the end side in either direction, nothing pops with less movement, and
// the moods heading speaks the phone's language.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/wallpaper_sheet.dart';

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  late List<Atmo> previews;

  Future<void> open(
    WidgetTester t, {
    bool still = false,
    TextDirection dir = TextDirection.ltr,
  }) async {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    previews = [];
    await t.pumpWidget(
      host(
        Builder(
          builder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                showWallpaperSheet(ctx, Atmo.none, onPreview: previews.add),
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
        still: still,
        dir: dir,
      ),
    );
    await t.tap(find.byType(GestureDetector).first);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
  }

  Finder swatch(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(Column));

  double scaleOfTick(WidgetTester t, String label) => t
      .widget<AnimatedScale>(
        find
            .descendant(
              of: swatch(label).first,
              matching: find.byType(AnimatedScale),
            )
            .last,
      )
      .scale;

  testWidgets('a pick pops its ring and tick in, then rests', (t) async {
    await open(t);
    expect(find.text(l10n.wallpaperMoods), findsOneWidget);
    expect(scaleOfTick(t, l10n.atmosphereDusk), lessThan(1));
    await t.tap(find.text(l10n.atmosphereDusk));
    await t.pump();
    expect(previews, [Atmo.dusk]);
    expect(scaleOfTick(t, l10n.atmosphereDusk), 1);
    await t.pump(const Duration(milliseconds: 60));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pumpAndSettle();
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion: nothing pops', (t) async {
    await open(t, still: true);
    expect(scaleOfTick(t, l10n.atmosphereDusk), 1);
    await t.tap(find.text(l10n.atmosphereDusk));
    await t.pumpAndSettle();
    final scales = t.widgetList<AnimatedScale>(
      find.descendant(
        of: swatch(l10n.atmosphereDusk).first,
        matching: find.byType(AnimatedScale),
      ),
    );
    for (final s in scales) {
      expect(s.duration, Duration.zero);
    }
  });

  testWidgets('right to left: the tick sits at the round\'s left', (t) async {
    await open(t, dir: TextDirection.rtl);
    await t.tap(find.text(l10n.atmosphereDusk));
    await t.pumpAndSettle();
    final tick = t.getCenter(
      find.descendant(
        of: swatch(l10n.atmosphereDusk).first,
        matching: find.byIcon(Icons.check_rounded),
      ),
    );
    final word = t.getCenter(find.text(l10n.atmosphereDusk));
    expect(tick.dx, lessThan(word.dx));
  });

  testWidgets('the moods heading is in the phone\'s language', (t) async {
    setL10nLocale(const Locale('de'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    await open(t);
    expect(find.text('Stimmungen'), findsOneWidget);
    expect(find.text('moods'), findsNothing);
  });
}
