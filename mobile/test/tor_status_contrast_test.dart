// SPDX-License-Identifier: GPL-3.0-or-later
// tor's status words, in the tor sheet and the home pill, read in both
// themes: 4.5:1 on the grounds they sit on, never a colour fixed for dark
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

// every text colour drawn under [root], spans included
List<Color> _inks(WidgetTester t) {
  final out = <Color>[];
  void span(InlineSpan s) {
    final c = s.style?.color;
    if (c != null) out.add(c);
    if (s is TextSpan) s.children?.forEach(span);
  }

  for (final w in t.widgetList<RichText>(find.byType(RichText))) {
    span(w.text);
  }
  return out;
}

void main() {
  tearDown(() => HaloColors.setLight(false));

  for (final light in [true, false]) {
    for (final status in TorStatus.values) {
      testWidgets(
        'the tor sheet reads in ${light ? 'light' : 'dark'}: $status',
        (t) async {
          HaloColors.setLight(light);
          await t.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Material(
                color: HaloColors.surface2,
                child: SingleChildScrollView(
                  child: TorWarmupGraph(status: status, bootstrapPct: 40),
                ),
              ),
            ),
          );
          // standby first, then a phase further on
          for (final step in [Duration.zero, const Duration(seconds: 3)]) {
            await t.pump(step);
            final inks = _inks(t);
            expect(inks, isNotEmpty);
            for (final c in inks) {
              expect(
                _ratio(c, HaloColors.surface2),
                greaterThanOrEqualTo(4.5),
                reason: '$c on ${HaloColors.surface2}',
              );
            }
          }
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  test('the home pill words reach 4.5:1 on the surfaces, both themes', () {
    for (final light in [true, false]) {
      HaloColors.setLight(light);
      for (final ink in [
        HaloColors.greenText,
        HaloColors.violetText,
        HaloColors.warnText,
        HaloColors.sky,
      ]) {
        for (final ground in [HaloColors.surface, HaloColors.surface2]) {
          expect(
            _ratio(ink, ground),
            greaterThanOrEqualTo(4.5),
            reason: '${light ? 'light' : 'dark'}: $ink on $ground',
          );
        }
      }
    }
  });

  test('no status colour fixed for dark in the pill or the tor graph', () {
    final main = File('lib/main.dart').readAsStringSync();
    final motion = File('lib/widgets/motion.dart').readAsStringSync();
    for (final hex in ['0xFF34D399', '0xFFB79CFF']) {
      expect(main.contains('Color($hex)'), isFalse, reason: 'main.dart $hex');
    }
    final graph = motion.substring(
      motion.indexOf('class _TorWarmupGraphState'),
      motion.indexOf('class _ZigZagWarmupPainter'),
    );
    for (final k in ['kText,', 'kText2,', 'kText3,', 'kAmber)', 'kGreen ']) {
      expect(graph.contains(k), isFalse, reason: k);
    }
  });
}
