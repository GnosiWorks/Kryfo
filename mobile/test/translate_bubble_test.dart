// SPDX-License-Identifier: GPL-3.0-or-later
// the translate line under a foreign message, and the pack sheet a tap
// opens when the pack is missing
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/downloads.dart';
import 'package:kryfo/translate/engine_bridge.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/pack_sheet.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:kryfo/translate/translate_bubble.dart';

import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';

Widget framed(Widget home, {bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: Scaffold(body: Center(child: home)),
);

Finder rich(String s) => find.textContaining(s, findRichText: true);

// a poll of the download, then whatever it set moving comes to rest
Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 150));
  await t.pumpAndSettle();
}

Widget bubble(ChatTranslation c, String text, {String key = 'm1'}) =>
    TranslatedBody(
      chat: c,
      msgKey: key,
      text: text,
      original: Text(text),
      translated: (t) => Text(t),
    );

void main() {
  final zhGz = builtInCatalog.bundle('zh')!.gz;

  Future<ChatTranslation> open(
    WidgetTester t,
    Fakes f,
    Widget Function(ChatTranslation) build, {
    bool still = false,
  }) async {
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    await t.pumpWidget(framed(build(c), still: still));
    await t.pump();
    return c;
  }

  testWidgets('a foreign message offers translate; ours does not', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await open(
      t,
      f,
      (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble(c, _zh),
          bubble(c, 'see you tomorrow, then', key: 'm2'),
        ],
      ),
    );
    expect(rich(l10n.translateAction), findsOneWidget);
    expect(find.text(_en), findsNothing);
  });

  testWidgets('no chat handed in: the words as they are', (t) async {
    await t.pumpWidget(
      framed(
        TranslatedBody(
          chat: null,
          msgKey: 'm',
          text: _zh,
          original: const Text(_zh),
          translated: (s) => Text(s),
        ),
      ),
    );
    expect(find.text(_zh), findsOneWidget);
    expect(rich(l10n.translateAction), findsNothing);
  });

  testWidgets('tap: the translation with its source; show original', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await open(t, f, (c) => bubble(c, _zh));
    await t.tap(rich(l10n.translateAction));
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
    expect(find.text(_zh), findsNothing);
    final label = l10n.translateFrom(l10n.translateLangZh);
    expect(find.textContaining(label, findRichText: true), findsOneWidget);
    expect(rich(l10n.translateShowOriginal), findsOneWidget);
    await t.tap(rich(l10n.translateShowOriginal));
    await t.pumpAndSettle();
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(_en), findsNothing);
    expect(rich(l10n.translateAction), findsOneWidget);
    // shown again from what was made, not made again
    await t.tap(rich(l10n.translateAction));
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
    expect(f.translator.asked, hasLength(1));
  });

  testWidgets('a failure says so and can be tried again', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    f.translator.breakNext = true;
    await open(t, f, (c) => bubble(c, _zh));
    await t.tap(rich(l10n.translateAction));
    await t.pumpAndSettle();
    expect(
      find.textContaining(l10n.translateFailed, findRichText: true),
      findsOneWidget,
    );
    await t.tap(find.textContaining(l10n.commonTryAgain, findRichText: true));
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
  });

  testWidgets('no pack: the size first, then progress, cancel, resume, and '
      'the message translated once it is in', (t) async {
    final f = fakeHub(words: {_zh: _en});
    await open(t, f, (c) => bubble(c, _zh));
    await t.tap(rich(l10n.translateAction));
    await t.pumpAndSettle();
    expect(find.text(l10n.translatePackTitle(l10n.translateLangZh)), findsOne);
    final download = l10n.translateDownload(packSize(zhGz));
    expect(find.text(download), findsOneWidget);
    expect(packSize(zhGz), l10n.transportMb('75'));
    expect(f.backend.started, isEmpty);

    await t.tap(find.text(download));
    await settle(t);
    expect(f.backend.started, ['zh']);
    f.backend.status = FetchStatus('running', done: zhGz ~/ 4, total: zhGz);
    await settle(t);
    expect(
      find.text(l10n.translateProgress(packSize(zhGz ~/ 4), packSize(zhGz))),
      findsOneWidget,
    );
    expect(find.text(l10n.commonCancel), findsOneWidget);

    await t.tap(find.text(l10n.commonCancel));
    f.backend.disk = zhGz ~/ 4;
    await settle(t);
    expect(find.text(l10n.translateResume), findsOneWidget);
    expect(find.text(l10n.translatePaused(packSize(zhGz ~/ 4))), findsOne);

    await t.tap(find.text(l10n.translateResume));
    await settle(t);
    expect(f.backend.started, ['zh', 'zh']);
    f.backend.finish('zh');
    await settle(t);
    expect(find.text(l10n.commonDone), findsOneWidget);
    await t.tap(find.text(l10n.commonDone));
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
  });

  testWidgets('download errors say why, and try again', (t) async {
    final f = fakeHub();
    f.backend.startAnswer = 'error: tor: not started';
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    final b = builtInCatalog.bundle('zh')!;
    await t.pumpWidget(framed(PackControls(hub: f.hub, bundle: b)));
    await t.pump();
    await t.tap(find.text(l10n.translateDownload(packSize(b.gz))));
    await settle(t);
    expect(find.text(l10n.translateFailNoTor), findsOneWidget);
    expect(find.text(l10n.commonTryAgain), findsOneWidget);

    f.backend.startAnswer = 'ok';
    await t.tap(find.text(l10n.commonTryAgain));
    await settle(t);
    f.backend.status = const FetchStatus('failed', kind: 'hash');
    await settle(t);
    expect(find.text(l10n.translateFailBadFile), findsOneWidget);

    await t.tap(find.text(l10n.commonTryAgain));
    await settle(t);
    f.backend.status = const FetchStatus('failed', kind: 'net');
    await settle(t);
    expect(find.text(l10n.translateFailNetwork), findsOneWidget);

    f.backend.startAnswer = 'error: engine has no downloads';
    await t.tap(find.text(l10n.commonTryAgain));
    await settle(t);
    expect(find.text(l10n.translateFailNoEngine), findsOneWidget);
    expect(find.text(l10n.commonTryAgain), findsNothing);
  });

  testWidgets('wi-fi only off wi-fi: said, and a way to go now', (t) async {
    final f = fakeHub(
      settings: const TranslateSettings(wifiOnly: true),
      wifi: false,
    );
    final b = builtInCatalog.bundle('zh')!;
    await f.hub.ready();
    await t.pumpWidget(framed(PackControls(hub: f.hub, bundle: b)));
    await t.tap(find.text(l10n.translateDownload(packSize(b.gz))));
    await settle(t);
    expect(find.text(l10n.translateNeedsWifi), findsOneWidget);
    expect(f.backend.started, isEmpty);
    await t.tap(find.text(l10n.translateDownloadAnyway));
    await settle(t);
    expect(f.backend.started, ['zh']);
    expect(f.hub.downloads.of('zh').phase, DlPhase.running);
    f.backend.finish('zh');
    await settle(t);
    expect(
      find.text(l10n.translateInstalled(packSize(f.backend.disk))),
      findsOne,
    );
  });

  testWidgets('no library: the sheet says so, and offers the pack', (t) async {
    final f = fakeHub(lib: false);
    await open(t, f, (c) => bubble(c, _zh));
    await t.tap(rich(l10n.translateAction));
    await t.pumpAndSettle();
    expect(find.text(l10n.translatePackNoLib), findsOneWidget);
    expect(find.text(l10n.translateDownload(packSize(zhGz))), findsOneWidget);
  });

  testWidgets('a chat set to translate does it without a tap', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await f.store.setChatAuto('heron', true);
    await open(t, f, (c) => bubble(c, _zh));
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
    expect(rich(l10n.translateShowOriginal), findsOneWidget);
  });

  testWidgets('another chat stays as it was written', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await f.store.setChatAuto('fox', true);
    await open(t, f, (c) => bubble(c, _zh));
    await t.pumpAndSettle();
    expect(find.text(_zh), findsOneWidget);
    expect(find.text(_en), findsNothing);
  });

  testWidgets('reduced motion: the swap is immediate', (t) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    await open(t, f, (c) => bubble(c, _zh), still: true);
    await t.tap(rich(l10n.translateAction));
    await t.pump();
    await t.pump();
    expect(find.text(_en), findsOneWidget);
    expect(find.text(_zh), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
  });
}
