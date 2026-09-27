import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/tools_screen.dart';
import 'package:kryfo/theme.dart';

Widget host(Widget child, {double scale = 1, bool still = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(scale),
          disableAnimations: still,
        ),
        child: Scaffold(body: child),
      ),
    );

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

void main() {
  testWidgets('card and tools appear in order', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), still: true));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    final ys = [
      for (final s in [
        'What does this photo know?',
        'Clean a photo or video',
        'Make a private QR code',
        'Lock a file',
        'Open a locked file',
      ])
        t.getTopLeft(find.text(s)).dy,
    ];
    expect(ys, [...ys]..sort());
  });

  testWidgets('taps reach callbacks, rows without one are inert', (t) async {
    final got = <String>[];
    await t.pumpWidget(
      host(
        ToolsScreen(
          onPickPhoto: () => got.add('photo'),
          onPickVideo: () => got.add('video'),
          onQr: () => got.add('qr'),
        ),
        still: true,
      ),
    );
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(find.text('Pick a photo'));
    await t.tap(find.text('Video'));
    await t.tap(find.text('Make a private QR code'));
    await t.ensureVisible(find.text('Lock a file'));
    await t.tap(find.text('Lock a file'));
    expect(got, ['photo', 'video', 'qr']);
  });

  testWidgets('no text uses text2 or text3', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), still: true));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(w.style?.color, isNot(HaloColors.text2), reason: '${w.data}');
      expect(w.style?.color, isNot(HaloColors.text3), reason: '${w.data}');
    }
  });

  test('amber card ink holds 4.5:1 contrast', () {
    for (final bg in [HaloColors.amberBright, HaloColors.amberBrightDeep]) {
      final a = _lum(bg), b = _lum(HaloColors.amberInk);
      expect((a + 0.05) / (b + 0.05), greaterThan(4.5));
    }
  });

  testWidgets('largest font fits a small phone by scrolling', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), scale: 2, still: true));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion: the dot holds still', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), still: true));
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.hasRunningAnimations, false);
  });

  testWidgets('the dot breathes twice as the tab opens, then rests', (t) async {
    await t.pumpWidget(host(const ToolsScreen()));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.hasRunningAnimations, isTrue);
    await t.pump(const Duration(seconds: 5));
    expect(t.hasRunningAnimations, isFalse);
    // at rest it is lit, not caught mid-fade
    final dot = t.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(ToolsScreen),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(dot.opacity.value, 1);
  });

  double tileScale(WidgetTester t, String title) => t
      .widget<AnimatedScale>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text(title),
                matching: find.byType(GestureDetector),
              ),
              matching: find.byType(AnimatedScale),
            )
            .first,
      )
      .scale;

  Offset nudge(WidgetTester t, String title) => t
      .widget<AnimatedSlide>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(GestureDetector),
          ),
          matching: find.byType(AnimatedSlide),
        ),
      )
      .offset;

  testWidgets('a pressed row tints, dips and springs back', (t) async {
    var taps = 0;
    await t.pumpWidget(host(ToolsScreen(onQr: () => taps++)));
    await t.pump(const Duration(milliseconds: 500));
    const title = 'Make a private QR code';
    final g = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 120));
    expect(tileScale(t, title), lessThan(1));
    expect(nudge(t, title).dx, greaterThan(0));
    await g.up();
    await t.pump();
    expect(taps, 1);
    expect(tileScale(t, title), 1);
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(seconds: 5));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('right to left: the chevron leans the other way', (t) async {
    await t.pumpWidget(
      host(
        Directionality(
          textDirection: TextDirection.rtl,
          child: ToolsScreen(onQr: () {}),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    const title = 'Make a private QR code';
    final g = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 120));
    expect(nudge(t, title).dx, lessThan(0));
    await g.up();
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('reduced motion: a press tints but nothing moves', (t) async {
    await t.pumpWidget(host(ToolsScreen(onQr: () {}), still: true));
    await t.pump(const Duration(milliseconds: 500));
    const title = 'Make a private QR code';
    final g = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 120));
    expect(tileScale(t, title), 1);
    expect(nudge(t, title), Offset.zero);
    await g.up();
    await t.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the card buttons press like the rest of the app', (t) async {
    var picks = 0;
    await t.pumpWidget(host(ToolsScreen(onPickPhoto: () => picks++)));
    await t.pump(const Duration(milliseconds: 500));
    final g = await t.startGesture(t.getCenter(find.text('Pick a photo')));
    // the scroll view has the pointer too: the press shows once it is a tap
    await t.pump(const Duration(milliseconds: 150));
    final pressed = t.widget<AnimatedScale>(
      find
          .ancestor(
            of: find.text('Pick a photo'),
            matching: find.byType(AnimatedScale),
          )
          .first,
    );
    expect(pressed.scale, lessThan(1));
    await g.up();
    expect(picks, 1);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('a screen reader can press every row', (t) async {
    final h = t.ensureSemantics();
    var taps = 0;
    await t.pumpWidget(
      host(ToolsScreen(onClean: () => taps++, onPickVideo: () => taps++)),
    );
    // the rows have faded in once their stagger has played
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    for (final label in [
      RegExp('^Clean a photo or video'),
      RegExp(r'^Video$'),
    ]) {
      final node = t.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      t.semantics.tap(find.semantics.byLabel(label));
    }
    expect(taps, 2);
    await t.pump(const Duration(seconds: 6));
    h.dispose();
  });
}
