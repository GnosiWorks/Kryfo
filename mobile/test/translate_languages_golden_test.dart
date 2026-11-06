// SPDX-License-Identifier: GPL-3.0-or-later
// settings > translation > languages pixel for pixel, in the light theme,
// the dark one and right to left: one language on the phone, one coming,
// one waiting for wi-fi, one into english only and the rest to download
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/translate_languages_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/engine_bridge.dart';
import 'package:kryfo/translate/settings.dart';

import 'narrow_settings.dart' show loadAppFonts;
import 'translate_fakes.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final (name, light, locale) in [
    ('light', true, const Locale('en')),
    ('dark', false, const Locale('en')),
    ('rtl', false, const Locale('ar')),
  ]) {
    testWidgets('languages, $name', (t) async {
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      HaloColors.setLight(light);
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      addTearDown(() => HaloColors.setLight(false));
      final f = fakeHub(
        app: 'ru',
        catalog: dirCatalog,
        have: {'zh'},
        wifi: false,
        settings: const TranslateSettings(wifiOnly: true, mine: ['zh']),
      );
      await f.hub.ready();
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
          home: TranslateLanguagesScreen(hub: f.hub),
        ),
      );
      await t.pumpAndSettle();
      // russian waits for wi-fi; german comes in over "download anyway"
      await f.hub.downloadLang('ru');
      await f.hub.downloadLang('de', anyNetwork: true);
      f.backend.statuses['de-en'] = const FetchStatus(
        'running',
        done: 30 << 20,
        total: 48 << 20,
      );
      await t.pump(const Duration(milliseconds: 150));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(TranslateLanguagesScreen),
        matchesGoldenFile('goldens/translate_languages_$name.png'),
      );
      f.backend.finish('de-en');
      f.backend.finish('en-de');
      await t.pump(const Duration(milliseconds: 150));
      f.hub.downloads.dispose();
    });
  }
}
