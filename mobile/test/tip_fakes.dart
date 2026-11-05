// SPDX-License-Identifier: GPL-3.0-or-later
// a google play that answers from lists: what it sells, what the account
// owns, and what the payment sheet comes back with
import 'package:kryfo/tips/tip_billing.dart';

class FakeTipBilling implements TipBilling {
  TipCode productsCode = TipCode.ok;
  List<TipProduct> items = const [
    TipProduct('tip_supporter', '€4.99'),
    TipProduct('tip_patron', '€9.99'),
    TipProduct('tip_guardian', '€24.99'),
  ];
  TipCode ownedCode = TipCode.ok;
  List<TipPurchase> owns = [];
  TipCode buyCode = TipCode.ok;
  final bought = <String>[];
  final acked = <String>[];
  void Function(TipUpdate u)? _update;

  @override
  set onUpdate(void Function(TipUpdate u)? f) => _update = f;

  /// the payment sheet closing, as play tells it
  void sheet(TipCode code, [List<TipPurchase> ps = const []]) =>
      _update?.call(TipUpdate(code, ps));

  @override
  Future<({TipCode code, List<TipProduct> items})> products(
    List<String> ids,
  ) async => (
    code: productsCode,
    items: [
      for (final i in items)
        if (ids.contains(i.id)) i,
    ],
  );

  @override
  Future<TipCode> buy(String id) async {
    bought.add(id);
    return buyCode;
  }

  int ownedAsks = 0;

  @override
  Future<({TipCode code, List<TipPurchase> purchases})> owned() async {
    ownedAsks++;
    return (code: ownedCode, purchases: List.of(owns));
  }

  @override
  Future<TipCode> acknowledge(String token) async {
    acked.add(token);
    owns = [
      for (final p in owns)
        p.token == token
            ? TipPurchase(
                products: p.products,
                state: p.state,
                token: p.token,
                acknowledged: true,
              )
            : p,
    ];
    return TipCode.ok;
  }
}

TipPurchase bought(
  String product, {
  String token = 'tok',
  TipState state = TipState.purchased,
  bool acked = false,
}) => TipPurchase(
  products: [product],
  state: state,
  token: token,
  acknowledged: acked,
);
