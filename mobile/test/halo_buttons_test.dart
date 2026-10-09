// SPDX-License-Identifier: GPL-3.0-or-later
// the shared buttons: a short label as it always was, a long one in a long
// language on two lines, never cut with an ellipsis
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/halo_buttons.dart';

Widget _in(Widget b) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 256, child: b)),
  ),
);

void main() {
  // two lines in the test font: 16 squares a line in 232
  const long = 'Make a six digit code';
  for (final (name, make) in <(String, Widget Function(String))>[
    ('primary', (l) => HaloPrimaryButton(label: l, onTap: () {})),
    ('ghost', (l) => HaloGhostButton(label: l, onTap: () {})),
  ]) {
    testWidgets('$name: short stays one line at 46, long wraps whole', (
      t,
    ) async {
      await t.pumpWidget(_in(make('Add')));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.getSize(find.byType(make('Add').runtimeType)).height, 46);
      await t.pumpWidget(_in(make(long)));
      await t.pump(const Duration(milliseconds: 400));
      final p = t.renderObject<RenderParagraph>(find.text(long));
      expect(p.didExceedMaxLines, isFalse);
      expect(
        t.getSize(find.byType(make(long).runtimeType)).height,
        greaterThan(46),
      );
    });
  }
}
