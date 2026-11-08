// SPDX-License-Identifier: GPL-3.0-or-later
// the download offer under a message: once per language, under the newest
// message in it, and an x that puts the language on the never list, with
// a way back from the translation settings
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:kryfo/translate/translate_bubble.dart';

import 'translate_fakes.dart';

const _a = 'Привет, увидимся завтра на вокзале';
const _b = 'Спасибо, до встречи у входа в парк';
const _c = 'Хорошо, тогда я возьму билеты на всех';

Fakes _reader() => fakeHub(
  app: 'de',
  catalog: dirCatalog,
  settings: const TranslateSettings(wifiOnly: false),
  guess: (_) => LangGuess('ru', 1),
);

Widget _framed(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Widget _body(ChatTranslation c, String key, String text, int? came) =>
    TranslatedBody(
      key: ValueKey('body-$key'),
      chat: c,
      msgKey: key,
      text: text,
      came: came,
      original: Text(text),
      translated: (s) => Text(s),
    );

Finder _offerIn(String key) => find.descendant(
  of: find.byKey(ValueKey('body-$key')),
  matching: find.byKey(const ValueKey('tr-offer')),
);

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 150));
  await t.pumpAndSettle();
}

void main() {
  Future<ChatTranslation> open(
    WidgetTester t,
    Fakes f,
    List<(String, String, int?)> msgs,
  ) async {
    await f.hub.ready();
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    await show(t, c, msgs);
    return c;
  }

  testWidgets('once per language: under the newest message only', (t) async {
    final f = _reader();
    final c = await open(t, f, [('u1', _a, 1), ('u2', _b, 2)]);
    expect(find.byKey(const ValueKey('tr-offer')), findsOneWidget);
    expect(_offerIn('u2'), findsOneWidget);
    // a newer one comes: the offer moves to it
    await show(t, c, [('u1', _a, 1), ('u2', _b, 2), ('u3', _c, 3)]);
    expect(find.byKey(const ValueKey('tr-offer')), findsOneWidget);
    expect(_offerIn('u3'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('without an arrival time every message offers', (t) async {
    final f = _reader();
    await open(t, f, [('u1', _a, null), ('u2', _b, null)]);
    expect(find.byKey(const ValueKey('tr-offer')), findsNWidgets(2));
  });

  testWidgets('the x: never offered again, with undo', (t) async {
    final f = _reader();
    await open(t, f, [('u1', _a, 1)]);
    final x = find.byKey(const ValueKey('tr-offer-close'));
    expect(x, findsOneWidget);
    expect(
      find.bySemanticsLabel(l10n.translateBarNever(langName('ru'))),
      findsOneWidget,
    );
    await t.tap(x);
    await _settle(t);
    expect(f.hub.settings.never, ['ru']);
    expect(find.byKey(const ValueKey('tr-offer')), findsNothing);
    expect(find.text(l10n.translateNeverDone(langName('ru'))), findsOneWidget);
    // nothing fetched by the x
    expect(f.backend.started, isEmpty);
    await t.tap(find.text(l10n.translateUndo));
    await _settle(t);
    expect(f.hub.settings.never, isEmpty);
    expect(find.byKey(const ValueKey('tr-offer')), findsOneWidget);
  });

  test('the never list empties in one go', () async {
    final f = _reader();
    await f.hub.ready();
    await f.hub.neverFor('ru');
    await f.hub.neverFor('de');
    expect(f.hub.settings.never, ['ru', 'de']);
    await f.hub.offerAllAgain();
    expect(f.hub.settings.never, isEmpty);
    expect((await f.store.load()).never, isEmpty);
  });
}

Future<void> show(
  WidgetTester t,
  ChatTranslation c,
  List<(String, String, int?)> msgs,
) async {
  await t.pumpWidget(
    _framed(
      Scaffold(
        body: Column(
          children: [for (final (k, s, at) in msgs) _body(c, k, s, at)],
        ),
      ),
    ),
  );
  await _settle(t);
}
