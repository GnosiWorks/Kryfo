// SPDX-License-Identifier: GPL-3.0-or-later
// every mood keeps the words at 4.5:1, in both themes and with every
// accent: on the chat's ground and on the incoming bubble
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart';
import 'package:kryfo/theme.dart';

import 'a11y_fakes.dart';

void main() {
  tearDown(() {
    HaloColors.setLight(false);
    HaloColors.setAccent(HaloAccent.yellow);
  });

  for (final light in [true, false]) {
    for (final a in Atmo.values.where(atmoIsMood)) {
      test('${a.name} reads in ${light ? 'light' : 'dark'}', () {
        HaloColors.setLight(light);
        final m = moodOf(a)!;
        for (final accent in HaloAccent.values) {
          HaloColors.setAccent(accent);
          for (final under in [HaloColors.surface, HaloColors.ink]) {
            final ground = Color.alphaBlend(
              HaloColors.ink.withValues(alpha: m.dim),
              Color.alphaBlend(m.base.withValues(alpha: m.wash), under),
            );
            final bubble = Color.lerp(HaloColors.bubbleIn, m.base, m.bubble)!;
            for (final g in [ground, bubble]) {
              for (final ink in [
                HaloColors.text,
                HaloColors.text2,
                HaloColors.text3,
                HaloColors.amberText,
              ]) {
                expect(
                  ratio(ink, g),
                  greaterThanOrEqualTo(4.5),
                  reason: '${accent.name}: $ink on $g',
                );
              }
            }
          }
        }
      });
    }
  }
}
