// SPDX-License-Identifier: GPL-3.0-or-later
// small moving parts that have to come to rest: the map pin's rings, the
// tick after a copy, a code assembling, the boot splash with less movement.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/tools/geo.dart';
import 'package:kryfo/widgets/breathing_ring.dart';
import 'package:kryfo/widgets/copied_mark.dart';
import 'package:kryfo/widgets/offline_map.dart';
import 'package:kryfo/widgets/qr_wipe.dart';

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
  GlobalKey? shot,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(360, 640), disableAnimations: still),
    child: Directionality(
      textDirection: dir,
      child: Scaffold(
        body: Center(
          child: RepaintBoundary(key: shot, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  group('the map pin', () {
    Future<AnimationController> map(
      WidgetTester t, {
      bool still = false,
    }) async {
      final reveal = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 1600),
      );
      addTearDown(reveal.dispose);
      await t.pumpWidget(
        host(
          SizedBox(
            width: 300,
            height: 200,
            child: OfflineMap(
              world: const GeoWorld([]),
              places: const GeoPlaces([]),
              lat: 43.47,
              lon: 11.89,
              reveal: reveal,
              label: 'map',
            ),
          ),
          still: still,
        ),
      );
      return reveal;
    }

    testWidgets('rings three times once it lands, then rests', (t) async {
      final reveal = await map(t);
      expect(t.hasRunningAnimations, isFalse, reason: 'no ring before');
      reveal.forward();
      await t.pump();
      await t.pump(const Duration(milliseconds: 1700));
      expect(reveal.isCompleted, isTrue);
      await t.pump(const Duration(milliseconds: 100));
      expect(t.hasRunningAnimations, isTrue, reason: 'the pin rings');
      await t.pump(const Duration(seconds: 7));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: it never rings', (t) async {
      final reveal = await map(t, still: true);
      reveal.value = 1;
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('the copied mark', () {
    Widget mark(int n, {bool still = false}) =>
        host(CopiedMark(copies: n), still: still);

    testWidgets('turns into a tick for a moment, then back', (t) async {
      await t.pumpWidget(mark(0));
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await t.pumpWidget(mark(1));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_outlined), findsNothing);
      await t.pump(const Duration(milliseconds: 1300));
      await t.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('a second copy holds the tick a while longer', (t) async {
      await t.pumpWidget(mark(0));
      await t.pumpWidget(mark(1));
      await t.pump(const Duration(milliseconds: 1000));
      await t.pumpWidget(mark(2));
      await t.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('reduced motion: the tick is there, still', (t) async {
      await t.pumpWidget(mark(0, still: true));
      await t.pumpWidget(mark(1, still: true));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      final scale = t.widget<Transform>(
        find.ancestor(
          of: find.byIcon(Icons.check_rounded),
          matching: find.byType(Transform),
        ),
      );
      expect(scale.transform.getMaxScaleOnAxis(), 1);
      await t.pump(const Duration(milliseconds: 1400));
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    });

    testWidgets('leaving mid-tick leaves no timer behind', (t) async {
      await t.pumpWidget(mark(0));
      await t.pumpWidget(mark(1));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpWidget(const SizedBox());
    });
  });

  group('a code assembling', () {
    final shot = GlobalKey();
    const white = ColoredBox(
      color: Color(0xFFFFFFFF),
      child: SizedBox(width: 100, height: 100),
    );

    // the alpha of the drawn box at a corner
    Future<int> alphaAt(WidgetTester t, Offset at) async {
      final b =
          shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late int a;
      await t.runAsync(() async {
        final img = await b.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final i = (at.dy.toInt() * img.width + at.dx.toInt()) * 4;
        a = data!.getUint8(i + 3);
        img.dispose();
      });
      return a;
    }

    testWidgets('wipes from the start corner and settles plain', (t) async {
      await t.pumpWidget(host(const QrWipe(child: white), shot: shot));
      await t.pump(const Duration(milliseconds: 220));
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(await alphaAt(t, const Offset(2, 2)), greaterThan(200));
      expect(await alphaAt(t, const Offset(97, 97)), lessThan(50));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.hasRunningAnimations, isFalse);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('right to left: it starts at the right', (t) async {
      await t.pumpWidget(
        host(
          const QrWipe(child: white),
          shot: shot,
          dir: TextDirection.rtl,
        ),
      );
      await t.pump(const Duration(milliseconds: 220));
      expect(await alphaAt(t, const Offset(97, 2)), greaterThan(200));
      expect(await alphaAt(t, const Offset(2, 97)), lessThan(50));
      await t.pump(const Duration(milliseconds: 200));
    });

    testWidgets('reduced motion: the code is simply there', (t) async {
      await t.pumpWidget(
        host(const QrWipe(child: white), shot: shot, still: true),
      );
      expect(find.byType(ShaderMask), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('hidden until its code arrives', (t) async {
      await t.pumpWidget(host(const QrWipe(shown: false, child: white)));
      await t.pump(const Duration(milliseconds: 600));
      expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      await t.pumpWidget(host(const QrWipe(child: white)));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShaderMask), findsOneWidget);
      await t.pump(const Duration(milliseconds: 200));
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('the empty page ring', () {
    const ring = BreathingRing(child: SizedBox(width: 20, height: 20));

    // the ring's wash, as its alpha
    double wash(WidgetTester t) {
      final c = t.widget<Container>(
        find
            .descendant(
              of: find.byType(BreathingRing),
              matching: find.byType(Container),
            )
            .first,
      );
      return (c.decoration as BoxDecoration).color!.a;
    }

    testWidgets('breathes three times, then rests', (t) async {
      await t.pumpWidget(host(ring));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.hasRunningAnimations, isTrue);
      expect(wash(t), greaterThan(0));
      await t.pump(const Duration(seconds: 8));
      expect(t.hasRunningAnimations, isFalse);
      expect(wash(t), 0);
    });

    testWidgets('reduced motion: it holds still', (t) async {
      await t.pumpWidget(host(ring, still: true));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
    });
  });
}
