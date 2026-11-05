// SPDX-License-Identifier: GPL-3.0-or-later
// the play build's tip screen against a fake google play: its prices, the
// amount picked going to the payment sheet, the thank you once play says it
// went through, what is bought already, a pending payment, no play at all,
// still motion, and every language without a donation word or an overflow
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/tip_screen.dart';
import 'package:kryfo/supporter.dart';
import 'package:kryfo/tips/tip_billing.dart';
import 'package:kryfo/tips/tip_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;
import 'tip_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeTipBilling play;
  late TipJar jar;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    play = FakeTipBilling();
    jar = TipJar(billing: play, whenOpen: (a) => a());
  });

  Future<void> open(
    WidgetTester t, {
    bool still = false,
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    phone(t);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(
          t.view,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: app(
          TipScreen(jar: jar),
          still: still,
          locale: locale,
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  testWidgets('it says what a tip gives and who takes the payment', (t) async {
    await open(t);
    expect(find.text(l10n.tipsTitle), findsOneWidget);
    expect(find.text(l10n.tipsBadgeOnly), findsOneWidget);
    expect(find.text(l10n.tipsThroughPlay), findsOneWidget);
    expect(find.text(l10n.tipsBadgeStays), findsOneWidget);
    for (final p in ['€4.99', '€9.99', '€24.99']) {
      expect(find.text(p), findsOneWidget);
    }
    expect(find.text(l10n.donateTierGuardian), findsOneWidget);
    await close(t);
  });

  testWidgets('the amount picked goes to play, the thanks follow', (t) async {
    await open(t);
    await t.tap(find.text('€24.99'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('tips-leave')));
    await t.pump();
    expect(play.bought, ['tip_guardian']);
    // play holds it for the account from now on
    play.owns = [bought('tip_guardian', token: 'g')];
    play.sheet(TipCode.ok, play.owns);
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(find.text(l10n.tipsThanks), findsOneWidget);
    expect(find.text(l10n.tipsGranted('guardian')), findsOneWidget);
    expect(await loadSupporterTier(), SupporterTier.guardian);
    expect(play.acked, ['g']);
    await t.tap(find.byKey(const ValueKey('tips-show')));
    await t.pump();
    expect(await loadShowBadgeSelf(), isTrue);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    // back on the tip screen, the amount is now theirs
    expect(find.text(l10n.tipsThanks), findsNothing);
    expect(find.text(l10n.tipsYours), findsOneWidget);
    await close(t);
  });

  testWidgets('a closed sheet leaves the screen as it was', (t) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('tips-leave')));
    await t.pump();
    expect(play.bought, ['tip_supporter']);
    play.sheet(TipCode.canceled);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.tipsThanks), findsNothing);
    expect(await loadSupporterTier(), SupporterTier.none);
    await close(t);
  });

  testWidgets('what is bought shows as theirs and cannot be picked', (t) async {
    play.owns = [bought('tip_supporter', acked: true)];
    await open(t);
    expect(find.text(l10n.tipsYours), findsOneWidget);
    expect(find.text('€4.99'), findsNothing);
    await t.tap(find.text(l10n.tipsYours));
    await t.tap(find.byKey(const ValueKey('tips-leave')));
    await t.pump();
    // the first amount still open was picked, not the bought one
    expect(play.bought, ['tip_patron']);
    await close(t);
  });

  testWidgets('a pending payment says it waits at google play', (t) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('tips-leave')));
    await t.pump();
    play.sheet(TipCode.ok, [bought('tip_supporter', state: TipState.pending)]);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.tipsPending), findsOneWidget);
    expect(await loadSupporterTier(), SupporterTier.none);
    expect(play.acked, isEmpty);
    await close(t);
  });

  testWidgets('restore brings the badge back and says so', (t) async {
    play.owns = [bought('tip_patron', acked: true)];
    await open(t);
    expect(await loadSupporterTier(), SupporterTier.none);
    await t.ensureVisible(find.byKey(const ValueKey('tips-restore')));
    await t.tap(find.byKey(const ValueKey('tips-restore')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(await loadSupporterTier(), SupporterTier.patron);
    expect(find.text(l10n.tipsRestored('patron')), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await close(t);
  });

  testWidgets('restore with nothing bought says so', (t) async {
    await open(t);
    await t.ensureVisible(find.byKey(const ValueKey('tips-restore')));
    await t.tap(find.byKey(const ValueKey('tips-restore')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.tipsNothingToRestore), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await close(t);
  });

  testWidgets('no play billing: a calm line and nothing to buy', (t) async {
    play.productsCode = TipCode.unavailable;
    await open(t);
    expect(find.text(l10n.tipsUnavailable), findsOneWidget);
    expect(find.byKey(const ValueKey('tips-leave')), findsNothing);
    await close(t);
  });

  testWidgets('no products made yet: they open soon', (t) async {
    play.items = const [];
    await open(t);
    expect(find.text(l10n.tipsSoon), findsOneWidget);
    expect(find.byKey(const ValueKey('tips-leave')), findsNothing);
    await close(t);
  });

  testWidgets('still motion: it settles at once, prices loading too', (
    t,
  ) async {
    await open(t, still: true);
    await t.pumpAndSettle();
    expect(find.text('€9.99'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tips-leave')));
    await t.pump();
    play.sheet(TipCode.ok, [bought('tip_supporter')]);
    await t.pumpAndSettle();
    expect(find.text(l10n.tipsThanks), findsOneWidget);
    await close(t);
  });

  for (final lang in ['de', 'ar', 'hi', 'ru']) {
    testWidgets('it fits in $lang at a large font', (t) async {
      setL10nLocale(Locale(lang));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await open(t, locale: Locale(lang), scale: 2.0);
      expect(t.takeException(), isNull);
      expect(find.text(l10n.tipsBadgeOnly), findsOneWidget);
      await close(t);
    });
  }

  // play's payments policy and the decision: a tip, never a donation, and
  // no language copies the english
  test('no tip word is a donation, and none is english', () {
    final banned = {
      'en': r'donat',
      'de': r'spende',
      'es': r'donaci|donativ|donar',
      'fr': r'\bdons?\b|donation',
      'it': r'donazion|donar',
      'pt': r'doaç|doar\b',
      'ru': r'пожертв|донат',
      'uk': r'пожертв|донат',
      'pl': r'darowizn|datek|donac',
      'tr': r'bağış',
      'id': r'donasi',
      'vi': r'quyên góp',
      'zh': r'捐',
      'zh_Hant': r'捐',
      'ar': r'تبرع|تبرّع',
      'fa': r'اهدا|کمک مالی',
      'hi': r'दान',
    };
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = [
      for (final k in en.keys)
        if (k.startsWith('tips')) k,
    ];
    expect(keys, hasLength(21));
    final files = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'app_\w+\.arb$').hasMatch(f.path))
        .toList();
    expect(files, hasLength(17));
    for (final f in files) {
      final lang = RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)![1]!;
      final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final bad = RegExp(banned[lang]!, caseSensitive: false);
      for (final k in keys) {
        final v = d[k] as String?;
        expect(v, isNotNull, reason: '$lang $k');
        expect(bad.hasMatch(v!), isFalse, reason: '$lang $k: $v');
        if (lang != 'en') {
          expect(v, isNot(en[k]), reason: '$lang $k is the english');
        }
      }
      // play shows its own prices: no amount or currency of ours, in the
      // tip jar's words or the tier names on its cards
      for (final k in [
        ...keys,
        'donateTierSupporter',
        'donateTierPatron',
        'donateTierGuardian',
      ]) {
        final v = d[k] as String;
        expect(amount.hasMatch(v), isFalse, reason: '$lang $k: $v');
      }
    }
  });
}

// an amount or a currency, in any script's digits
final amount = RegExp(
  r'\p{Nd}|[$€£¥₹₽]|\b(usd|eur|sats?|btc)\b',
  unicode: true,
  caseSensitive: false,
);
