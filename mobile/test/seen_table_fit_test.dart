// SPDX-License-Identifier: GPL-3.0-or-later
// the table of what we can see, in every language, drawn with the app's own
// fonts on a small phone at its smallest and biggest font: a column is as
// wide as its longest word, so no word in a cell or a column's name is
// broken inside, and the table stays on the screen
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/seen_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';

// the app clamps the phone's font size to this
const _biggest = 1.6;

// a small phone: 360 by 740
const _size = Size(1080, 2220);
const _ratio = 3.0;

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

// the words of the table's cells and column names
Set<String> _cells() => {
  l10n.seenOnion,
  l10n.seenRelay,
  l10n.seenFast,
  l10n.seenHidden,
  l10n.seenNever,
  l10n.seenOnDevice,
  l10n.seenYours,
  l10n.seenUnaudited,
  l10n.seenOurRelay,
  l10n.seenEveryRelay,
  l10n.seenIntroducer,
  l10n.seenRoomKeys,
  l10n.seenOverTor,
};

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setL10nLocale(const Locale('en')));

  for (final code in [
    'en',
    'de',
    'ru',
    'uk',
    'fr',
    'es',
    'pt',
    'it',
    'tr',
    'vi',
    'id',
    'fa',
    'ar',
    'zh',
    'zh-Hant',
  ]) {
    for (final scale in [1.0, _biggest]) {
      testWidgets('$code at $scale: every word of the table whole', (t) async {
        final parts = code.split('-');
        final locale = parts.length == 2
            ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
            : Locale(code);
        await devOpen(
          t,
          const SeenScreen(),
          locale: locale,
          scale: scale,
          size: _size,
          ratio: _ratio,
        );
        expect(t.takeException(), isNull);
        final cells = _cells();
        final width = _size.width / _ratio;
        final bad = <String>[];
        var seen = 0;
        for (final e in find.byType(RichText).evaluate()) {
          final p = e.renderObject! as RenderParagraph;
          final s = p.text.toPlainText();
          if (!cells.contains(s) || !p.attached || !p.hasSize) continue;
          seen++;
          final w = p.size.width;
          final word = p.getMinIntrinsicWidth(double.infinity);
          if (word > w + 0.5)
            bad.add('broken (${word.round()} in ${w.round()}): $s');
          if (p.didExceedMaxLines) bad.add('cut short: $s');
          final left = p.localToGlobal(Offset.zero).dx;
          if (left < -0.5 || left + w > width + 0.5) bad.add('off: $s');
        }
        expect(seen, greaterThan(10));
        expect(bad, isEmpty);
        await devClose(t);
      });
    }
  }
}
