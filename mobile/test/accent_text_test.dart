// SPDX-License-Identifier: GPL-3.0-or-later
// words in a status colour take its text tone: 4.5:1 on every ground in
// both themes. the accents themselves stay for icons, rings and fills
import 'dart:io';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/notice_banner.dart';

import 'a11y_fakes.dart';
import 'pin_flow_fakes.dart' show appOnly, makeLock;

List<Color> _grounds() => [
  HaloColors.surface,
  HaloColors.surface2,
  HaloColors.surface3,
  HaloColors.bubbleIn,
  HaloColors.ink,
];

void main() {
  tearDown(() => HaloColors.setLight(false));

  test('the text tones reach 4.5:1 on every ground and on their own tint', () {
    for (final light in [true, false]) {
      HaloColors.setLight(light);
      for (final (name, accent, words) in [
        ('rose', HaloColors.rose, HaloColors.roseText),
        ('green', HaloColors.green, HaloColors.greenText),
        ('violet', HaloColors.violet, HaloColors.violetText),
        ('warn', HaloColors.warn, HaloColors.warnText),
      ]) {
        for (final g in [
          ..._grounds(),
          Color.alphaBlend(accent.withValues(alpha: 0.07), HaloColors.surface),
        ]) {
          expect(
            ratio(words, g),
            greaterThanOrEqualTo(4.5),
            reason: '${light ? 'light' : 'dark'} $name on $g',
          );
        }
        expect(HaloColors.wordsIn(accent), words, reason: name);
      }
      // relay's sky is its own text tone, on the grounds it is written on
      for (final g in [
        HaloColors.surface,
        HaloColors.surface2,
        HaloColors.ink,
      ]) {
        expect(ratio(HaloColors.sky, g), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('no words in lib are painted in a plain status accent', () {
    final accent = RegExp(r'HaloColors\.(rose|green|violet)\b(?!Text|Soft)');
    final opener = RegExp(r'HaloType\.(sans|mono|serif)\(|TextStyle\(');
    final other = RegExp(r'Icon\(|BoxDecoration\(|Border|Container\(|Paint');
    // an icon's tint in a list, and a text cursor: not words
    const notWords = {
      'lib/screens/pins_screen.dart': 'Icons.local_fire_department_outlined',
      'lib/screens/room_create_sheet.dart': 'cursorColor: HaloColors.violet',
    };
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('theme.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!accent.hasMatch(lines[i]) || lines[i].contains('withValues')) {
          continue;
        }
        final ctx = lines.sublist(i < 6 ? 0 : i - 6, i + 1).join('\n');
        final a = ctx.lastIndexOf(opener);
        final b = ctx.lastIndexOf(other);
        final skip = notWords[f.path];
        if (skip != null && ctx.contains(skip)) continue;
        if (a >= 0 && a > b) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  });

  for (final light in [true, false]) {
    final theme = light ? 'light' : 'dark';
    for (final (name, tone) in [
      ('rose', () => HaloColors.rose),
      ('violet', () => HaloColors.violet),
      ('green', () => HaloColors.green),
    ]) {
      testWidgets('a $name notice reads at 4.5:1 in $theme', (t) async {
        await t.pumpWidget(
          bare(
            Builder(
              builder: (_) => Scaffold(
                backgroundColor: HaloColors.surface,
                body: NoticeBanner(
                  glyph: NoticeGlyph.shield,
                  text: 'Careful',
                  color: tone(),
                ),
              ),
            ),
            light: light,
            still: true,
          ),
        );
        await t.pumpAndSettle();
        final ground = Color.alphaBlend(
          tone().withValues(alpha: 0.07),
          HaloColors.surface,
        );
        final c = inks(t, find.byType(NoticeBanner)).single;
        expect(ratio(c, ground), greaterThanOrEqualTo(4.5), reason: '$c');
      });
    }

    testWidgets('a wrong pin reads at 4.5:1 on the lock screen in $theme', (
      t,
    ) async {
      final lock = await makeLock(appOnly);
      lock.state.lock();
      await t.pumpWidget(
        bare(LockScreen(lock: lock.state), light: light, still: true),
      );
      await t.pumpAndSettle();
      for (final d in '0000'.split('')) {
        await t.tap(find.text(d).last);
        await t.pump();
      }
      await t.tap(find.bySemanticsLabel(l10n.commonDone));
      // the check runs, then the line shows for the shake
      for (
        var i = 0;
        i < 20 && find.text(l10n.lockNotIt).evaluate().isEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(find.text(l10n.lockNotIt), findsOneWidget);
      final c = inks(t, find.text(l10n.lockNotIt)).single;
      expect(ratio(c, HaloColors.ink), greaterThanOrEqualTo(4.5), reason: '$c');
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    });
  }
}
