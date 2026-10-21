// SPDX-License-Identifier: GPL-3.0-or-later
// card donations on the support screen
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

Widget _framed({
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
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

  testWidgets('the card tile is as tall as the coin tiles', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await _beats(t);
    Size tile(String name) => t.getSize(
      find
          .ancestor(
            of: find.text(name),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(tile(l10n.donateCard).height, tile(l10n.donateBitcoin).height);
    expect(tile(l10n.donateCard).height, tile(l10n.donateMonero).height);
    expect(tile(l10n.donateCard).width, tile(l10n.donateMonero).width);
  });

  testWidgets('chosen, it says where the money goes, in no grey', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await _beats(t);
    await _toCard(t);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('donate-card')),
        matching: find.text(
          'Card payments go to Marios directly until our fiscal host is set '
          'up.',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.donateCopyAddress), findsNothing);
    for (final s in [l10n.donateCardOneTime, l10n.donateCardMarios]) {
      for (final w in t.widgetList<Text>(find.text(s))) {
        expect(w.style?.color, HaloColors.text, reason: s);
      }
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
    // the box and the sheet both say it
    expect(find.text(l10n.donateCardSeesName), findsNWidgets(2));
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

  Finder tiersRow() => find.byKey(const ValueKey('donate-card-tiers'));

  testWidgets('right under the badge tiers, with the fiscal host and the '
      'badge lines', (t) async {
    _phone(t);
    await t.pumpWidget(_framed());
    await _beats(t);
    expect(tiersRow(), findsOneWidget);
    double top(Finder f) => t.getTopLeft(f).dy;
    final tier = top(find.text(l10n.donateTierGuardian));
    final row = top(tiersRow());
    expect(tier, lessThan(row));
    expect(row, lessThan(top(find.text(l10n.donateBitcoin))));
    // straight after the tiers, nothing between them
    expect(
      row - t.getBottomLeft(find.text(l10n.donateTierGuardian)).dy,
      lessThan(80),
    );
    for (final s in [
      l10n.donateNoBitcoinCard,
      l10n.donateCardMarios,
      l10n.donateCardNoBadge,
    ]) {
      expect(
        find.descendant(of: tiersRow(), matching: find.text(s)),
        findsOneWidget,
      );
    }
    expect(l10n.donateNoBitcoinCard, 'No bitcoin? Pay by card');
    expect(
      t.widget<Text>(find.text(l10n.donateNoBitcoinCard)).style?.color,
      HaloColors.text,
    );
    // and card is still one of the choices with the coins
    expect(find.text(l10n.donateCard), findsOneWidget);
  });

  for (final still in [false, true]) {
    testWidgets('the row opens the same card page after the same yes'
        '${still ? ', reduced motion' : ''}', (t) async {
      _phone(t);
      await t.pumpWidget(_framed(still: still));
      await _beats(t);
      await t.tap(find.text(l10n.donateNoBitcoinCard));
      await _beats(t);
      expect(find.text(l10n.settingsFollowBrowserNote), findsOneWidget);
      // the quick path says who sees the name too, on the sheet
      expect(find.text(l10n.donateCardSeesName), findsOneWidget);
      expect(opened, isEmpty);
      await t.tap(find.text(l10n.settingsFollowOpen));
      await _beats(t);
      expect(opened.map((u) => u.toString()), [_url]);
    });
  }

  testWidgets('a screen reader hears each card button once', (t) async {
    final sem = t.ensureSemantics();
    _phone(t);
    await t.pumpWidget(_framed());
    await _beats(t);
    expect(find.bySemanticsLabel(l10n.donateNoBitcoinCard), findsOneWidget);
    final row = t.getSemantics(find.bySemanticsLabel(l10n.donateNoBitcoinCard));
    expect(row.label, l10n.donateNoBitcoinCard);
    await _toCard(t);
    final pay = t.getSemantics(find.bySemanticsLabel(l10n.donateCardPay));
    expect(pay.label, l10n.donateCardPay);
    sem.dispose();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'at 360 dp and large text it fits in ${locale.toLanguageTag()}: '
      'the copy button, the card row and the card box',
      (t) async {
        _phone(t);
        setL10nLocale(locale);
        addTearDown(() => setL10nLocale(const Locale('en')));
        await t.pumpWidget(_framed(locale: locale, scale: 1.5));
        await _beats(t);
        expect(t.takeException(), isNull);
        // the copy label stays inside its button
        final copy = find.text(l10n.donateCopyAddress);
        await t.ensureVisible(copy);
        await _beats(t, 2);
        final button = find
            .ancestor(of: copy, matching: find.byType(Container))
            .first;
        final box = t.getRect(button);
        final label = t.getRect(copy);
        expect(box.left, lessThanOrEqualTo(label.left));
        expect(box.right, greaterThanOrEqualTo(label.right));
        expect(box.bottom, greaterThanOrEqualTo(label.bottom));
        final card = find.text(l10n.donateCard);
        await t.ensureVisible(card);
        await t.tap(card);
        await _beats(t);
        expect(t.takeException(), isNull);
      },
    );
  }

  test('every language names Marios and no amount', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      expect(l.donateCardMarios, contains('Marios'), reason: tag);
      for (final s in [
        l.donateCard,
        l.donateNoBitcoinCard,
        l.donateCardNoBadge,
        l.donateCardOneTime,
        l.donateCardMarios,
        l.donateCardSeesName,
        l.donateCardPay,
      ]) {
        expect(s.trim(), isNotEmpty, reason: tag);
        expect(s, isNot(contains(RegExp(r'[0-9€$]'))), reason: '$tag: $s');
        expect(s, isNot(contains('\u2014')), reason: '$tag: $s');
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
