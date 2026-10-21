// SPDX-License-Identifier: GPL-3.0-or-later
// the invoice ask: one more try when tor is slow, the countdown from the
// service's expiry, and the circuit started before any ask
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/badge_client.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/screens/donate_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _made =
    '{"id":"inv1","tier":"supporter","address":"bc1qtest","btc":"0.0002",'
    '"uri":"bitcoin:bc1qtest?amount=0.0002","expiresIn":3600}';

// answers the invoice asks in turn, the last answer for any after
class _Service implements HaloEngine {
  final List<String> answers;
  int asked = 0;
  // the first ask waits for this, when set
  final Completer<String>? hold;
  // every get, in order
  final gets = <String>[];
  _Service(this.answers, {this.hold});

  @override
  Future<String> torPost(String url, String body) async {
    expect(url, '$kBadgeOnion/invoice');
    expect(body, '{"tier":"supporter"}');
    final a = answers[asked < answers.length ? asked : answers.length - 1];
    asked++;
    if (asked == 1 && hold != null) return hold!.future;
    return a;
  }

  @override
  Future<String> torGetJson(String url) async {
    gets.add(url);
    return url.endsWith('/pubkey') ? '{"pubkey":"x"}' : '{"status":"pending"}';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<InvoiceAsk> _ask(List<String> answers, {int? asks}) async {
  final s = _Service(answers);
  useEngineForTest(s);
  final got = await createInvoice('supporter');
  if (asks != null) expect(s.asked, asks);
  return got;
}

Widget _framed(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> _openSupport(WidgetTester t, _Service s) async {
  t.view.physicalSize = const Size(2000, 3200);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  appState.sendModeForTest = 'private';
  useEngineForTest(s);
  await t.pumpWidget(_framed(const DonateScreen()));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _payWithBitcoin(WidgetTester t, _Service s) async {
  await _openSupport(t, s);
  await t.ensureVisible(find.text(l10n.donatePayWithBitcoin));
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(find.text(l10n.donatePayWithBitcoin));
  await t.pump(const Duration(seconds: 1));
}

// the whole minutes the invoice line says are left
int _minutesLeft(WidgetTester t) {
  final head = l10n.donateSendExactlyThisAmount('');
  final line = t.widget<Text>(find.textContaining(head)).data!;
  return int.parse(line.substring(head.length).split(':').first);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
  });

  group('the ask', () {
    test('a cold circuit that gives up is asked once more', () async {
      final got = await _ask([
        'error: post: context deadline exceeded',
        _made,
      ], asks: 2);
      expect(got.invoice?.address, 'bc1qtest');
      expect(got.failure, isNull);
    });

    test('tor failing twice reads as slow, not as the service', () async {
      final got = await _ask(['error: tor timeout'], asks: 2);
      expect(got.invoice, isNull);
      expect(got.failure, InvoiceFailure.slow);
    });

    test('a hiccup behind the service is asked once more', () async {
      final got = await _ask(['error: status 502: upstream', _made], asks: 2);
      expect(got.invoice, isNotNull);
    });

    test('a busy or refusing service is not asked again', () async {
      for (final no in ['error: status 429: busy', 'error: status 400: x']) {
        final got = await _ask([no, _made], asks: 1);
        expect(got.invoice, isNull);
        expect(got.failure, InvoiceFailure.service);
      }
    });

    test('the countdown is what the service says', () async {
      expect((await _ask([_made])).invoice!.secondsLeft, 3600);
      // an old service says nothing: it kept invoices a quarter hour
      final old = _made.replaceFirst(',"expiresIn":3600', '');
      expect((await _ask([old])).invoice!.secondsLeft, 15 * 60);
      final odd = _made.replaceFirst('3600', '999999');
      expect((await _ask([odd])).invoice!.secondsLeft, 3 * 60 * 60);
    });
  });

  group('the screen', () {
    testWidgets('tor that never gets through says tor was slow', (t) async {
      final s = _Service(['error: post: context deadline exceeded']);
      await _payWithBitcoin(t, s);
      await t.pump(const Duration(seconds: 1));
      expect(s.asked, 2);
      expect(find.text(l10n.donateTorWasSlowTo), findsOneWidget);
      expect(
        find.text(l10n.donateThePaymentServiceIsHavingTrouble),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    }, skip: !kBadgeTiersShown);

    testWidgets(
      'a service that says no says the service has trouble',
      (t) async {
        final s = _Service(['error: status 429: busy']);
        await _payWithBitcoin(t, s);
        await t.pump(const Duration(seconds: 1));
        expect(
          find.text(l10n.donateThePaymentServiceIsHavingTrouble),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      },
      skip: !kBadgeTiersShown,
    );

    testWidgets(
      'a second ask that works shows the invoice for an hour',
      (t) async {
        final s = _Service(['error: post: context deadline exceeded', _made]);
        await _payWithBitcoin(t, s);
        await t.pump(const Duration(seconds: 1));
        expect(s.asked, 2);
        expect(_minutesLeft(t), 59);
        // still open well past the old quarter hour
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(minutes: 1));
        }
        expect(_minutesLeft(t), 39);
        expect(find.text(l10n.donateThisInvoiceExpired), findsNothing);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 61));
      },
      skip: !kBadgeTiersShown,
    );
  });

