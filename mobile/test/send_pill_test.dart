// SPDX-License-Identifier: GPL-3.0-or-later
// the pill under a message on its way: its words read in both themes, and
// it rests when the phone asks for no movement
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart';

import 'a11y_fakes.dart';

void main() {
  tearDown(() => HaloColors.setLight(false));

  for (final light in [true, false]) {
    final theme = light ? 'light' : 'dark';
    for (final (mode, delivered) in [
      (PrivacyMode.normal, false),
      (PrivacyMode.private, false),
      (PrivacyMode.fast, true),
      (PrivacyMode.private, true),
    ]) {
      testWidgets('the $mode pill${delivered ? ', delivered,' : ''} reads '
          'at 4.5:1 in $theme', (t) async {
        await t.pumpWidget(
          bare(
            const Scaffold(
              body: Center(child: SendPill(mode: PrivacyMode.fast)),
            ),
            light: light,
            still: true,
          ),
        );
        await t.pumpWidget(
          bare(
            Scaffold(
              body: Center(
                child: SendPill(mode: mode, delivered: delivered),
              ),
            ),
            light: light,
            still: true,
          ),
        );
        final box = t.widget<Container>(
          find
              .descendant(
                of: find.byType(SendPill),
                matching: find.byType(Container),
              )
              .first,
        );
        final tint = (box.decoration! as BoxDecoration).color!;
        for (final g in [HaloColors.surface, HaloColors.ink]) {
          final ground = Color.alphaBlend(tint, g);
          final words = inks(t, find.byType(SendPill));
          expect(words, isNotEmpty);
          for (final c in words) {
            expect(
              ratio(c, ground),
              greaterThanOrEqualTo(4.5),
              reason: '$c on $ground',
            );
          }
        }
      });
    }
  }

  for (final mode in [PrivacyMode.normal, PrivacyMode.private]) {
    testWidgets('the $mode pill stands still with reduced motion', (t) async {
      await t.pumpWidget(
        bare(
          Scaffold(
            body: Center(child: SendPill(mode: mode)),
          ),
          still: true,
        ),
      );
      // a pill that loops never settles
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the $mode pill turns with motion on', (t) async {
      await t.pumpWidget(
        bare(
          Scaffold(
            body: Center(child: SendPill(mode: mode)),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isTrue);
      await t.pumpWidget(const SizedBox());
    });
  }
}
