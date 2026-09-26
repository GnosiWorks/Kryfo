import 'package:flutter/material.dart';
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

  testWidgets('taps reach callbacks, rows without one are inert', (
    t,
  ) async {
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

  testWidgets('no text uses text2 or text3', (
    t,
  ) async {
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
}
