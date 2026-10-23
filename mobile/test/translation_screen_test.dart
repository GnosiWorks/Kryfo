// SPDX-License-Identifier: GPL-3.0-or-later
// settings > translation: packs, languages, defaults, the mirror and the
// privacy note
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/translation_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/auto_translate_row.dart';
import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:kryfo/widgets/halo_rows.dart';
import 'package:kryfo/widgets/language_sheet.dart' show languageNameHere;

import 'translate_fakes.dart';

Widget framed(Widget home, {bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 150));
  await t.pumpAndSettle();
}

HaloRow row(WidgetTester t, String label) =>
    t.widget<HaloRow>(find.widgetWithText(HaloRow, label));

void main() {
  final zh = builtInCatalog.bundle('zh')!;

  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(720, 3200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  testWidgets('a pack not downloaded: its size, then a download', (t) async {
    tall(t);
    final f = fakeHub();
    await t.pumpWidget(framed(TranslationScreen(hub: f.hub)));
    await t.pumpAndSettle();
    expect(find.text(l10n.translatePackPair(l10n.translateLangZh)), findsOne);
    expect(find.text(l10n.translateNotDownloaded(packSize(zh.gz))), findsOne);
    await t.tap(find.text(l10n.translateDownload(packSize(zh.gz))));
    await settle(t);
    expect(f.backend.started, ['zh']);
    expect(find.text(l10n.translateDownloading), findsOneWidget);
    f.backend.finish('zh');
    await settle(t);
    expect(find.text(l10n.translateInstalled(packSize(zh.disk))), findsOne);
  });

  testWidgets('a pack on the phone: its size, and deleted after a yes', (
    t,
  ) async {
    tall(t);
    final f = fakeHub(installed: true);
    await t.pumpWidget(framed(TranslationScreen(hub: f.hub)));
    await t.pumpAndSettle();
    expect(find.text(l10n.translateInstalled(packSize(zh.disk))), findsOne);
    await t.tap(find.byTooltip(l10n.commonDelete));
    await t.pumpAndSettle();
    expect(
      find.text(l10n.translateDeleteTitle(l10n.translateLangZh)),
      findsOneWidget,
    );
    await t.tap(find.text(l10n.commonDelete).last);
    await t.pumpAndSettle();
    expect(f.backend.have, isEmpty);
    expect(find.text(l10n.translateNotDownloaded(packSize(zh.gz))), findsOne);
  });

  testWidgets('the defaults: no auto, wi-fi only', (t) async {
    tall(t);
    final f = fakeHub(settings: const TranslateSettings());
    await t.pumpWidget(framed(TranslationScreen(hub: f.hub)));
    await t.pumpAndSettle();
    expect(row(t, l10n.translateAutoDefault).toggled, isFalse);
    expect(row(t, l10n.translateWifiOnly).toggled, isTrue);
    expect(row(t, l10n.translateInto).value, l10n.translateAppLanguage);
    expect(row(t, l10n.translateMyLanguages).value, languageNameHere('en'));

    await t.tap(find.text(l10n.translateAutoDefault));
    await t.pumpAndSettle();
    expect(f.store.settings.autoDefault, isTrue);
    await t.tap(find.text(l10n.translateWifiOnly));
    await t.pumpAndSettle();
    expect(f.store.settings.wifiOnly, isFalse);
  });

  testWidgets('languages read and the one to translate into', (t) async {
    tall(t);
    final f = fakeHub();
    await t.pumpWidget(framed(TranslationScreen(hub: f.hub)));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateMyLanguages));
    await t.pumpAndSettle();
    await t.tap(find.text(languageNameHere('de')));
    await t.pump();
    await t.tap(find.text(l10n.commonDone));
    await t.pumpAndSettle();
    expect(f.store.settings.mine, ['de']);
    expect(
      row(t, l10n.translateMyLanguages).value,
      '${languageNameHere('en')}, ${languageNameHere('de')}',
    );

    await t.tap(find.text(l10n.translateInto));
    await t.pumpAndSettle();
    await t.tap(find.text(langName('zh')).last);
    await t.pumpAndSettle();
    expect(f.store.settings.target, 'zh');
    expect(row(t, l10n.translateInto).value, langName('zh'));
  });

  testWidgets('packs come from our mirror only: nothing to set', (t) async {
    tall(t);
    final f = fakeHub();
    await t.pumpWidget(framed(TranslationScreen(hub: f.hub)));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.dns_outlined), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await t.tap(find.text(l10n.translateWifiOnly));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.translateDownload(packSize(zh.gz))));
    await settle(t);
    expect(f.backend.started, ['zh']);
    f.backend.finish('zh');
    await settle(t);
  });

  testWidgets('the privacy note is there', (t) async {
    tall(t);
    final f = fakeHub();
    await t.pumpWidget(framed(TranslationScreen(hub: f.hub)));
    await t.pumpAndSettle();
    expect(find.text(l10n.translatePrivacyTitle), findsOneWidget);
    expect(find.text(l10n.translatePrivacyNote), findsOneWidget);
  });

  testWidgets('reduced motion: the page comes to rest', (t) async {
    tall(t);
    final f = fakeHub();
    await t.pumpWidget(framed(TranslationScreen(hub: f.hub), still: true));
    await t.pump();
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('a chat\'s own switch: off, on, and kept for that chat', (
    t,
  ) async {
    final f = fakeHub();
    Widget page(String id) => framed(
      Scaffold(
        body: HaloGroup(
          children: [
            AutoTranslateRow(key: ValueKey(id), chatId: id, hub: f.hub),
          ],
        ),
      ),
    );
    await t.pumpWidget(page('heron'));
    await t.pumpAndSettle();
    expect(row(t, l10n.translateAutoInChat).toggled, isFalse);
    await t.tap(find.text(l10n.translateAutoInChat));
    await t.pumpAndSettle();
    expect(row(t, l10n.translateAutoInChat).toggled, isTrue);
    expect(await f.store.chatAuto('heron'), isTrue);
    await t.pumpWidget(page('fox'));
    await t.pumpAndSettle();
    expect(row(t, l10n.translateAutoInChat).toggled, isFalse);
    await t.pumpWidget(page('heron'));
    await t.pumpAndSettle();
    expect(row(t, l10n.translateAutoInChat).toggled, isTrue);
  });
}
