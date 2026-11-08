// SPDX-License-Identifier: GPL-3.0-or-later
// the translate line under a message: there only when it should be, its
// menu on a long press (always this chat, never this language with an
// undo), no glyph of its own, the original
// one tap away, the translation marked as one, a pack's size and no fetch
// without a tap, translation off, and how it reads in 16 languages, right
// to left, with reduced motion and to a screen reader
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/translate_bubble.dart';
import 'package:kryfo/widgets/ease_size.dart';

import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';

Finder _rich(String s) => find.textContaining(s, findRichText: true);
Finder _more() => find.byKey(const ValueKey('tr-more'));
Finder _line() => _rich(l10n.translateAction);
Finder _idle() => find.byKey(const ValueKey('tr-idle'));
Finder _shownFoot() => find.byKey(const ValueKey('tr-shown'));

void main() {
  Widget page(
    ChatTranslation c,
    Map<String, String> msgs, {
    bool still = false,
    bool reader = false,
    Locale? locale,
  }) => MaterialApp(
    theme: buildHaloTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(
        ctx,
      ).copyWith(disableAnimations: still, accessibleNavigation: reader),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in msgs.entries)
              Container(
                key: ValueKey('bubble-${e.key}'),
                constraints: const BoxConstraints(maxWidth: 280),
                child: TranslatedBody(
                  chat: c,
                  msgKey: e.key,
                  text: e.value,
                  original: Text(e.value),
                  translated: (t) => Text(t),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<ChatTranslation> open(
    WidgetTester t,
    Fakes f,
    Map<String, String> msgs, {
    bool still = false,
    bool reader = false,
    Locale? locale,
  }) async {
    await f.hub.ready();
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    await t.pumpWidget(
      page(c, msgs, still: still, reader: reader, locale: locale),
    );
    await t.pumpAndSettle();
    return c;
  }

  testWidgets('a line only under a foreign message with a few words', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await open(t, f, {
      'u1': _zh,
      'u2': '你好',
      'u3': '张伟',
      'u4': '😂😂😂',
      'u5': 'see you at the station tomorrow',
      'u6': '明天见 see you tomorrow',
    });
    expect(_idle(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bubble-u1')),
        matching: _idle(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('show original is one tap away, and the translation is marked', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final f = fakeHub(installed: true, words: {_zh: _en});
    await open(t, f, {'u1': _zh});
    await t.tap(_rich(l10n.translateAction));
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
    // the line under it says it is a translation, with the mark
    expect(_shownFoot(), findsOneWidget);
    expect(_rich(l10n.translateFrom(langName('zh'))), findsOneWidget);
    expect(
      find.descendant(
        of: _shownFoot(),
        matching: find.byIcon(Icons.translate_rounded),
      ),
      findsOneWidget,
    );
    // and a screen reader hears it before the words
    expect(
      find.bySemanticsLabel(RegExp('^${l10n.translateFrom(langName('zh'))}')),
      findsWidgets,
    );
    await t.tap(_rich(l10n.translateShowOriginal));
    await t.pumpAndSettle();
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(_en), findsNothing);
    handle.dispose();
  });

  testWidgets('the menu: always translate this chat', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en, '我们后天在车站见吧': 'x'});
    final c = await open(t, f, {'u1': _zh, 'u2': '我们后天在车站见吧'});
    await t.longPress(_line().first);
    await t.pumpAndSettle();
    expect(find.text(l10n.translateAlwaysChat), findsOneWidget);
    expect(find.text(l10n.translateBarNever(langName('zh'))), findsOneWidget);
    await t.tap(find.text(l10n.translateAlwaysChat));
    await t.pumpAndSettle();
    expect(await f.store.chatAuto('heron'), isTrue);
    expect(c.auto, isTrue);
    // both translate on their own
    expect(find.text(_en), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
    // and off again from the same menu
    await t.longPress(_rich(l10n.translateShowOriginal).first);
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateAlwaysChat));
    await t.pumpAndSettle();
    expect(await f.store.chatAuto('heron'), isFalse);
    expect(find.text(_zh), findsOneWidget);
  });

  testWidgets('a long press on the line opens the menu too', (t) async {
    final f = fakeHub(installed: true);
    await open(t, f, {'u1': _zh});
    await t.longPress(_rich(l10n.translateAction));
    await t.pumpAndSettle();
    expect(find.text(l10n.translateAlwaysChat), findsOneWidget);
  });

  testWidgets('never offer: the line folds away, an undo brings it back', (
    t,
  ) async {
    final f = fakeHub(installed: true);
    await open(t, f, {'u1': _zh});
    final tall = t.getSize(find.byKey(const ValueKey('bubble-u1'))).height;
    await t.longPress(_line());
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateBarNever(langName('zh'))));
    // folds, not cut: part way down a frame later
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(find.byType(EaseSize), findsOneWidget);
    await t.pumpAndSettle();
    expect(f.store.settings.never, ['zh']);
    expect(_idle(), findsNothing);
    expect(
      t.getSize(find.byKey(const ValueKey('bubble-u1'))).height,
      lessThan(tall),
    );
    expect(find.text(l10n.translateNeverDone(langName('zh'))), findsOneWidget);
    await t.tap(find.text(l10n.translateUndo));
    await t.pumpAndSettle();
    expect(f.store.settings.never, isEmpty);
    expect(_idle(), findsOneWidget);
  });

  testWidgets('a pack not on the phone: its size, fetched only on a tap', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final f = fakeHub(words: {_zh: _en});
    await open(t, f, {'u1': _zh});
    final gz = zhCatalog.bundle('zh')!.gz;
    final offer = l10n.translateOfferDownload(langName('zh'), packSize(gz));
    expect(_rich(offer), findsOneWidget);
    expect(find.bySemanticsLabel(offer), findsOneWidget);
    // nothing started on its own
    await t.pump(const Duration(seconds: 2));
    expect(f.backend.started, isEmpty);
    await t.tap(_rich(offer));
    await t.pumpAndSettle();
    // the one-time download, with its size, waits for its own button
    expect(find.text(l10n.translateDownload(packSize(gz))), findsOneWidget);
    expect(f.backend.started, isEmpty);
    await t.tap(find.text(l10n.translateDownload(packSize(gz))));
    await t.pump(const Duration(milliseconds: 150));
    expect(f.backend.started, ['zh']);
    f.backend.finish('zh');
    await t.pump(const Duration(milliseconds: 150));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.commonDone));
    await t.pumpAndSettle();
    // the message the tap was for
    expect(find.text(_en), findsOneWidget);
    expect(_rich(offer), findsNothing);
    handle.dispose();
  });

  testWidgets('translation off: no line, no menu, nothing auto', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await f.hub.ready();
    await f.hub.setChatAuto('heron', true);
    await f.hub.setOn(false);
    await open(t, f, {'u1': _zh});
    expect(_idle(), findsNothing);
    expect(_more(), findsNothing);
    expect(find.text(_zh), findsOneWidget);
    expect(f.translator.asked, isEmpty);
    await f.hub.setOn(true);
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
  });

  testWidgets('reduced motion: the line and the words change at once', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await open(t, f, {'u1': _zh}, still: true);
    await t.tap(_rich(l10n.translateAction));
    await t.pump();
    await t.pump();
    expect(find.text(_en), findsOneWidget);
    expect(find.text(_zh), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('no glyph of its own: a foreign message is only a line taller', (
    t,
  ) async {
    final f = fakeHub(installed: true);
    await open(t, f, {'u1': _zh, 'u2': '你好'});
    expect(_more(), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    final line = t.getSize(_idle()).height;
    final tall = t.getSize(find.byKey(const ValueKey('bubble-u1'))).height;
    final short = t.getSize(find.byKey(const ValueKey('bubble-u2'))).height;
    expect(tall - short, moreOrLessEquals(line, epsilon: 0.5));
    expect(line, lessThan(24));
  });

  testWidgets('right to left: the line starts on the right', (t) async {
    final f = fakeHub(installed: true);
    await open(t, f, {'u1': _zh}, locale: const Locale('ar'));
    final icon = t.getCenter(
      find.descendant(
        of: _idle(),
        matching: find.byIcon(Icons.translate_rounded),
      ),
    );
    expect(icon.dx, greaterThan(t.getCenter(_line()).dx));
    await t.longPress(_line());
    await t.pumpAndSettle();
    expect(find.text(l10n.translateAlwaysChat), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'a screen reader: the line is a button with the menu as an action',
    (t) async {
      final handle = t.ensureSemantics();
      final f = fakeHub(installed: true, words: {_zh: _en});
      await open(t, f, {'u1': _zh});
      final line = t.getSemantics(find.bySemanticsLabel(l10n.translateAction));
      final data = line.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      // the menu by name, no long press needed
      final menu = CustomSemanticsAction(label: l10n.translateBarMore);
      final id = CustomSemanticsAction.getIdentifier(menu);
      expect(data.customSemanticsActionIds, contains(id));
      t.semantics.performAction(
        find.semantics.byLabel(l10n.translateAction),
        SemanticsAction.customAction,
        args: id,
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.translateAlwaysChat), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      t.semantics.tap(find.semantics.byLabel(l10n.translateAction));
      await t.pumpAndSettle();
      expect(find.text(_en), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('a screen reader on: the undo stays until it is used', (t) async {
    final f = fakeHub(installed: true);
    await open(t, f, {'u1': _zh}, reader: true);
    await t.longPress(_line());
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateBarNever(langName('zh'))));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 12));
    await t.pumpAndSettle();
    expect(find.text(l10n.translateUndo), findsOneWidget);
    await t.tap(find.text(l10n.translateUndo));
    await t.pumpAndSettle();
    expect(f.store.settings.never, isEmpty);
  });

  testWidgets('no screen reader: the undo goes after a while', (t) async {
    final f = fakeHub(installed: true);
    await open(t, f, {'u1': _zh});
    await t.longPress(_line());
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateBarNever(langName('zh'))));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 12));
    await t.pumpAndSettle();
    expect(find.text(l10n.translateUndo), findsNothing);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('the line and its menu in $locale', (t) async {
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      final f = fakeHub(installed: true, words: {_zh: _en});
      await open(t, f, {'u1': _zh}, locale: locale);
      expect(_idle(), findsOneWidget);
      expect(_rich(l10n.translateAction), findsOneWidget);
      await t.longPress(_line());
      await t.pumpAndSettle();
      expect(find.text(l10n.translateAlwaysChat), findsOneWidget);
      expect(find.text(l10n.translateBarNever(langName('zh'))), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
