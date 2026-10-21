// SPDX-License-Identifier: GPL-3.0-or-later
// card on support: one more choice after the coins, the line about where
// the money goes, and a page that opens in the browser only after a yes,
// with the url as it is
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/open_outside.dart';
import 'package:kryfo/screens/donate_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url =
    'https://checkout.revolut.com/pay/6153a006-b91f-42fa-b433-aa903b890840';

Widget _framed({bool still = false}) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: const DonateScreen(),
);

final _clip = <String>[];

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(720, 1600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  _clip.clear();
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    if (c.method == 'Clipboard.setData') {
      _clip.add((c.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _beats(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toCard(WidgetTester t) async {
  final card = find.text(l10n.donateCard);
  await t.scrollUntilVisible(card, 200);
  await t.tap(card);
  await _beats(t);
  await t.scrollUntilVisible(find.text(l10n.donateCardPay), 200);
  await _beats(t);
}

void main() {
  late List<Uri> opened;
  late bool takes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    opened = [];
    takes = true;
    openOutsideForTest = (u) async {
      opened.add(u);
      return takes;
    };
  });
  tearDown(() => openOutsideForTest = null);

  testWidgets('card comes after the coins, and the coins stay', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await _beats(t);
    double y(String s) => t.getTopLeft(find.text(s)).dy;
    for (final c in [
      l10n.donateBitcoin,
      l10n.donateMonero,
      l10n.donateSolana,
      l10n.donateEthereum,
    ]) {
      expect(find.text(c), findsOneWidget);
      expect(y(c), lessThan(y(l10n.donateCard)));
    }
    // bitcoin is still the one chosen first
    expect(find.text(l10n.donateCardPay), findsNothing);
    expect(find.text(l10n.donateCopyAddress), findsOneWidget);
  });

  testWidgets('chosen, it says where the money goes, in no grey', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await _beats(t);
    await _toCard(t);
    expect(
      find.text(
        'Card payments go to Marios directly until our fiscal host is set up.',
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.donateCopyAddress), findsNothing);
    for (final s in [l10n.donateCardOneTime, l10n.donateCardMarios]) {
      expect(t.widget<Text>(find.text(s)).style?.color, HaloColors.text);
    }
    expect(
      t.widget<Text>(find.text(l10n.donateCardSeesName)).style?.color,
      HaloColors.text2,
    );
    expect(t.getSize(find.text(l10n.donateCardPay)).height, greaterThan(0));
    expect(t.takeException(), isNull);
  });

  testWidgets('the page opens only after a yes, with the url as it is', (
    t,
  ) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await _beats(t);
    await _toCard(t);
    await t.tap(find.text(l10n.donateCardPay));
    await _beats(t);
    expect(find.text(l10n.settingsFollowBrowserNote), findsOneWidget);
    expect(opened, isEmpty);
    // cancel opens nothing
    await t.tap(find.text(l10n.commonCancel));
    await _beats(t);
    expect(opened, isEmpty);
    await t.tap(find.text(l10n.donateCardPay));
    await _beats(t);
    await t.tap(find.text(l10n.settingsFollowOpen));
    await _beats(t);
    expect(opened.map((u) => u.toString()), [_url]);
    expect(opened.single.hasQuery, isFalse);
    expect(kCardUrl, _url);
    expect(_clip, isEmpty);
  });

  testWidgets('no browser: the link goes on the clipboard', (t) async {
    _phone(t);
    takes = false;
    await t.pumpWidget(_framed(still: true));
    await _beats(t);
    await _toCard(t);
    await t.tap(find.text(l10n.donateCardPay));
    await _beats(t);
    await t.tap(find.text(l10n.settingsFollowOpen));
    await _beats(t);
    expect(_clip, [_url]);
    expect(find.text(l10n.settingsLinkCopied), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
  });

  test('every language names Marios and no amount', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      expect(l.donateCardMarios, contains('Marios'), reason: tag);
      for (final s in [
        l.donateCard,
        l.donateCardOneTime,
        l.donateCardMarios,
        l.donateCardSeesName,
        l.donateCardPay,
      ]) {
        expect(s.trim(), isNotEmpty, reason: tag);
        expect(s, isNot(contains(RegExp(r'[0-9€$]'))), reason: '$tag: $s');
        expect(s, isNot(contains('—')), reason: '$tag: $s');
      }
      if (locale.languageCode != 'en') {
        expect(
          l.donateCardMarios,
          isNot(lookupAppLocalizations(const Locale('en')).donateCardMarios),
          reason: tag,
        );
      }
    }
  });
}
