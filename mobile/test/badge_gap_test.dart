// SPDX-License-Identifier: GPL-3.0-or-later
// every invoice takes a fresh bitcoin address: none is made before the
// donor asks, this phone's open one is asked for again within its hour, and
// a busy service points to the card
import 'dart:convert';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/badge_client.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute;
import 'package:kryfo/open_outside.dart';
import 'package:kryfo/screens/donate_screen.dart';
import 'package:kryfo/supporter.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _made(String id, {String tier = 'supporter', int left = 3600}) =>
    '{"id":"$id","tier":"$tier","address":"bc1qtest","btc":"0.0002",'
    '"uri":"bitcoin:bc1qtest?amount=0.0002","expiresIn":$left}';

// answers the invoice asks in turn, the last answer for any after
class _Service implements HaloEngine {
  final List<String> answers;
  final bodies = <Map<String, dynamic>>[];
  final receipts = <String, String>{};
  _Service(this.answers);

  int get asked => bodies.length;

  @override
  Future<String> torPost(String url, String body) async {
    expect(url, '$kBadgeOnion/invoice');
    bodies.add(jsonDecode(body) as Map<String, dynamic>);
    final n = bodies.length - 1;
    return answers[n < answers.length ? n : answers.length - 1];
  }

  @override
  Future<String> torGetJson(String url) async {
    if (url.endsWith('/pubkey')) return '{"pubkey":"x"}';
    final id = Uri.parse(url).queryParameters['id'] ?? '';
    return receipts[id] ?? '{"status":"pending"}';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _framed({Locale locale = const Locale('en'), double scale = 1}) =>
    MaterialApp(
      locale: locale,
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const DonateScreen(),
    );

void _phone(WidgetTester t, {Size dp = const Size(1000, 1600)}) {
  t.view.physicalSize = dp * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _open(
  WidgetTester t,
  _Service s, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  appState.sendModeForTest = 'private';
  useEngineForTest(s);
  await t.pumpWidget(_framed(locale: locale, scale: scale));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _toReview(WidgetTester t) async {
  final pay = find.text(l10n.donatePayWithBitcoin);
  await t.ensureVisible(pay);
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(pay);
  // a new route's first frame is offstage
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _showAddress(WidgetTester t) async {
  final show = find.text(l10n.donateShowTheAddress);
  await t.ensureVisible(show);
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(show);
  await t.pump(const Duration(seconds: 1));
}

Future<void> _back(WidgetTester t) async {
  Navigator.of(t.element(find.text(l10n.donateBitcoin).last)).pop();
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _beats(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 61));
}

String? _stored(SharedPreferences p) => p.getString('badge_open_invoice');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
  });

  group('no address before the tap', () {
    testWidgets('support, the tiers and the review make no invoice', (t) async {
      _phone(t);
      final s = _Service([_made('inv1', tier: 'patron')]);
      await _open(t, s);
      for (final tier in [
        l10n.donateTierGuardian,
        l10n.donateTierSupporter,
        l10n.donateTierPatron,
      ]) {
        final card = find.text(tier).first;
        await t.ensureVisible(card);
        await t.tap(card);
        await t.pump(const Duration(milliseconds: 300));
      }
      await _toReview(t);
      // the tier, the amount and what the badge gives, and still nothing asked
      expect(find.text(l10n.donateTierPatron), findsOneWidget);
      expect(find.text(l10n.donateReviewAmount(dollars(50))), findsOneWidget);
      for (final line in [
        l10n.donateWhatTheBadgeGives,
        l10n.donateGivesMark,
        l10n.donateGivesReceipt,
        l10n.donateGivesFree,
        l10n.donateAddressOnTap,
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      await t.pump(const Duration(minutes: 2));
      expect(s.asked, 0);
      expect(find.textContaining('bc1qtest'), findsNothing);
      await _showAddress(t);
      expect(s.bodies, [
        {'tier': 'patron'},
      ]);
      expect(
        find.textContaining(l10n.donateSendExactlyThisAmount('')),
        findsOneWidget,
      );
      await _drain(t);
    });

    testWidgets('leaving the review asks nothing', (t) async {
      _phone(t);
      final s = _Service([_made('inv1')]);
      await _open(t, s);
      for (var i = 0; i < 3; i++) {
        await _toReview(t);
        expect(find.text(l10n.donateShowTheAddress), findsOneWidget);
        await _back(t);
      }
      await t.pump(const Duration(minutes: 1));
      expect(s.asked, 0);
      expect(await loadOpenInvoices(), isEmpty);
      await _drain(t);
    });
  });

  group('the same invoice within its hour', () {
    testWidgets('coming back asks for the open one by its id', (t) async {
      _phone(t);
      final s = _Service([_made('inv1')]);
      await _open(t, s);
      await _toReview(t);
      await _showAddress(t);
      // a first address is not called the earlier one
      expect(find.byKey(const ValueKey('same-address')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      final saved = (await loadOpenInvoices()).single;
      expect(saved.id, 'inv1');
      expect(saved.tier, SupporterTier.supporter);
      final left = saved.expiresAt!.difference(DateTime.now());
      expect(left.inMinutes, inInclusiveRange(58, 60));
      await _back(t);
      await _toReview(t);
      await _showAddress(t);
      // the second ask names this phone's invoice and nothing else
      expect(s.bodies, [
        {'tier': 'supporter'},
        {'tier': 'supporter', 'again': 'inv1'},
      ]);
      expect(_stored(prefs)!.split(';'), hasLength(1));
      // the same address handed back says so, so nobody sends twice
      expect(find.text(l10n.donateSameAddressAgain), findsOneWidget);
      await _drain(t);
    });

    testWidgets('one past its hour, or for another tier, is not sent', (
      t,
    ) async {
      final now = DateTime.now();
      final past = now.subtract(const Duration(minutes: 1));
      final later = now.add(const Duration(minutes: 30));
      SharedPreferences.setMockInitialValues({
        'badge_open_invoice':
            'inv0|supporter|${past.millisecondsSinceEpoch};'
            'inv9|guardian|${later.millisecondsSinceEpoch};'
            'inv8|supporter',
      });
      _phone(t);
      final s = _Service([_made('inv2')]);
      await _open(t, s);
      await _toReview(t);
      await _showAddress(t);
      expect(s.bodies, [
        {'tier': 'supporter'},
      ]);
      // the others stay, so a late payment to them is still honoured
      final ids = (await loadOpenInvoices()).map((i) => i.id);
      expect(ids, containsAll(['inv0', 'inv9', 'inv8', 'inv2']));
      await _drain(t);
    });

    testWidgets('a new one in its place is kept beside the old', (t) async {
      final later = DateTime.now().add(const Duration(minutes: 40));
      SharedPreferences.setMockInitialValues({
        'badge_open_invoice': 'inv1|supporter|${later.millisecondsSinceEpoch}',
      });
      _phone(t);
      final s = _Service([_made('inv3')]);
      await _open(t, s);
      await _toReview(t);
      await _showAddress(t);
      expect(s.bodies.single['again'], 'inv1');
      expect((await loadOpenInvoices()).map((i) => i.id), ['inv1', 'inv3']);
      // a different invoice came back: it is a new address, said as nothing
      expect(find.byKey(const ValueKey('same-address')), findsNothing);
      expect(await reusableInvoice(SupporterTier.supporter), 'inv3');
      await _drain(t);
    });
  });

  group('busy', () {
    late List<Uri> opened;
    setUp(() {
      opened = [];
      openOutsideForTest = (u) async {
        opened.add(u);
        return true;
      };
    });
    tearDown(() => openOutsideForTest = null);

    testWidgets('says so calmly, with the card right there', (t) async {
      _phone(t);
      final s = _Service(['error: status 429: busy, try again later']);
      await _open(t, s);
      await _toReview(t);
      await _showAddress(t);
      // a busy service is not asked twice in a row
      expect(s.asked, 1);
      expect(find.text(l10n.donateBitcoinBusy), findsOneWidget);
      expect(
        find.text(l10n.donateThePaymentServiceIsHavingTrouble),
        findsNothing,
      );
      // the badge waits, the donation does not: the fixed address is here
      expect(find.text(l10n.donateBusyPlainAddress), findsOneWidget);
      expect(find.textContaining('bc1q dewm'), findsOneWidget);
      expect(find.text(l10n.donateCopyAddress), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('busy-card')));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byKey(const ValueKey('busy-card')));
      await _beats(t);
      // the card page is named first, like every card path
      expect(find.text(l10n.donateCardSeesName), findsWidgets);
      await t.tap(find.text(l10n.settingsFollowOpen));
      await _beats(t);
      expect(opened.single, Uri.parse(kCardUrl));
      // try again asks once more
      await t.ensureVisible(find.text(l10n.commonTryAgain));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text(l10n.commonTryAgain));
      await t.pump(const Duration(seconds: 1));
      expect(s.asked, 2);
      await _drain(t);
    });

    test('every language has the busy line and the review', () {
      final en = lookupAppLocalizations(const Locale('en'));
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        final tag = locale.toLanguageTag();
        final words = [
          l.donateBitcoinBusy,
          l.donateShowTheAddress,
          l.donateWhatTheBadgeGives,
          l.donateGivesMark,
          l.donateGivesReceipt,
          l.donateGivesFree,
          l.donateAddressOnTap,
        ];
        for (final w in words) {
          expect(w.trim(), isNotEmpty, reason: tag);
          expect(w, isNot(contains('\u2014')), reason: tag);
        }
        expect(l.donateReviewAmount(r'$20'), contains(r'$20'), reason: tag);
        if (locale.languageCode != 'en') {
          expect(l.donateBitcoinBusy, isNot(en.donateBitcoinBusy), reason: tag);
          expect(l.donateGivesMark, isNot(en.donateGivesMark), reason: tag);
        }
      }
      expect(AppLocalizations.supportedLocales, hasLength(16));
    });
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('the review and the busy page fit at 360 dp and large text in '
        '${locale.toLanguageTag()}', (t) async {
      _phone(t, dp: const Size(360, 720));
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      final s = _Service(['error: status 429: busy']);
      await _open(t, s, locale: locale, scale: 2);
      await _toReview(t);
      expect(t.takeException(), isNull);
      final show = find.text(l10n.donateShowTheAddress);
      await t.ensureVisible(show);
      await t.pump(const Duration(milliseconds: 100));
      // right to left where the language reads that way
      final rtl = const {'ar', 'fa'}.contains(locale.languageCode);
      expect(
        Directionality.of(t.element(show)),
        rtl ? TextDirection.rtl : TextDirection.ltr,
      );
      // the button holds its whole label
      final button = find.ancestor(
        of: show,
        matching: find.byType(AnimatedContainer),
      );
      final box = t.getRect(button.first);
      final label = t.getRect(show);
      expect(box.left, lessThanOrEqualTo(label.left));
      expect(box.right, greaterThanOrEqualTo(label.right));
      await _showAddress(t);
      expect(find.text(l10n.donateBitcoinBusy), findsOneWidget);
      await t.ensureVisible(find.text(l10n.donateCardPay));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      await _drain(t);
    });
  }

  group('settling what this phone kept', () {
    late ed.KeyPair key;
    late _Service s;
    setUp(() {
      key = ed.generateKey();
      useBadgeKeyForTest(base64Url.encode(key.publicKey.bytes));
      s = _Service([_made('x')]);
      useEngineForTest(s);
    });
    tearDown(() => useBadgeKeyForTest(null));

    String paid(String id, String tier) {
      final payload = 'halo-badge|v1|$id|$tier';
      final sig = ed.sign(
        key.privateKey,
        Uint8List.fromList(utf8.encode(payload)),
      );
      return jsonEncode({
        'status': 'paid',
        'id': id,
        'tier': tier,
        'payload': payload,
        'sig': base64Url.encode(sig),
      });
    }

    test('a receipt for another invoice is refused', () async {
      s.receipts['inv1'] = paid('inv9', 'guardian');
      expect((await fetchReceipt('inv1')).state, ReceiptState.error);
      SharedPreferences.setMockInitialValues({
        'badge_open_invoice': 'inv1|guardian',
      });
      expect(await settleOpenInvoice(), isNull);
      expect(await loadSupporterTier(), SupporterTier.none);
      expect((await loadOpenInvoices()).single.id, 'inv1');
    });

    test('the tier is the one the signed words name', () async {
      // the answer around the payload says guardian, the payload patron
      s.receipts['inv2'] = paid(
        'inv2',
        'patron',
      ).replaceFirst('"tier":"patron"', '"tier":"guardian"');
      final r = await fetchReceipt('inv2');
      expect(r.state, ReceiptState.paid);
      expect(r.tier, 'patron');
      // and a record that says more than was paid grants only what was
      SharedPreferences.setMockInitialValues({
        'badge_open_invoice': 'inv2|guardian',
      });
      expect(await settleOpenInvoice(), SupporterTier.patron);
      expect(await loadSupporterTier(), SupporterTier.patron);
    });

    test('a payload that is not one is refused', () async {
      for (final p in [
        'halo-badge|v2|inv3|patron',
        'halo-badge|v1|inv3|emperor',
        'halo-badge|v1|inv3',
        'other|v1|inv3|patron',
      ]) {
        expect(signedReceipt(p), isNull, reason: p);
      }
      expect(signedReceipt('halo-badge|v1|inv3|patron'), (
        id: 'inv3',
        tier: 'patron',
      ));
    });

    testWidgets('the live check grants what the receipt proves', (t) async {
      _phone(t);
      final live = _Service([_made('inv1')]);
      live.receipts['inv1'] = paid('inv1', 'patron');
      await _open(t, live);
      await _toReview(t);
      await _showAddress(t);
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(await loadSupporterTier(), SupporterTier.patron);
      expect(
        find.text(l10n.donateVerifiedOnChainYou('patron')),
        findsOneWidget,
      );
      await _drain(t);
    });

    testWidgets('a smaller payment says the higher badge stays', (t) async {
      SharedPreferences.setMockInitialValues({'supporter_tier': 'guardian'});
      _phone(t);
      final live = _Service([_made('inv1')]);
      live.receipts['inv1'] = paid('inv1', 'patron');
      await _open(t, live);
      await _toReview(t);
      await _showAddress(t);
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(await loadSupporterTier(), SupporterTier.guardian);
      expect(
        find.text(l10n.donateVerifiedBadgeStays('guardian')),
        findsOneWidget,
      );
      expect(find.text(l10n.donateVerifiedOnChainYou('patron')), findsNothing);
      await _drain(t);
    });

    test('every language thanks and keeps the badge', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l = lookupAppLocalizations(locale);
        for (final k in ['supporter', 'patron', 'guardian']) {
          final w = l.donateVerifiedBadgeStays(k);
          expect(w, isNot(contains('\u2014')), reason: locale.toLanguageTag());
          expect(w, isNot(l.donateVerifiedOnChainYou(k)));
        }
      }
    });

    test(
      'each is asked about: paid granted, gone dropped, open kept',
      () async {
        SharedPreferences.setMockInitialValues({
          'badge_open_invoice': 'inv1|supporter;inv2|patron|1;inv3|guardian',
        });
        s.receipts['inv1'] = '{"status":"expired"}';
        s.receipts['inv2'] = paid('inv2', 'patron');
        expect(await settleOpenInvoice(), SupporterTier.patron);
        expect(await loadSupporterTier(), SupporterTier.patron);
        expect((await loadOpenInvoices()).map((i) => i.id), ['inv3']);
      },
    );

    test(
      'the highest paid one wins, and an older one never lowers a badge',
      () async {
        SharedPreferences.setMockInitialValues({
          'badge_open_invoice': 'inv1|guardian;inv2|supporter',
        });
        s.receipts['inv1'] = paid('inv1', 'guardian');
        s.receipts['inv2'] = paid('inv2', 'supporter');
        expect(await settleOpenInvoice(), SupporterTier.guardian);
        SharedPreferences.setMockInitialValues({
          'supporter_tier': 'guardian',
          'badge_open_invoice': 'inv2|supporter',
        });
        expect(await settleOpenInvoice(), isNull);
        expect(await loadSupporterTier(), SupporterTier.guardian);
        expect(await loadOpenInvoices(), isEmpty);
      },
    );
  });

