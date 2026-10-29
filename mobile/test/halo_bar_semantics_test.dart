// SPDX-License-Identifier: GPL-3.0-or-later
// a long job's bar to a screen reader: named, a live region, in steps of
// 10%. a bar with no name, like a poll's, adds nothing to hear
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/numbers.dart';
import 'package:kryfo/widgets/halo_bar.dart';

import 'a11y_fakes.dart';

void main() {
  test('the spoken share drops to the last 10%', () {
    expect(barStep(0.43), 0.4);
    expect(barStep(0.47), 0.4);
    expect(barStep(0.51), 0.5);
    expect(barStep(1.2), 1.0);
    expect(barStep(-1), 0.0);
  });

  testWidgets('a named bar is a live region with its share', (t) async {
    final h = t.ensureSemantics();
    Future<SemanticsNode> at(double? v) async {
      await t.pumpWidget(
        bare(
          Scaffold(
            body: HaloBar(value: v, label: 'Backup progress'),
          ),
          still: true,
        ),
      );
      return t.getSemantics(find.byType(HaloBar));
    }

    var n = await at(0.43);
    expect(n.label, 'Backup progress');
    expect(n.value, percent(0.4));
    expect(n.flagsCollection.isLiveRegion, isTrue);
    n = await at(0.47);
    expect(n.value, percent(0.4));
    n = await at(0.51);
    expect(n.value, percent(0.5));
    n = await at(null);
    expect(n.label, 'Backup progress');
    expect(n.value, isEmpty);
    h.dispose();
  });

  testWidgets('a bar with no name adds no node', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(
      bare(const Scaffold(body: HaloBar(value: 0.5)), still: true),
    );
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    h.dispose();
  });
}
