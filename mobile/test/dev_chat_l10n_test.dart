// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat in the languages that need a look, drawn with the
// app's own fonts on a small phone: the long ones at the biggest font the
// app allows, persian and arabic mirrored. the row, its sheet, its delete,
// the settings row and the honest list: every word whole, inside its box
// and on the screen, and Marios in Latin letters
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/screens/dev_about_sheet.dart';
import 'package:kryfo/screens/seen_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/widgets/dev_avatar.dart';
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

// the words the chat brought, in the language on screen
Set<String> _ours() => {
  l10n.devRowTitle,
  l10n.devPinned,
  l10n.devAnonymous,
  l10n.devAboutLine,
  l10n.devKeyLabel,
  l10n.devDeleteLine,
  l10n.devDeleteLineAnon,
  l10n.settingsWriteToMarios,
  l10n.settingsWriteToMariosHint,
  l10n.seenDevChat,
  l10n.seenDevChatCell,
  l10n.seenDevChatLine,
  l10n.contactMute,
  l10n.contactUnmute,
  l10n.contactPinToTop,
  l10n.contactUnpin,
  l10n.contactArchive,
  l10n.contactDeleteChat,
};

final _bad = <String>[];

// no word broken across lines, no line cut off by its box, and the box on
// the screen from side to side. a row's one-line title ends in an ellipsis
// by design, so [skip] leaves it out
void _fits(
  WidgetTester t,
  String page, {
  Set<String> skip = const {},
  bool need = true,
}) {
  expect(t.takeException(), isNull, reason: page);
  final ours = _ours().difference(skip);
  final width = t.view.physicalSize.width / t.view.devicePixelRatio;
  var seen = 0;
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    final s = p.text.toPlainText();
    if (!ours.contains(s) || !p.attached || !p.hasSize) continue;
    seen++;
    final w = p.size.width;
    if (p.didExceedMaxLines) _bad.add('$page, cut short: $s');
    if (p.getMaxIntrinsicHeight(w) > p.size.height + 0.5) {
      _bad.add('$page, clipped: $s');
    }
    final word = p.getMinIntrinsicWidth(double.infinity);
    if (word > w + 0.5) {
      _bad.add('$page, a word broken (${word.round()} in ${w.round()}): $s');
    }
    final left = p.localToGlobal(Offset.zero).dx;
    if (left < -0.5 || left + w > width + 0.5) _bad.add('$page, off: $s');
  }
  // the page showed some of them, or it checked nothing
  if (need) expect(seen, greaterThan(0), reason: page);
}

Future<void> _walk(WidgetTester t, Locale locale, double scale) async {
  final tag = '${locale.toLanguageTag()} at $scale';
  await devWorld(chats: [('amber-fox-river', 50, false)]);
  await devTestChat.begin(
    currentDevKey!,
    anon: const DevAnon(id: 'made-for-this', edPriv: 'e', xPriv: 'x'),
  );
  await appState.refreshContacts();
  expect(l10n.devRowTitle, contains('Marios'));

  // the row: whole, the ring at the start of reading
  await devOpen(
    t,
    devHome(),
    locale: locale,
    scale: scale,
    size: _size,
    ratio: _ratio,
  );
  _fits(t, '$tag, home', skip: {l10n.devRowTitle}, need: false);
  final title = find.text(l10n.devRowTitle);
  expect(title, findsOneWidget, reason: tag);
  final rtl = Directionality.of(t.element(title)) == TextDirection.rtl;
  final ring = t.getCenter(find.byType(DevAvatar));
  expect(
    rtl ? ring.dx > t.getCenter(title).dx : ring.dx < t.getCenter(title).dx,
    isTrue,
    reason: tag,
  );
  await devClose(t);

  // its sheet, and the delete it asks about
  await devOpen(
    t,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showDevAboutSheet(context),
            child: const Text('about'),
          ),
        ),
      ),
    ),
    locale: locale,
    scale: scale,
    size: _size,
    ratio: _ratio,
  );
  await t.tap(find.text('about'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  _fits(t, '$tag, sheet');
  final del = find.text(l10n.contactDeleteChat);
  await t.scrollUntilVisible(
    del,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await t.pump(const Duration(milliseconds: 300));
  _fits(t, '$tag, sheet bottom');
  await t.tap(del);
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  _fits(t, '$tag, delete');
  expect(find.text(l10n.devDeleteLineAnon), findsOneWidget, reason: tag);
  await devClose(t);

  // the settings row
  await devOpen(
    t,
    const SettingsScreen(),
    locale: locale,
    scale: scale,
    size: _size,
    ratio: _ratio,
  );
  final write = find.text(l10n.settingsWriteToMarios);
  await t.scrollUntilVisible(
    write,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(t.element(write), alignment: 0.5);
  await t.pump(const Duration(milliseconds: 500));
  _fits(t, '$tag, settings');
  await devClose(t);
}

// the honest list's table keeps its columns narrow at any size; its words
// are checked at the size most phones use
Future<void> _seen(WidgetTester t, Locale locale) async {
  final tag = '${locale.toLanguageTag()}, seen';
  await devWorld();
  await devOpen(
    t,
    const SeenScreen(),
    locale: locale,
    size: _size,
    ratio: _ratio,
  );
  final row = find.text(l10n.seenDevChat);
  await t.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(t.element(row), alignment: 0.3);
  await t.pump(const Duration(milliseconds: 500));
  await t.tap(row);
  await t.pump(const Duration(milliseconds: 500));
  _fits(t, tag);
  expect(find.text(l10n.seenDevChatLine), findsOneWidget, reason: tag);
  await devClose(t);
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    useDevKeysForTest([devCard('m1')]);
    _bad.clear();
  });

  tearDown(() {
    useDevKeysForTest(null);
    setL10nLocale(const Locale('en'));
  });

  for (final code in ['de', 'ru', 'uk', 'fr', 'vi', 'fa', 'ar']) {
    testWidgets('$code: the row, its sheet and its rows fit', (t) async {
      await _walk(t, Locale(code), 1);
      await _walk(t, Locale(code), _biggest);
      await _seen(t, Locale(code));
      expect(_bad, isEmpty);
    });
  }
}