  group('the record on this phone', () {
    test('an older version\'s line still reads and settles', () async {
      SharedPreferences.setMockInitialValues({
        'badge_open_invoice': 'inv0|patron',
      });
      final list = await loadOpenInvoices();
      expect(list.single.id, 'inv0');
      expect(list.single.expiresAt, isNull);
      // no end known: never handed back, only settled
      expect(await reusableInvoice(SupporterTier.patron), isNull);
    });

    test('a decoy keeps its own', () async {
      final later = DateTime.now().add(const Duration(minutes: 30));
      await saveOpenInvoice(
        'inv1',
        SupporterTier.supporter,
        HaloContainer.decoy,
        later,
      );
      expect(await reusableInvoice(SupporterTier.supporter), isNull);
      expect(
        await reusableInvoice(SupporterTier.supporter, HaloContainer.decoy),
        'inv1',
      );
    });

    test('only the newest few are kept', () async {
      for (var i = 0; i < 9; i++) {
        await saveOpenInvoice('inv$i', SupporterTier.supporter);
      }
      final ids = (await loadOpenInvoices()).map((i) => i.id).toList();
      expect(ids, ['inv3', 'inv4', 'inv5', 'inv6', 'inv7', 'inv8']);
      await clearOpenInvoice(HaloContainer.everyday, 'inv5');
      expect(
        (await loadOpenInvoices()).map((i) => i.id),
        isNot(contains('inv5')),
      );
    });

    test('the time left is read from the service at the ask', () async {
      final at = DateTime(2026, 1, 1, 12);
      await saveOpenInvoice(
        'inv1',
        SupporterTier.guardian,
        HaloContainer.everyday,
        at.add(const Duration(minutes: 60)),
      );
      expect(
        await reusableInvoice(
          SupporterTier.guardian,
          HaloContainer.everyday,
          at.add(const Duration(minutes: 59)),
        ),
        'inv1',
      );
      expect(
        await reusableInvoice(
          SupporterTier.guardian,
          HaloContainer.everyday,
          at.add(const Duration(minutes: 61)),
        ),
        isNull,
      );
    });
  });
}
