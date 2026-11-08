// SPDX-License-Identifier: GPL-3.0-or-later
// the first translation opens the model, which takes a moment on a phone:
// the message says "Translating…" the whole time, cold and again after the
// model closed in the background, and the words come once it is open
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/translate_bubble.dart';

import 'translate_fakes.dart';

const _zh1 = '你好，我们明天见吧';
const _zh2 = '我今天下班有点晚，大概八点到家';
const _en1 = 'Hello, see you tomorrow';
const _en2 = "I'm a bit late from work, home around eight";

Finder _rich(String s) => find.textContaining(s, findRichText: true);

void main() {
  testWidgets(
    '"Translating…" while the model loads, cold and after it closed',
    (t) async {
      final f = fakeHub(installed: true, words: {_zh1: _en1, _zh2: _en2});
      await f.hub.ready();
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: buildHaloTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                for (final (k, s) in [('u1', _zh1), ('u2', _zh2)])
                  TranslatedBody(
                    key: ValueKey(k),
                    chat: c,
                    msgKey: k,
                    text: s,
                    original: Text(s),
                    translated: (x) => Text(x),
                  ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      Future<void> loads(String key, String en) async {
        // the model is still opening
        final load = Completer<void>();
        f.translator.gate = load;
        await t.tap(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: _rich(l10n.translateAction),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 100));
          expect(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: _rich(l10n.translateWorking),
            ),
            findsOneWidget,
            reason: 'at ${i * 100} ms',
          );
        }
        expect(find.text(en), findsNothing);
        load.complete();
        f.translator.gate = null;
        await t.pumpAndSettle();
        expect(find.text(en), findsOneWidget);
        expect(_rich(l10n.translateWorking), findsNothing);
      }

      // cold: nothing opened yet
      await loads('u1', _en1);
      // the app went to the background: the model closed, and opens again
      await f.hub.away();
      expect(f.translator.closes, 1);
      await loads('u2', _en2);
    },
  );
}
