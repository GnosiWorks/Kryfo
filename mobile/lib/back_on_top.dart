// SPDX-License-Identifier: GPL-3.0-or-later
// a page told when the page pushed over it is popped and it is on top
// again. sheets and menus over it do not count
import 'package:flutter/widgets.dart';

// on the app's navigator
final pageRoutes = RouteObserver<PageRoute<dynamic>>();

// the routes a chat page stands on: a 1:1 chat or a group's
final Set<Route<dynamic>> _chatRoutes = {};

/// true when [r] is a chat's own page
bool isChatPage(Route<dynamic> r) => _chatRoutes.contains(r);

mixin BackOnTop<T extends StatefulWidget> on State<T> implements RouteAware {
  PageRoute<dynamic>? _route;

  // the page above is gone and this one shows again
  void backOnTop();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r is! PageRoute<dynamic> || identical(r, _route)) return;
    if (_route != null) {
      pageRoutes.unsubscribe(this);
      _chatRoutes.remove(_route);
    }
    _route = r;
    _chatRoutes.add(r);
    pageRoutes.subscribe(this, r);
  }

  @override
  void dispose() {
    pageRoutes.unsubscribe(this);
    _chatRoutes.remove(_route);
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

/// the app navigator's routes, oldest first, sheets and dialogs too
class RouteStack extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];

  /// the routes over [r], nearest first. none when [r] is not here
  List<Route<dynamic>> above(Route<dynamic> r) {
    final i = _routes.indexOf(r);
    return i < 0 ? const [] : _routes.sublist(i + 1);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i < 0 || newRoute == null) return;
    _routes[i] = newRoute;
  }
}

// on the app's navigator
final routeStack = RouteStack();
