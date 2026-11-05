// SPDX-License-Identifier: GPL-3.0-or-later
// the tip jar against a fake google play: a badge is granted on the phone
// before play hears it was delivered, never for a payment still pending,
// never lower than the one held, and nothing of the purchase is kept
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/supporter.dart';
import 'package:kryfo/tips/tip_billing.dart';
import 'package:kryfo/tips/tip_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tip_fakes.dart';

void main() {
  late FakeTipBilling play;
  late TipJar jar;
  var box = HaloContainer.everyday;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    play = FakeTipBilling();
    box = HaloContainer.everyday;
    jar = TipJar(billing: play, container: () => box, whenOpen: (a) => a());
  });

  Future<List<TipEvent>> heard(Future<void> Function() act) async {
    final got = <TipEvent>[];
    final sub = jar.events.listen(got.add);
    await act();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return got;
  }

  test('each amount is its own product with its badge', () {
    expect(kTipProducts.values.toSet(), {
      SupporterTier.supporter,
      SupporterTier.patron,
      SupporterTier.guardian,
    });
    for (final t in kTipProducts.values) {
      expect(kTipProducts[tipProductFor(t)], t);
    }
    expect(tipProductFor(SupporterTier.none), isNull);
  });

  test('a paid tip grants its badge, then play hears of it', () async {
    jar.listen();
    final got = await heard(
      () async => play.sheet(TipCode.ok, [bought('tip_patron', token: 't1')]),
    );
    expect(await loadSupporterTier(), SupporterTier.patron);
    expect(play.acked, ['t1']);
    expect(got.single.outcome, TipOutcome.granted);
    expect(got.single.tier, SupporterTier.patron);
  });

  test('a pending payment grants nothing and is not acknowledged', () async {
    jar.listen();
    final got = await heard(
      () async => play.sheet(TipCode.ok, [
        bought('tip_guardian', state: TipState.pending),
      ]),
    );
    expect(await loadSupporterTier(), SupporterTier.none);
    expect(play.acked, isEmpty);
    expect(got.single.outcome, TipOutcome.pending);
  });

  test('once it goes through, the next look grants it', () async {
    play.owns = [bought('tip_guardian', token: 'g', state: TipState.pending)];
    expect(await jar.settle(always: true), isNotNull);
    expect(await loadSupporterTier(), SupporterTier.none);
    play.owns = [bought('tip_guardian', token: 'g')];
    final e = await jar.settle(always: true);
    expect(e?.outcome, TipOutcome.granted);
    expect(await loadSupporterTier(), SupporterTier.guardian);
    expect(play.acked, ['g']);
    // the look after finds nothing new
    expect(await jar.settle(always: true), isNull);
    expect(play.acked, ['g']);
  });

  test('play is asked at the front only while a tip is owed', () async {
    play.owns = [bought('tip_patron', acked: true)];
    expect(await jar.settle(), isNull);
    expect(play.ownedAsks, 0);
    // a sheet opened and the app stopped on it: the next return asks
    await jar.buy(SupporterTier.guardian);
    play.owns = [
      bought('tip_patron', acked: true),
      bought('tip_guardian', token: 'g'),
    ];
    final e = await jar.settle();
    expect(e?.outcome, TipOutcome.granted);
    expect(play.ownedAsks, 1);
    expect(play.acked, ['g']);
    // settled: the returns after ask nothing again
    expect(await jar.settle(), isNull);
    expect(play.ownedAsks, 1);
  });

  test('a pending tip stays owed until it goes through', () async {
    await jar.buy(SupporterTier.supporter);
    play.owns = [bought('tip_supporter', state: TipState.pending)];
    expect((await jar.settle())?.outcome, TipOutcome.pending);
    expect((await jar.settle())?.outcome, TipOutcome.pending);
    play.owns = [bought('tip_supporter')];
    expect((await jar.settle())?.outcome, TipOutcome.granted);
    expect(await jar.settle(), isNull);
    expect(play.ownedAsks, 3);
  });

  test('a smaller tip never lowers a badge', () async {
    await saveSupporterTier(SupporterTier.guardian);
    jar.listen();
    final got = await heard(
      () async => play.sheet(TipCode.ok, [bought('tip_supporter')]),
    );
    expect(await loadSupporterTier(), SupporterTier.guardian);
    expect(got.single.outcome, TipOutcome.kept);
    expect(got.single.tier, SupporterTier.guardian);
    // still acknowledged: the money was taken, and play refunds otherwise
    expect(play.acked, ['tok']);
  });

  test('a product we do not sell gives nothing', () async {
    jar.listen();
    final got = await heard(
      () async => play.sheet(TipCode.ok, [bought('something_else')]),
    );
    expect(await loadSupporterTier(), SupporterTier.none);
    expect(play.acked, isEmpty);
    expect(got, isEmpty);
  });

  test('a closed sheet and a broken one say so and grant nothing', () async {
    jar.listen();
    final got = await heard(() async {
      play.sheet(TipCode.canceled);
      play.sheet(TipCode.failed);
      play.sheet(TipCode.unavailable);
    });
    expect(got.map((e) => e.outcome), [
      TipOutcome.canceled,
      TipOutcome.failed,
      TipOutcome.unavailable,
    ]);
    expect(await loadSupporterTier(), SupporterTier.none);
  });

  test('an amount bought before comes back instead', () async {
    play.owns = [bought('tip_patron', acked: true)];
    jar.listen();
    final got = await heard(() async => play.sheet(TipCode.owned));
    expect(got.single.outcome, TipOutcome.granted);
    expect(await loadSupporterTier(), SupporterTier.patron);
    expect(play.acked, isEmpty);
  });

  test('restore brings back the highest bought, settle leaves it', () async {
    play.owns = [
      bought('tip_supporter', token: 'a', acked: true),
      bought('tip_guardian', token: 'b', acked: true),
    ];
    // a new install: the look at the front grants nothing already delivered
    expect(await jar.settle(always: true), isNull);
    expect(await loadSupporterTier(), SupporterTier.none);
    final e = await jar.restore();
    expect(e.outcome, TipOutcome.granted);
    expect(e.tier, SupporterTier.guardian);
    expect(await loadSupporterTier(), SupporterTier.guardian);
    expect(play.acked, isEmpty);
    expect(await jar.ownedTiers(), {
      SupporterTier.supporter,
      SupporterTier.guardian,
    });
  });

  test('restore with nothing bought, or no play, says which', () async {
    expect((await jar.restore()).outcome, TipOutcome.nothing);
    play.ownedCode = TipCode.unavailable;
    expect((await jar.restore()).outcome, TipOutcome.unavailable);
    play.ownedCode = TipCode.failed;
    expect((await jar.restore()).outcome, TipOutcome.failed);
    expect(await jar.ownedTiers(), isEmpty);
  });

  test('the badge goes to the session the person is in', () async {
    box = HaloContainer.decoy;
    play.owns = [bought('tip_patron')];
    await jar.settle(always: true);
    expect(await loadSupporterTier(HaloContainer.decoy), SupporterTier.patron);
    expect(await loadSupporterTier(), SupporterTier.none);
  });

  test('a tip owed to one session is not settled in the other', () async {
    // started in the everyday app, still pending at play
    await jar.buy(SupporterTier.patron);
    play.owns = [bought('tip_patron', token: 'p')];
    // the decoy opens to the front: nothing owed there, play not asked
    box = HaloContainer.decoy;
    expect(await jar.settle(), isNull);
    expect(play.ownedAsks, 0);
    expect(await loadSupporterTier(HaloContainer.decoy), SupporterTier.none);
    // back in the everyday app it lands there
    box = HaloContainer.everyday;
    expect((await jar.settle())?.outcome, TipOutcome.granted);
    expect(await loadSupporterTier(), SupporterTier.patron);
    expect(play.acked, ['p']);
  });

  test('a grant waits for the lock to lift', () async {
    final held = <Future<void> Function()>[];
    jar = TipJar(
      billing: play,
      container: () => box,
      whenOpen: (a) async => held.add(a),
    );
    jar.listen();
    play.sheet(TipCode.ok, [bought('tip_patron')]);
    await Future<void>.delayed(Duration.zero);
    expect(await loadSupporterTier(), SupporterTier.none);
    expect(play.acked, isEmpty);
    await held.single();
    expect(await loadSupporterTier(), SupporterTier.patron);
    expect(play.acked, ['tok']);
  });

  test('no token or order id is kept anywhere', () async {
    play.owns = [bought('tip_guardian', token: 'TOKEN-123')];
    await jar.settle(always: true);
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()) {
      expect('${prefs.get(k)}', isNot(contains('TOKEN-123')), reason: k);
      expect(k, isNot(contains('order')));
      expect(k, isNot(contains('token')));
    }
    expect(prefs.getKeys(), {'supporter_tier'});
  });

  test('buy opens the sheet for the tier picked', () async {
    expect(await jar.buy(SupporterTier.patron), TipCode.ok);
    expect(play.bought, ['tip_patron']);
    expect(await jar.buy(SupporterTier.none), TipCode.failed);
    expect(play.bought, ['tip_patron']);
  });

  group('the channel', () {
    const ch = MethodChannel('kryfo/tips-test');
    final calls = <MethodCall>[];
    TestWidgetsFlutterBinding.ensureInitialized();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(calls.clear);
    tearDown(() => m.setMockMethodCallHandler(ch, null));

    test('reads what the play side hands over', () async {
      m.setMockMethodCallHandler(ch, (c) async {
        calls.add(c);
        return switch (c.method) {
          'products' => {
            'code': 'ok',
            'items': [
              {'id': 'tip_patron', 'price': r'$9.99'},
              {'id': 7},
            ],
          },
          'owned' => {
            'code': 'ok',
            'purchases': [
              {
                'products': ['tip_patron'],
                'state': 'purchased',
                'token': 'tk',
                'acked': true,
              },
              {'products': 'bad'},
            ],
          },
          'buy' => 'canceled',
          'ack' => 'ok',
          _ => null,
        };
      });
      final b = ChannelTipBilling(ch);
      final p = await b.products(['tip_patron']);
      expect(p.code, TipCode.ok);
      expect(p.items.single.price, r'$9.99');
      final o = await b.owned();
      expect(o.purchases.single.token, 'tk');
      expect(o.purchases.single.acknowledged, isTrue);
      expect(o.purchases.single.state, TipState.purchased);
      expect(await b.buy('tip_patron'), TipCode.canceled);
      expect(await b.acknowledge('tk'), TipCode.ok);
      expect(calls.map((c) => c.method), ['products', 'owned', 'buy', 'ack']);
      expect(calls.first.arguments, {
        'ids': ['tip_patron'],
      });
    });

    test('no play side reads as unavailable', () async {
      final b = ChannelTipBilling(ch);
      expect((await b.products(['tip_patron'])).code, TipCode.unavailable);
      expect((await b.owned()).code, TipCode.unavailable);
      expect(await b.buy('tip_patron'), TipCode.unavailable);
    });
  });
}
