// SPDX-License-Identifier: GPL-3.0-or-later
// with the paid tiers off, support is the four addresses and nothing more:
// no tier, no invoice, no word about badges, and nothing asks the badge
// service. a badge someone already has still shows.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/address_text.dart';
import 'package:kryfo/badge_client.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/donate_screen.dart';
import 'package:kryfo/screens/profile_screen.dart';
import 'package:kryfo/supporter.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget framed(Widget home, {bool still = false}) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

// what went on the clipboard
final _copied = <String>[];

// tall and wide: the test font's square glyphs need the room
void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1600, 3200);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  _copied.clear();
  final m = t.binding.defaultBinaryMessenger;
  const secure = MethodChannel('halo/platform');
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(secure, (c) async {
    if (c.method != 'copySensitive') return null;
    _copied.add((c.arguments as Map)['text'] as String);
    return true;
  });
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(secure, null);
  });
}

// a coin picked, and the box it leaves gone from the tree
Future<void> pick(WidgetTester t, String coin) async {
  await t.tap(find.text(coin));
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

// the toast, and the minute a copied address stays on the clipboard
Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pump(const Duration(seconds: 61));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

// every tor request is written down and answered as the service would
class _Engine implements HaloEngine {
  final asked = <String>[];
  @override
  Future<String> torPost(String url, String body) async {
    asked.add(url);
    return '{"id":"inv1","tier":"supporter","address":"bc1qtest","btc":"0.0002"}';
  }

  @override
  Future<String> torGetJson(String url) async {
    asked.add(url);
    return '{"status":"pending"}';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _addrs = {
  'btc': 'bc1qdewmhrwkh8elts8ldehfq5qaj68ymexfnzkk7j',
  'xmr':
      '4ApyZS72ZYCG3z8rtwwX6JgdjSdAcphHSFRxiKrL5yLnYYz8fvXQayWMyw79AxFoQ7BXLfzEExk5f7Z2xPdEPWyRBXtVwiD',
  'sol': 'DrxaQPM8wD63EErdGN9GrazGVnxwiCB9Pc6RYR3v2x4a',
  'eth': '0x55014AF792d54E4350b7f4bfc7be7D62EbbCfE43',
};

Map<String, String> get _coinNames => {
  'btc': l10n.donateBitcoin,
  'xmr': l10n.donateMonero,
  'sol': l10n.donateSolana,
  'eth': l10n.donateEthereum,
};

// every piece of text on screen, rich text included
List<String> shown(WidgetTester t) => [
  for (final w in t.widgetList(find.byType(RichText)))
    (w as RichText).text.toPlainText(),
];

void main() {
  late _Engine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    engine = _Engine();
    useEngineForTest(engine);
    appState.sendModeForTest = 'private';
  });

  test('the tiers are off', () {
    expect(kBadgeTiersShown, isFalse);
  });

  for (final mode in ['private', 'balanced']) {
    testWidgets('support shows no tier and no badge talk ($mode)', (t) async {
      phone(t);
      appState.sendModeForTest = mode;
      await t.pumpWidget(framed(const DonateScreen()));
      await t.pump(const Duration(seconds: 1));
      for (final coin in _coinNames.values) {
        await pick(t, coin);
        for (final s in [
          l10n.donateTierSupporter,
          l10n.donateTierPatron,
          l10n.donateTierGuardian,
          r'$20',
          r'$50',
          r'$100',
          l10n.donatePayWithBitcoin,
          l10n.donateBadgesStartAt20,
          l10n.donateBitcoinBadgesNeedOnion,
          l10n.donateSwitchToOnion,
          l10n.donateBadgeUnlocks,
          l10n.donateManualNoBadge,
          l10n.donateBitcoinIsVerifiedBy,
          l10n.donateWeCanTVerify,
        ]) {
          expect(find.text(s), findsNothing, reason: '$coin: $s');
        }
        final badgeTalk = [
          for (final s in shown(t))
            if (s.toLowerCase().contains('badge')) s,
        ];
        expect(badgeTalk, isEmpty, reason: coin);
      }
      // the page still reads as one: hero, coins, the address
      expect(find.text(l10n.donateNoAdsNoInvestors), findsOneWidget);
      expect(find.text(l10n.donateCopyAddress), findsOneWidget);
      expect(t.takeException(), isNull);
      await drain(t);
    });
  }

  testWidgets('nothing on support asks the badge service', (t) async {
    phone(t);
    // an invoice left open by an older version: kept, and not asked about
    SharedPreferences.setMockInitialValues({
      'badge_open_invoice': 'inv0|patron',
    });
    await t.pumpWidget(framed(const DonateScreen()));
    await t.pump(const Duration(seconds: 1));
    for (final coin in _coinNames.values) {
      await pick(t, coin);
      await t.tap(find.text(l10n.donateCopyAddress));
      await t.pump(const Duration(seconds: 1));
    }
    await t.pump(const Duration(minutes: 2));
    expect(engine.asked, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('badge_open_invoice'), 'inv0|patron');
    await drain(t);
  });

  test('the invoice calls stay home', () async {
    SharedPreferences.setMockInitialValues({
      'badge_open_invoice': 'inv0|patron',
    });
    expect(await createInvoice('supporter'), isNull);
    expect(await settleOpenInvoice(), isNull);
    expect(engine.asked.where((u) => u.startsWith(kBadgeOnion)), isEmpty);
    expect(await loadSupporterTier(), SupporterTier.none);
  });

  testWidgets('every fixed address shows and copies', (t) async {
    phone(t);
    await t.pumpWidget(framed(const DonateScreen()));
    await t.pump(const Duration(seconds: 1));
    for (final e in _addrs.entries) {
      await pick(t, _coinNames[e.key]!);
      expect(find.text(chunkAddress(e.value)), findsOneWidget, reason: e.key);
      await t.tap(find.text(l10n.donateCopyAddress));
      await t.pump(const Duration(milliseconds: 300));
      expect(_copied.last, e.value);
      expect(find.text(l10n.donateAddressCopiedClearsIn), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
    }
    expect(_copied, _addrs.values.toList());
    await drain(t);
  });

  testWidgets('reduced motion: a new coin is simply there', (t) async {
    phone(t);
    await t.pumpWidget(framed(const DonateScreen(), still: true));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text(l10n.donateSolana));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    expect(find.text(chunkAddress(_addrs['sol']!)), findsOneWidget);
    await drain(t);
  });

  testWidgets('a badge already earned still shows on me', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({
      'supporter_tier': 'patron',
      'supporter_show_self': true,
    });
    await t.pumpWidget(framed(const ProfileScreen()));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.profileSupporterBadge), findsOneWidget);
    expect(find.text(l10n.profileYouAreAThank('patron')), findsOneWidget);
    // the pill in the head and the one in its section
    expect(find.text(tierLabel(SupporterTier.patron)), findsNWidgets(2));
    expect(find.text(tierGlyph(SupporterTier.patron)), findsNWidgets(2));
    expect(engine.asked, isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 11));
  });
}
