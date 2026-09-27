// SPDX-License-Identifier: GPL-3.0-or-later
// the safety number turns green group by group when it is marked verified
// here, and is simply green when it was verified before; the what we can
// see table marks the route in use with a band, never by dimming the other
// words; introductions come in row by row and a pick pops its tick. all of
// it rests, reading order is followed right to left, and with less
// movement nothing cascades or pops.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/screens/introduce_sheet.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/screens/seen_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: child,
);

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

const _groups = ['11111', '22222', '33333', '44444', '55555', '66666'];

Color colourOf(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!.color!;

// how far a colour has gone from the text colour toward green
double greenness(Color c) {
  final from = HaloColors.text;
  final to = HaloColors.green;
  return ((c.r - from.r) / (to.r - from.r)).clamp(0.0, 1.0);
}

void main() {
  group('the safety number', () {
    Widget card(bool verified, {bool celebrate = true, bool still = false}) =>
        host(
          Scaffold(
            body: SafetyNumberCard(
              groups: _groups,
              verified: verified,
              celebrate: celebrate,
            ),
          ),
          still: still,
        );

    testWidgets('marked here, it turns green in reading order', (t) async {
      await t.pumpWidget(card(false));
      await settles(t);
      await t.pumpWidget(card(true));
      await t.pump(const Duration(milliseconds: 250));
      final first = greenness(colourOf(t, _groups.first));
      final last = greenness(colourOf(t, _groups.last));
      expect(first, greaterThan(last));
      await settles(t);
      expect(colourOf(t, _groups.last), HaloColors.green);
    });

    testWidgets('verified before, it is simply green', (t) async {
      await t.pumpWidget(card(false, celebrate: false));
      await settles(t);
      await t.pumpWidget(card(true, celebrate: false));
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
      expect(colourOf(t, _groups.first), HaloColors.green);
    });

    testWidgets('reduced motion: no cascade', (t) async {
      await t.pumpWidget(card(false, still: true));
      await t.pump();
      await t.pumpWidget(card(true, still: true));
      await t.pump();
      expect(colourOf(t, _groups.last), HaloColors.green);
    });

    testWidgets('right to left: the cascade starts on the right', (t) async {
      await t.pumpWidget(
        host(
          const Scaffold(
            body: SafetyNumberCard(groups: _groups, verified: false),
          ),
          dir: TextDirection.rtl,
        ),
      );
      await settles(t);
      expect(
        t.getCenter(find.text(_groups[0])).dx,
        greaterThan(t.getCenter(find.text(_groups[1])).dx),
      );
      await t.pumpWidget(
        host(
          const Scaffold(
            body: SafetyNumberCard(
              groups: _groups,
              verified: true,
              celebrate: true,
            ),
          ),
          dir: TextDirection.rtl,
        ),
      );
      await t.pump(const Duration(milliseconds: 250));
      expect(
        greenness(colourOf(t, _groups[0])),
        greaterThan(greenness(colourOf(t, _groups[5]))),
      );
      await settles(t);
    });
  });

  group('what we can see', () {
    setUp(() => appState.sendModeForTest = 'balanced');

    Rect bandIn(WidgetTester t) {
      final bands = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                HaloColors.amber.withValues(alpha: 0.07),
      );
      return t.getRect(bands.first);
    }

    Future<void> open(
      WidgetTester t, {
      bool still = false,
      TextDirection dir = TextDirection.ltr,
    }) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      quiet(t);
      await t.pumpWidget(host(const SeenScreen(), still: still, dir: dir));
      await t.pump(const Duration(seconds: 1));
      await settles(t);
    }

    testWidgets('the other routes keep their full colour', (t) async {
      await open(t);
      for (final e in find.text(l10n.seenHidden).evaluate()) {
        final dimmers = find.ancestor(
          of: find.byWidget(e.widget),
          matching: find.byType(Opacity),
        );
        for (final o in t.widgetList<Opacity>(dimmers)) {
          expect(o.opacity, 1);
        }
      }
    });

    testWidgets('the band sits under the route in use', (t) async {
      await open(t);
      final band = bandIn(t);
      final relay = t.getCenter(find.text(l10n.seenRelay));
      expect(band.left, lessThan(relay.dx));
      expect(band.right, greaterThan(relay.dx));
    });

    testWidgets('right to left: the band follows the column', (t) async {
      await open(t, dir: TextDirection.rtl);
      final band = bandIn(t);
      final relay = t.getCenter(find.text(l10n.seenRelay));
      expect(band.left, lessThan(relay.dx));
      expect(band.right, greaterThan(relay.dx));
    });

    testWidgets('a row opens and rests; with less movement at once', (t) async {
      await open(t);
      await t.tap(find.text(l10n.seenWhatYouSay));
      await t.pump(const Duration(milliseconds: 80));
      expect(find.byType(AnimatedSize), findsWidgets);
      await settles(t);
      expect(find.text(l10n.seenEndToEndEncrypted), findsOneWidget);
    });

    testWidgets('reduced motion: nothing grows', (t) async {
      await open(t, still: true);
      expect(find.byType(AnimatedSize), findsNothing);
      await t.tap(find.text(l10n.seenWhatYouSay));
      await t.pump();
      expect(find.text(l10n.seenEndToEndEncrypted), findsOneWidget);
    });
  });

  group('introductions', () {
    late List<ContactPreview> was;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      was = appState.contacts;
      appState.contacts = [
        ContactPreview(haloId: 'wren-velvet-march', avatarSeed: 'w'),
        ContactPreview(haloId: 'moss-tide-lamp', avatarSeed: 'm'),
        ContactPreview(haloId: 'fern-cold-oak', avatarSeed: 'f'),
      ];
    });
    tearDown(() => appState.contacts = was);

    Future<void> open(
      WidgetTester t, {
      bool still = false,
      TextDirection dir = TextDirection.ltr,
    }) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      quiet(t);
      await t.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (ctx) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    showIntroduceSheet(ctx, peerId: 'peer', peerName: 'Ada'),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          still: still,
          dir: dir,
        ),
      );
      await t.tap(find.byType(GestureDetector).first);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await settles(t);
    }

    double tickScale(WidgetTester t, String id) => t
        .widget<AnimatedScale>(
          find
              .descendant(
                of: find.bySemanticsLabel(id),
                matching: find.byType(AnimatedScale),
              )
              .last,
        )
        .scale;

    testWidgets('a pick pops its tick and rests', (t) async {
      final h = t.ensureSemantics();
      await open(t);
      expect(tickScale(t, 'moss-tide-lamp'), lessThan(1));
      await t.tap(find.text('moss-tide-lamp'));
      await t.pump();
      expect(tickScale(t, 'moss-tide-lamp'), 1);
      await t.pump(const Duration(milliseconds: 60));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await settles(t);
      h.dispose();
    });

    testWidgets('reduced motion: nothing pops', (t) async {
      final h = t.ensureSemantics();
      await open(t, still: true);
      expect(tickScale(t, 'moss-tide-lamp'), 1);
      await t.tap(find.text('moss-tide-lamp'));
      await t.pump();
      final scales = t.widgetList<AnimatedScale>(
        find.descendant(
          of: find.bySemanticsLabel('moss-tide-lamp'),
          matching: find.byType(AnimatedScale),
        ),
      );
      for (final s in scales) {
        expect(s.duration, Duration.zero);
      }
      h.dispose();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('right to left: the tick sits on the left', (t) async {
      final h = t.ensureSemantics();
      await open(t, dir: TextDirection.rtl);
      await t.tap(find.text('moss-tide-lamp'));
      await settles(t);
      final tick = t.getCenter(
        find.descendant(
          of: find.bySemanticsLabel('moss-tide-lamp'),
          matching: find.byIcon(Icons.check_rounded),
        ),
      );
      final name = t.getCenter(find.text('moss-tide-lamp'));
      expect(tick.dx, lessThan(name.dx));
      h.dispose();
    });
  });
}