  group('walking away', () {
    testWidgets('leaving during the first ask makes no second one', (t) async {
      final hold = Completer<String>();
      final s = _Service([_made], hold: hold);
      await _payWithBitcoin(t, s);
      await t.pump(const Duration(seconds: 1));
      expect(s.asked, 1);
      Navigator.of(
        t.element(find.text(l10n.donateReachingThePaymentService)),
      ).pop();
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.text(l10n.donateReachingThePaymentService), findsNothing);
      hold.complete('error: post: context deadline exceeded');
      await t.pump(const Duration(seconds: 1));
      expect(s.asked, 1);
      await t.pumpWidget(const SizedBox());
    }, skip: !kBadgeTiersShown);

    testWidgets('"use the address instead" makes no second ask', (t) async {
      final hold = Completer<String>();
      final s = _Service([_made], hold: hold);
      await _payWithBitcoin(t, s);
      await t.pump(const Duration(seconds: 21));
      await t.tap(find.text(l10n.donateUseTheAddressInstead));
      await t.pump(const Duration(seconds: 1));
      hold.complete('error: post: context deadline exceeded');
      await t.pump(const Duration(seconds: 1));
      expect(s.asked, 1);
      expect(find.text(l10n.donateTorWasSlowTo), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }, skip: !kBadgeTiersShown);
  });

  group('picking bitcoin', () {
    tearDown(() {
      final e = HaloDb();
      useDatabasesForTest(e, Session(e));
    });

    Future<void> tapBitcoin(WidgetTester t) async {
      final chip = find.text(l10n.donateBitcoin).first;
      await t.ensureVisible(chip);
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(chip);
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('starts the circuit once and makes no invoice', (t) async {
      final s = _Service([_made]);
      await _openSupport(t, s);
      expect(s.gets, isEmpty);
      await tapBitcoin(t);
      await t.tap(find.text(l10n.donateMonero).first);
      await t.pump(const Duration(milliseconds: 300));
      await tapBitcoin(t);
      expect(s.gets, ['$kBadgeOnion/pubkey']);
      expect(s.asked, 0);
      await t.pumpWidget(const SizedBox());
    }, skip: !kBadgeTiersShown);

    testWidgets(
      'an amount picked starts it too, once, with no invoice',
      (t) async {
        final s = _Service([_made]);
        await _openSupport(t, s);
        for (final tier in [l10n.donateTierPatron, l10n.donateTierGuardian]) {
          final card = find.text(tier).first;
          await t.ensureVisible(card);
          await t.pump(const Duration(milliseconds: 100));
          await t.tap(card);
          await t.pump(const Duration(milliseconds: 300));
        }
        expect(s.gets, ['$kBadgeOnion/pubkey']);
        // and bitcoin after it adds nothing: once a visit
        await tapBitcoin(t);
        expect(s.gets, ['$kBadgeOnion/pubkey']);
        expect(s.asked, 0);
        await t.pumpWidget(const SizedBox());
      },
      skip: !kBadgeTiersShown,
    );

    testWidgets('a decoy or a route without the onion asks nothing', (t) async {
      final s = _Service([_made]);
      final d = HaloDb(HaloContainer.decoy);
      useDatabasesForTest(HaloDb(), Session(d));
      await _openSupport(t, s);
      await tapBitcoin(t);
      await t.tap(find.text(l10n.donateTierPatron).first);
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpWidget(const SizedBox());
      useDatabasesForTest(HaloDb(), Session(HaloDb()));
      for (final mode in ['balanced', 'fast']) {
        await _openSupport(t, s);
        appState.sendModeForTest = mode;
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(_framed(const DonateScreen()));
        await t.pump(const Duration(seconds: 1));
        await tapBitcoin(t);
        await t.tap(find.text(l10n.donateTierPatron).first);
        await t.pump(const Duration(milliseconds: 300));
        await t.pumpWidget(const SizedBox());
      }
      expect(s.gets, isEmpty);
      expect(s.asked, 0);
    }, skip: !kBadgeTiersShown);
  });
}
