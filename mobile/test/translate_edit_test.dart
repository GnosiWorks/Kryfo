// SPDX-License-Identifier: GPL-3.0-or-later
// a message they edit: what was made of the old words goes, and the new
// words are offered, or translated on their own in a chat set to
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/translate_bubble.dart';

import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';
const _zh2 = '我们后天在车站见吧';
const _en2 = 'See you at the station the day after tomorrow';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

Widget _framed(Widget child) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

Widget _bubble(ChatTranslation c, String text) => TranslatedBody(
  chat: c,
  msgKey: 'm1',
  text: text,
  original: Text(text),
  translated: (t) => Text(t),
);

void main() {
  test('an edit drops the old translation and its guess', () async {
    var asked = 0;
    final f = fakeHub(
      installed: true,
      words: {_zh: _en},
      guess: (t) {
        asked++;
        return detectLanguage(t);
      },
    );
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    await c.toggle('m1', _zh);
    expect(c.of('m1', _zh).text, _en);
    expect(c.of('m1', _zh2).phase, MsgPhase.idle);
    expect(c.of('m1', _zh2).text, isNull);
    expect(c.shown('m1', _zh2), isFalse);
    // the old words' guess went too: asked again
    final before = asked;
    c.offer(_zh);
    expect(asked, before + 1);
    c.dispose();
  });

  test('a translation of the old words that comes late is not kept', () async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    final run = c.toggle('m1', _zh);
    expect(c.of('m1', _zh2).text, isNull);
    await run;
    expect(c.of('m1', _zh2).text, isNull);
    expect(c.of('m1').text, isNull);
    c.dispose();
  });

  testWidgets('the bubble shows the new words, then their translation', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: {_zh: _en, _zh2: _en2});
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    await t.pumpWidget(_framed(_bubble(c, _zh)));
    await t.pump();
    await t.tap(find.textContaining(l10n.translateAction, findRichText: true));
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);

    await t.pumpWidget(_framed(_bubble(c, _zh2)));
    await t.pumpAndSettle();
    expect(find.text(_en), findsNothing);
    expect(find.text(_zh2), findsOneWidget);
    expect(find.byKey(const ValueKey('tr-shown')), findsNothing);

    // in a chat that translates on its own, the new words are translated
    await c.setAuto(true);
    await t.pumpAndSettle();
    expect(find.text(_en2), findsOneWidget);
  });
}
