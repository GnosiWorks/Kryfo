// SPDX-License-Identifier: GPL-3.0-or-later
// the scanner's frame: its corners close in as it opens and come to rest,
// each corner is drawn for the corner it sits in whichever way the language
// reads, and with less movement nothing sweeps.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/scan_screen.dart';

final _shot = GlobalKey();

Widget framed(
  Animation<double> sweep, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
  bool success = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(360, 640), disableAnimations: still),
    child: Directionality(
      textDirection: dir,
      child: Center(
        child: RepaintBoundary(
          key: _shot,
          child: ScanFrame(size: 240, success: success, scanAnim: sweep),
        ),
      ),
    ),
  ),
);

Future<List<int>> pixels(WidgetTester t) async {
  final b = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late List<int> out;
  await t.runAsync(() async {
    final img = await b.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    out = data!.buffer.asUint8List().toList();
    img.dispose();
  });
  return out;
}

double scale(WidgetTester t) => t
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(ScanFrame),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getMaxScaleOnAxis();

void main() {
  testWidgets('the corners close in as it opens, then rest', (t) async {
    await t.pumpWidget(framed(const AlwaysStoppedAnimation(0)));
    await t.pump(const Duration(milliseconds: 40));
    expect(scale(t), greaterThan(1.01));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.hasRunningAnimations, isFalse);
    expect(scale(t), 1);
  });

  testWidgets('reduced motion: no close in and no sweeping line', (t) async {
    await t.pumpWidget(framed(const AlwaysStoppedAnimation(0.5), still: true));
    expect(scale(t), 1);
    expect(t.hasRunningAnimations, isFalse);
    // the line is the one gradient in the frame
    final lines = t
        .widgetList<Container>(find.byType(Container))
        .where((c) => (c.decoration as BoxDecoration?)?.gradient != null);
    expect(lines, isEmpty);
  });

  testWidgets('right to left draws the very same frame', (t) async {
    await t.pumpWidget(framed(const AlwaysStoppedAnimation(0), still: true));
    await t.pump();
    final ltr = await pixels(t);
    await t.pumpWidget(
      framed(
        const AlwaysStoppedAnimation(0),
        still: true,
        dir: TextDirection.rtl,
      ),
    );
    await t.pump();
    expect(await pixels(t), ltr);
  });
}
