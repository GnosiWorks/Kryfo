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

  testWidgets('a phone with simplified chinese among its languages: every '
      'style carries it', (t) async {
    t.platformDispatcher.localesTestValue = const [_en, Locale('zh', 'CN')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    expect(HaloType.sans().locale, kHans);
    expect(HaloType.serif().locale, kHans);
    t.platformDispatcher.localesTestValue = const [_en, Locale('zh', 'TW')];
    expect(HaloType.sans().locale, kHantTw);
    t.platformDispatcher.localesTestValue = const [_en];
    expect(HaloType.sans().locale, isNull);
  });
}
