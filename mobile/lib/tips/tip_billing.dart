// SPDX-License-Identifier: GPL-3.0-or-later
// google play billing as the tip jar sees it, over the play build's channel
// (android/app/src/play PlayTips.kt). the foss build has no such channel and
// never calls it: nothing of google's is in it. a purchase comes with its
// product, its state and its token, never its order id
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

// how play answered
enum TipCode { ok, canceled, owned, unavailable, missing, failed }

TipCode tipCodeOf(Object? s) => switch (s) {
  'ok' => TipCode.ok,
  'canceled' => TipCode.canceled,
  'owned' => TipCode.owned,
  'unavailable' => TipCode.unavailable,
  'missing' => TipCode.missing,
  _ => TipCode.failed,
};

enum TipState { purchased, pending, other }

class TipPurchase {
  final List<String> products;
  final TipState state;
  // what acknowledges it. held only while it is acknowledged, never stored
  final String token;
  final bool acknowledged;
  const TipPurchase({
    required this.products,
    required this.state,
    required this.token,
    this.acknowledged = false,
  });

  static TipPurchase? of(Object? raw) {
    if (raw is! Map) return null;
    final products = raw['products'];
    final token = raw['token'];
    if (products is! List || token is! String) return null;
    return TipPurchase(
      products: [for (final p in products) '$p'],
      state: switch (raw['state']) {
        'purchased' => TipState.purchased,
        'pending' => TipState.pending,
        _ => TipState.other,
      },
      token: token,
      acknowledged: raw['acked'] == true,
    );
  }
}

class TipProduct {
  final String id;
  // as play formats it, in the person's currency
  final String price;
  const TipProduct(this.id, this.price);
}

// a payment sheet that closed, or a pending payment that went through
class TipUpdate {
  final TipCode code;
  final List<TipPurchase> purchases;
  const TipUpdate(this.code, this.purchases);
}

abstract class TipBilling {
  /// the products play sells under [ids], null when play billing is not there
  Future<({TipCode code, List<TipProduct> items})> products(List<String> ids);

  /// opens play's payment sheet; the outcome comes as an update
  Future<TipCode> buy(String id);

  /// what this google account owns and has not had consumed
  Future<({TipCode code, List<TipPurchase> purchases})> owned();

  Future<TipCode> acknowledge(String token);

  set onUpdate(void Function(TipUpdate u)? f);
}

List<TipPurchase> _purchases(Object? raw) => [
  if (raw is List)
    for (final p in raw) ?TipPurchase.of(p),
];

class ChannelTipBilling implements TipBilling {
  ChannelTipBilling([this._ch = const MethodChannel('kryfo/tips')]);
  final MethodChannel _ch;
  void Function(TipUpdate u)? _update;
  bool _listening = false;

  @override
  set onUpdate(void Function(TipUpdate u)? f) {
    _update = f;
    if (_listening) return;
    _listening = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method != 'updated') return null;
      final a = call.arguments;
      final m = a is Map ? a : const {};
      _update?.call(
        TipUpdate(tipCodeOf(m['code']), _purchases(m['purchases'])),
      );
      return null;
    });
  }

  Future<Object?> _call(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      return 'unavailable';
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<({TipCode code, List<TipProduct> items})> products(
    List<String> ids,
  ) async {
    final r = await _call('products', {'ids': ids});
    if (r is! Map) return (code: tipCodeOf(r), items: const <TipProduct>[]);
    final items = r['items'];
    return (
      code: tipCodeOf(r['code']),
      items: [
        if (items is List)
          for (final i in items)
            if (i is Map && i['id'] is String && i['price'] is String)
              TipProduct(i['id'] as String, i['price'] as String),
      ],
    );
  }

  @override
  Future<TipCode> buy(String id) async =>
      tipCodeOf(await _call('buy', {'id': id}));

  @override
  Future<({TipCode code, List<TipPurchase> purchases})> owned() async {
    final r = await _call('owned');
    if (r is! Map) {
      return (code: tipCodeOf(r), purchases: const <TipPurchase>[]);
    }
    return (code: tipCodeOf(r['code']), purchases: _purchases(r['purchases']));
  }

  @override
  Future<TipCode> acknowledge(String token) async =>
      tipCodeOf(await _call('ack', {'token': token}));

  @visibleForTesting
  MethodChannel get channel => _ch;
}
