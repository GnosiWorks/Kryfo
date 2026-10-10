// SPDX-License-Identifier: GPL-3.0-or-later
// a page told when the page pushed over it is popped and it is on top
// again. sheets and menus over it do not count
import 'package:flutter/widgets.dart';

// on the app's navigator
final pageRoutes = RouteObserver<PageRoute<dynamic>>();

mixin BackOnTop<T extends StatefulWidget> on State<T> implements RouteAware {
  PageRoute<dynamic>? _route;

  // the page above is gone and this one shows again
  void backOnTop();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r is! PageRoute<dynamic> || identical(r, _route)) return;
    if (_route != null) pageRoutes.unsubscribe(this);
    _route = r;
    pageRoutes.subscribe(this, r);
  }

  @override
  void dispose() {
    pageRoutes.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (mounted) backOnTop();
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}

/// pops [nav] back to the page of the first of [states] it shows. false
/// when none of them is a page there
bool backToPage(NavigatorState nav, Iterable<State> states) {
  for (final s in states) {
    if (!s.mounted) continue;
    final r = ModalRoute.of(s.context);
    if (r == null || !r.isActive || r.navigator != nav) continue;
    if (!r.isCurrent) nav.popUntil((x) => x == r);
    return true;
  }
  return false;
}
