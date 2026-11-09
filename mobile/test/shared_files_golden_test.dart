// SPDX-License-Identifier: GPL-3.0-or-later
// the shared page's files tab pixel for pixel, as the mockup has it: two
// months, a kind's tile each, one file still to come. dark, light, right
// to left and the largest text
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/transfers.dart';
import 'package:kryfo/widgets/shared_media.dart';

import 'narrow_settings.dart' show loadAppFonts;

void main() {
  setUpAll(loadAppFonts);
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('shared_golden'));
  tearDown(() {
    fileWaits.value = const {};
    tmp.deleteSync(recursive: true);
  });

  // a file of [kb] that takes no room on disk
  String sized(String name, int kb) {
    final f = File('${tmp.path}/$name');
    f.openSync(mode: FileMode.write)
      ..truncateSync(kb * 1024)
      ..closeSync();
    return f.path;
  }

  for (final (v, light, locale, scale) in [
    ('dark', false, const Locale('en'), 1.0),
    ('light', true, const Locale('en'), 1.0),
    ('rtl', false, const Locale('ar'), 1.0),
    ('large', false, const Locale('en'), 2.0),
  ]) {
    testWidgets('shared files, $v', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      HaloColors.setLight(light);
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      addTearDown(() => HaloColors.setLight(false));
      final nov = DateTime(2025, 11, 9, 14, 2);
      final oct = DateTime(2025, 10, 19, 9, 30);
      setFileWait(
        'w1',
        const FileWait(
          size: 225280,
          state: WaitState.asks,
          rule: AutoGet.never,
        ),
      );
      SharedItem f(String name, int kb, DateTime when) =>
          SharedItem(path: sized(name, kb), name: name, when: when);
      final lists = SharedLists(
        files: [
          f('Lease-draft.pdf', 2458, nov),
          f('rent.py', 2, nov),
          f('Rain on the balcony.m4a', 3174, nov),
          SharedItem(name: 'Notes-from-meeting.docx', when: nov, uid: 'w1'),
          f('Hike-costs.xlsx', 48, oct),
          f('Moving-day.mp4', 24576, oct.subtract(const Duration(days: 7))),
          f('photos-march.zip', 38912, oct.subtract(const Duration(days: 16))),
        ],
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
          home: SharedScreen(
            chatId: 'p',
            title: 'Lena',
            start: SharedTab.files,
            load: () async => lists,
          ),
        ),
      );
      // the sizes are read from the files as each row is built
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shared_files_$v.png'),
      );
    });
  }
}
