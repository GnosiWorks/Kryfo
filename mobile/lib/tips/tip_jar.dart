// SPDX-License-Identifier: GPL-3.0-or-later
// the play build's tip jar: a few one-time products on google play, each
// giving a supporter badge and nothing else. the badge is granted here, on
// the phone, and nothing goes to a server of ours: there is no account to
// tie a purchase to, and none is set on it. no order id or token is kept;
// a product is acknowledged and kept, never consumed, so google play hands
// it back on a new install signed in to the same google account
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../container.dart';
import '../main.dart' show session;
import '../lock_guard.dart' show lockGuard;
import '../supporter.dart';
import 'tip_billing.dart';

/// the products, made in the play console as one-time products under these
/// ids, with the badge each one gives. the ids are mario's to make there
const kTipProducts = {
  'tip_supporter': SupporterTier.supporter,
  'tip_patron': SupporterTier.patron,
  'tip_guardian': SupporterTier.guardian,
};

// a tip was started on this phone and play may still owe its outcome. only
// then does a return to the front ask play, so a phone that never tips never
// talks to play billing. the phone's, like the google account it pays from
const _owedKey = 'tip_owed';

/// the product id that gives [t]
String? tipProductFor(SupporterTier t) {
  for (final e in kTipProducts.entries) {
    if (e.value == t) return e.key;
  }
  return null;
}

// the badge a purchase gives: the highest of its products we know
SupporterTier _tierOf(TipPurchase p) {
  var t = SupporterTier.none;
  for (final id in p.products) {
    final got = kTipProducts[id];
    if (got != null && got.index > t.index) t = got;
  }
  return t;
}

enum TipOutcome {
  // the badge is on this phone now
  granted,
  // a higher badge was already here and stays
  kept,
  // play holds the payment until it goes through
  pending,
  canceled,
  // nothing to bring back on this google account
  nothing,
  unavailable,
  failed,
}

class TipEvent {
  final TipOutcome outcome;
  final SupporterTier tier;
  const TipEvent(this.outcome, [this.tier = SupporterTier.none]);
}

class TipJar {
  TipJar({
    TipBilling? billing,
    HaloContainer Function()? container,
    Future<void> Function(Future<void> Function() act)? whenOpen,
  }) : _billing = billing ?? ChannelTipBilling(),
       _container = container ?? (() => session.container),
       _whenOpen = whenOpen ?? ((act) => lockGuard.afterUnlock(act));

  static TipJar? _instance;
  static TipJar get instance => _instance ??= TipJar();
  static set instanceForTest(TipJar? j) => _instance = j;

  final TipBilling _billing;
  final HaloContainer Function() _container;
  final Future<void> Function(Future<void> Function() act) _whenOpen;
  final _events = StreamController<TipEvent>.broadcast();
  bool _listening = false;

  /// what play said, as it said it: the tip screen shows these
  Stream<TipEvent> get events => _events.stream;

  /// the payment sheet's outcomes and payments that went through later
  void listen() {
    if (_listening) return;
    _listening = true;
    _billing.onUpdate = (u) => unawaited(_updated(u));
  }

  Future<void> _updated(TipUpdate u) async {
    switch (u.code) {
      case TipCode.ok:
        // granted with the lock lifted, in the session the person is in. a
        // decoy unlock drops it; the next settle finds it unacknowledged
        await _whenOpen(() async {
          final e = await _take(u.purchases, all: true);
          if (e != null) _events.add(e);
        });
      case TipCode.canceled:
        _events.add(const TipEvent(TipOutcome.canceled));
      case TipCode.owned:
        // bought before on this google account: it comes back
        _events.add(await restore());
      case TipCode.unavailable:
        _events.add(const TipEvent(TipOutcome.unavailable));
      case TipCode.missing || TipCode.failed:
        _events.add(const TipEvent(TipOutcome.failed));
    }
  }

  // grants each purchase's badge, then acknowledges it. [all] false: only
  // purchases play still waits to hear about, the ones made since the last
  // look. granted before the acknowledgement, so a stop between the two
  // finds it again unacknowledged and grants the same badge once more
  Future<TipEvent?> _take(List<TipPurchase> ps, {required bool all}) async {
    var top = SupporterTier.none;
    var wears = SupporterTier.none;
    var pending = false;
    var open = false;
    for (final p in ps) {
      final t = _tierOf(p);
      if (t == SupporterTier.none) continue;
      if (p.state == TipState.pending) {
        pending = true;
        continue;
      }
      if (p.state != TipState.purchased) continue;
      if (!all && p.acknowledged) continue;
      wears = await grantTier(t, _container());
      if (t.index > top.index) top = t;
      if (!p.acknowledged &&
          await _billing.acknowledge(p.token) != TipCode.ok) {
        open = true;
      }
    }
    await _owe(pending || open);
    if (top != SupporterTier.none) {
      return wears.index > top.index
          ? TipEvent(TipOutcome.kept, wears)
          : TipEvent(TipOutcome.granted, top);
    }
    if (pending) return const TipEvent(TipOutcome.pending);
    return null;
  }

  /// the products play sells, priced in the person's currency
  Future<({TipCode code, List<TipProduct> items})> products() =>
      _billing.products(kTipProducts.keys.toList());

  /// opens the payment sheet for [t]. what came of it arrives on [events]
  Future<TipCode> buy(SupporterTier t) async {
    final id = tipProductFor(t);
    if (id == null) return TipCode.failed;
    listen();
    // owed until play's answer is taken, should the app stop on the sheet
    await _owe(true);
    return _billing.buy(id);
  }

  Future<void> _owe(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    if (on) {
      await prefs.setBool(_owedKey, true);
    } else {
      await prefs.remove(_owedKey);
    }
  }

  /// payments that went through since the last look, granted quietly: one
  /// that waited at play, or one the app was stopped in the middle of.
  /// play refunds what is not acknowledged within three days. play is asked
  /// only while a tip is owed, or [always] from the tip screen
  Future<TipEvent?> settle({bool always = false}) async {
    if (!always) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_owedKey) != true) return null;
    }
    final r = await _billing.owned();
    if (r.code != TipCode.ok) return null;
    final e = await _take(r.purchases, all: false);
    if (e != null) _events.add(e);
    return e;
  }

  /// the badges this google account has bought: those amounts are done, a
  /// kept product cannot be bought twice
  Future<Set<SupporterTier>> ownedTiers() async {
    final r = await _billing.owned();
    if (r.code != TipCode.ok) return const {};
    return {
      for (final p in r.purchases)
        if (p.state == TipState.purchased && _tierOf(p) != SupporterTier.none)
          _tierOf(p),
    };
  }

  /// every badge this google account bought, back on this phone
  Future<TipEvent> restore() async {
    final r = await _billing.owned();
    if (r.code == TipCode.unavailable) {
      return const TipEvent(TipOutcome.unavailable);
    }
    if (r.code != TipCode.ok) return const TipEvent(TipOutcome.failed);
    return await _take(r.purchases, all: true) ??
        const TipEvent(TipOutcome.nothing);
  }
}
