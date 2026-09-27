// SPDX-License-Identifier: GPL-3.0-or-later
// the wallpaper sheet on a 720 px phone, drawn with the app's own fonts:
// every atmosphere name and heading fits in every language, at the normal
// font and at the biggest the app allows. a name may take two lines, but
// no word breaks and nothing is cut short.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/wallpaper_sheet.dart';
import 'package:kryfo/theme.dart';

// the app clamps the phone's font size to this
const _biggest = 1.6;

Future<void> _loadFonts() async {
  const families = {
    'Fraunces': ['Fraunces.ttf', 'Fraunces-Italic.ttf'],
    'Instrument Sans': ['InstrumentSans.ttf', 'InstrumentSans-Italic.ttf'],
    'JetBrains Mono': ['JetBrainsMono.ttf', 'JetBrainsMono-Italic.ttf'],
    'Noto Serif Cyrillic': [
      'NotoSerif-Cyrillic.ttf',
      'NotoSerif-Cyrillic-Italic.ttf',
    ],
    'Noto Sans Cyrillic': ['NotoSans-Cyrillic.ttf'],
    'Noto Sans Vietnamese': ['NotoSans-Vietnamese.ttf'],
    'Noto Naskh Arabic': ['NotoNaskhArabic-Kryfo.ttf'],
    'Noto Sans Arabic': ['NotoSansArabic-Kryfo.ttf'],
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

Future<void> _open(WidgetTester t, Locale locale, double scale) async {
  t.view.physicalSize = const Size(720, 1600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showWallpaperSheet(ctx, Atmo.none, allowPhoto: true),
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.byType(GestureDetector).first);
  await t.pumpAndSettle();
}

// what did not fit: a name or heading cut short, clipped, broken inside a
// word or off the side of the screen
List<String> _misfits(WidgetTester t) {
  final bad = <String>[];
  final words = {
    for (final a in Atmo.values) atmoLabel(a),
    l10n.wallpaperMoods,
    l10n.wallpaperGradients,
    l10n.wallpaperPatterns,
    l10n.wallpaperYourPhoto,
  };
  final width = t.view.physicalSize.width / t.view.devicePixelRatio;
  var seen = 0;
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    final s = p.text.toPlainText();
    if (!words.contains(s)) continue;
    seen++;
    final w = p.size.width;
    if (p.didExceedMaxLines) bad.add('cut short: $s');
    if (p.getMaxIntrinsicHeight(w) > p.size.height + 0.5) {
      bad.add('clipped: $s');
    }
    final word = p.getMinIntrinsicWidth(double.infinity);
    if (word > w + 0.5) {
      bad.add('word broken (${word.round()} in ${w.round()}): $s');
    }
    final left = p.localToGlobal(Offset.zero).dx;
    if (left < -0.5 || left + w > width + 0.5) bad.add('off screen: $s');
  }
  if (seen < words.length) bad.add('only $seen of ${words.length} on screen');
  return bad;
}

void main() {
  setUpAll(_loadFonts);
  tearDown(() => setL10nLocale(const Locale('en')));

  for (final locale in AppLocalizations.supportedLocales) {
    final code = locale.toLanguageTag();
    for (final scale in [1.0, _biggest]) {
      testWidgets('$code at ${scale}x: every name fits', (t) async {
        setL10nLocale(locale);
        await _open(t, locale, scale);
        expect(t.takeException(), isNull);
        expect(_misfits(t), isEmpty);
      });
    }
  }

  testWidgets('at the normal size the swatches keep their width and the '
      'long mood takes two lines', (t) async {
    await _open(t, const Locale('en'), 1);
    final name = find.text(l10n.atmosphereWarmAfternoon);
    final p = t.renderObject<RenderParagraph>(name);
    expect(p.size.width, 62);
    expect(p.didExceedMaxLines, isFalse);
    expect(
      p.size.height,
      greaterThan(t.getSize(find.text(l10n.atmosphereDusk)).height),
    );
  });
}
