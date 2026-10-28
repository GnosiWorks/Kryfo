// SPDX-License-Identifier: GPL-3.0-or-later
// the home pill's words stay readable in every language at every text
// size: drawn with the app's own fonts at 360 dp, at normal text and the
// largest, each state's whole phrase is on screen in two lines at most and
// never smaller than the header's smallest text
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/link_view.dart';
import 'package:kryfo/main.dart' show AppStateRoute, TorHalo, appState;
import 'package:kryfo/pill_fit.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  const families = {
    'JetBrains Mono': ['JetBrainsMono.ttf'],
    'Noto Sans Cyrillic': ['NotoSans-Cyrillic.ttf'],
    'Noto Sans Vietnamese': ['NotoSans-Vietnamese.ttf'],
    'Noto Sans Arabic': ['NotoSansArabic-Kryfo.ttf'],
    'Instrument Sans': ['InstrumentSans.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(
        File(
          'assets/fonts/$f',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }
}

const _width = 360.0;
// the room the header leaves the words (gates.dart)
const _room = _width * 0.24;

void main() {
  setUpAll(_loadFonts);
  tearDown(() => setL10nLocale(const Locale('en')));

  for (final locale in AppLocalizations.supportedLocales) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every state fits in $locale at text scale $scale', (
        t,
      ) async {
        setL10nLocale(locale);
        final rtl = const {'ar', 'fa'}.contains(locale.languageCode);
        for (final kind in LinkKind.values) {
          final v = LinkView(
            kind: kind,
            status: TorStatus.starting,
            // the widest percent there is
            pct: 100,
          );
          final fit = fitPill(
            text: v.text,
            short: v.shortText,
            style: HaloType.mono(size: kPillPx),
            room: _room,
            userScale: scale,
            direction: rtl ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(fit.fits, isTrue, reason: '$locale $kind "${v.text}"');
          expect(
            fit.px,
            greaterThanOrEqualTo(kPillMinPx - 1e-6),
            reason: '$locale $kind "${fit.text}"',
          );
          // large text never draws the words smaller than normal text does
          if (scale > 1) {
            final normal = fitPill(
              text: v.text,
              short: v.shortText,
              style: HaloType.mono(size: kPillPx),
              room: _room,
              userScale: 1,
              direction: rtl ? TextDirection.rtl : TextDirection.ltr,
            );
            expect(
              fit.px,
              greaterThanOrEqualTo(normal.px - 1e-6),
              reason: '$locale $kind',
            );
          }
        }
      });
    }
  }

  // the pill on screen draws what the fit says: the whole phrase, in two
  // lines at most, at the fitted size
  for (final code in ['pt', 'ru', 'es', 'uk', 'id', 'ar']) {
    testWidgets('the pill draws its whole phrase in $code at the largest '
        'text', (t) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      setL10nLocale(Locale(code));
      t.view.physicalSize = const Size(_width * 2, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      addTearDown(() {
        appState.setTorStatusForTest(TorStatus.off);
        appState.setRouteOKForTest(true);
        appState.usableAtForTest = null;
      });
      appState.sendModeForTest = 'private';
      appState.noteOnline(true);
      appState.usableAtForTest = null;
      appState.setTorStatusForTest(TorStatus.reachable);
      appState.setRouteOKForTest(false);
      await t.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const Material(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: TorHalo(label: true),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      final p = t.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(TorHalo),
          matching: find.byType(RichText),
        ),
      );
      final v = appState.linkView;
      expect(v.kind, LinkKind.relayWait);
      expect(p.text.toPlainText(), isIn([v.text, ?v.shortText]));
      expect(p.didExceedMaxLines, isFalse);
      expect(p.size.width, lessThanOrEqualTo(_room + 0.5));
      expect(
        p.textScaler.scale(kPillPx),
        greaterThanOrEqualTo(kPillMinPx - 1e-6),
      );
      await t.pumpWidget(const SizedBox());
    });
  }
}
