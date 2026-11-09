// SPDX-License-Identifier: GPL-3.0-or-later
// the sending sheet pixel for pixel, two files chosen and one not, in the
// dark theme, the light one and right to left
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/send_sheet.dart';

import 'narrow_settings.dart' show loadAppFonts;

void main() {
  setUpAll(loadAppFonts);
  setUp(() => sendSheetGuard = LockGuard(isLocked: () => false));
  tearDown(() => sendSheetGuard = lockGuard);

  for (final (v, light, locale) in [
    ('dark', false, const Locale('en')),
    ('light', true, const Locale('en')),
    ('rtl', false, const Locale('ar')),
  ]) {
    testWidgets('sending sheet, $v', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      HaloColors.setLight(light);
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      addTearDown(() => HaloColors.setLight(false));
      final day = DateTime.now();
      SendPick f(String n, int kb, int daysAgo) => SendPick(
        path: '/x/$n',
        name: n,
        size: kb * 1024,
        from: SendTab.files,
        when: day.subtract(Duration(days: daysAgo)),
      );
      final files = [
        f('Signed-lease.pdf', 1843, 0),
        f('Street-recording.mp3', 6348, 1),
        f('Notes-from-meeting.docx', 220, 2),
        f('Archive-2025.zip', 31744, 40),
      ];
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildHaloTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (c) => Scaffold(
              backgroundColor: HaloColors.ink,
              body: Center(
                child: TextButton(
                  onPressed: () => showSendSheet(
                    c,
                    to: 'Lena',
                    pickGallery: () async => const [],
                    pickFiles: () async => files,
                    recent: () async => const [],
                    start: SendTab.files,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.sendSheetBrowseFiles));
      await t.pumpAndSettle();
      // two of four: the pdf and the recording
      await t.tap(find.text('Notes-from-meeting'));
      await t.tap(find.text('Archive-2025'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/files_send_sheet_$v.png'),
      );
    });
  }
}
