// SPDX-License-Identifier: GPL-3.0-or-later
// the new parts pixel for pixel: the head while messages are picked, two
// picked rows and one not, a spoiler photo still blurred, and the timer
// beside the flame. dark, light, right to left and twice the text size
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/burn_sheet.dart';
import 'package:kryfo/widgets/select_parts.dart';
import 'package:kryfo/widgets/spoiler_cover.dart';

import 'narrow_settings.dart' show loadAppFonts;

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    forgetSpoilersForTest();
    openPictures();
  });

  for (final (name, light, locale, scale) in [
    ('dark', false, const Locale('en'), 1.0),
    ('light', true, const Locale('en'), 1.0),
    ('rtl', false, const Locale('ar'), 1.0),
    ('large', false, const Locale('en'), 2.0),
  ]) {
    testWidgets('picked rows, a spoiler and the flame, $name', (t) async {
      t.view.physicalSize = const Size(390, 760);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      HaloColors.setLight(light);
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      addTearDown(() => HaloColors.setLight(false));
      Widget bubble(String words, bool out) => Align(
        alignment: out
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: out ? HaloColors.amber : HaloColors.bubbleIn,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            words,
            style: HaloType.message(onAmber: out),
          ),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildHaloTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: HaloColors.surface,
            body: Column(
              children: [
                SelectBar(
                  count: 2,
                  onClose: () {},
                  onCopy: () {},
                  onForward: () {},
                  onDelete: () {},
                ),
                SelectRow(
                  on: true,
                  onTap: () {},
                  child: bubble('Saturday at the north gate', false),
                ),
                SelectRow(
                  on: false,
                  onTap: () {},
                  child: bubble('Bring the maps', true),
                ),
                SelectRow(
                  on: true,
                  onTap: () {},
                  child: bubble('See you there', true),
                ),
                const SizedBox(height: 16),
                SpoilerCover(
                  uid: 'sp',
                  on: true,
                  radius: BorderRadius.circular(14),
                  child: Container(
                    width: 240,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3E5A4C), Color(0xFFF59E0B)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HaloColors.amber,
                      ),
                    ),
                    const FlameTime(on: true, secs: 3600),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/pick_spoiler_$name.png'),
      );
    });
  }
}
