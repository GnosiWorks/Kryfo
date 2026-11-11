// SPDX-License-Identifier: GPL-3.0-or-later
// han text is drawn in the glyphs its chinese wants, so '。' sits at the
// foot of the line in simplified chinese: the app's chinese first, then the
// phone's first chinese, then, in a message, what its characters say. the
// test font draws every glyph alike, so the check is the locale the text is
// laid out in, which picks the phone's font
import 'dart:ui' show Locale;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/cjk_locale.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_link_text.dart';
import 'package:kryfo/widgets/written_field.dart';

const _en = Locale('en', 'US');

void main() {
  test('the app\'s chinese, else the phone\'s first chinese', () {
    expect(cjkTextLocale(app: 'en', system: [_en]), isNull);
    expect(cjkTextLocale(app: 'zh', system: [_en]), kHans);
    expect(cjkTextLocale(app: 'zh_Hant', system: [_en]), kHantTw);
    expect(
      cjkTextLocale(app: 'zh_Hant', system: [const Locale('zh', 'HK')]),
      kHantHk,
    );
    expect(
      cjkTextLocale(app: 'en', system: [_en, const Locale('zh', 'CN')]),
      kHans,
    );
    expect(
      cjkTextLocale(
        app: 'en',
        system: [
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ],
      ),
      kHans,
    );
    expect(
      cjkTextLocale(app: 'en', system: [const Locale('zh', 'TW')]),
      kHantTw,
    );
    // a phone that reads japanese first keeps its own glyphs
    expect(
      cjkTextLocale(
        app: 'en',
        system: [const Locale('ja'), const Locale('zh', 'CN')],
      ),
      isNull,
    );
    // a simplified chinese ui on a taiwanese phone is still simplified
    expect(cjkTextLocale(app: 'zh', system: [const Locale('zh', 'TW')]), kHans);
  });

  test('a message\'s own characters', () {
    expect(cjkLocaleFor('日本。韩国。'), kHans);
    expect(cjkLocaleFor('see you 明天见'), kHans);
    expect(cjkLocaleFor('日本語のテキストです。'), kJapanese);
    expect(cjkLocaleFor('hello there.'), isNull);
    expect(cjkLocaleFor('日本。韓國。', fallback: kHantTw), kHantTw);
    // kana says japanese whatever the phone's chinese
    expect(cjkLocaleFor('ありがとう。', fallback: kHans), kJapanese);
  });

  testWidgets('日本。韩国。 in an english ui is laid out as simplified chinese', (
    t,
  ) async {
    // the test runner's phone lists chinese second: this one has none
    t.platformDispatcher.localesTestValue = const [_en];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              KryfoLinkText(
                key: const ValueKey('zh'),
                text: '日本。韩国。',
                style: HaloType.sans(size: 15),
                linkColor: HaloColors.amberText,
              ),
              KryfoLinkText(
                key: const ValueKey('en'),
                text: 'Japan. Korea.',
                style: HaloType.sans(size: 15),
                linkColor: HaloColors.amberText,
              ),
            ],
          ),
        ),
      ),
    );
    RichText rich(String k) => t.widget<RichText>(
      find.descendant(
        of: find.byKey(ValueKey(k)),
        matching: find.byType(RichText),
      ),
    );
    expect(rich('zh').text.style!.locale, kHans);
    // the paragraph itself is laid out with it
    final p = t.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('zh')),
        matching: find.byType(RichText),
      ),
    );
    expect(p.text.style!.locale, kHans);
    // latin text in an english ui on a phone with no chinese keeps the
    // ui's locale
    expect(rich('en').text.style!.locale, isNull);
  });

  testWidgets('a phone with simplified chinese among its languages: han '
      'text takes it, latin text and our styles stay as they are', (t) async {
    t.platformDispatcher.localesTestValue = const [_en, Locale('zh', 'TW')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    // a locale on latin text would send its quotes and dashes to a cjk font
    expect(HaloType.sans().locale, isNull);
    expect(hanLocaleOf('see you tomorrow'), isNull);
    expect(hanLocaleOf('日本。韓國。'), kHantTw);
    t.platformDispatcher.localesTestValue = const [_en, Locale('zh', 'CN')];
    expect(hanLocaleOf('日本。韩国。'), kHans);
  });

  testWidgets('a phone that reads japanese or korean first keeps its own '
      'han glyphs; kana is still japanese', (t) async {
    t.platformDispatcher.localesTestValue = const [_en, Locale('ja', 'JP')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    expect(hanLocaleOf('日本。韩国。'), isNull);
    expect(hanLocaleOf('ありがとう。'), kJapanese);
    t.platformDispatcher.localesTestValue = const [
      Locale('ko', 'KR'),
      Locale('zh', 'CN'),
    ];
    expect(hanLocaleOf('大韓民國'), isNull);
    // chinese before japanese: the chinese glyphs
    t.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
      Locale('ja', 'JP'),
    ];
    expect(hanLocaleOf('日本。韩国。'), kHans);
  });

  testWidgets('every bubble path takes it: a style for han text, the style '
      'itself for latin', (t) async {
    t.platformDispatcher.localesTestValue = const [_en];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final base = HaloType.sans(size: 15);
    expect(withHan(base, '日本。韩国。').locale, kHans);
    expect(identical(withHan(base, 'Japan.'), base), isTrue);
    expect(withHan(base.copyWith(locale: kHantTw), '日本。韓國。').locale, kHantTw);
  });

  testWidgets('the composer lays out 日本。韩国。 as simplified chinese', (t) async {
    t.platformDispatcher.localesTestValue = const [_en];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final c = TextEditingController();
    addTearDown(c.dispose);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WrittenDir(
            controller: c,
            builder: (dir) => TextField(
              controller: c,
              textDirection: dir,
              style: HaloType.sans(
                size: 14,
              ).copyWith(locale: hanLocaleOf(c.text)),
            ),
          ),
        ),
      ),
    );
    Locale? laid() =>
        t.widget<EditableText>(find.byType(EditableText)).style.locale;
    expect(laid(), isNull);
    await t.enterText(find.byType(TextField), '日本。韩国。');
    await t.pump();
    expect(laid(), kHans);
    await t.enterText(find.byType(TextField), 'Japan.');
    await t.pump();
    expect(laid(), isNull);
  });
}
