// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop's chat pane: its own navigator, which chats, settings and the
// list's pages open into, beside the list on a wide window and over it on a
// narrow one. the phone never makes one
import 'package:flutter/material.dart';

import '../back_on_top.dart';

/// pushes [route] where a page opened from here belongs. [id] names the
/// chat it is, so the open one is not opened twice
typedef DeskPush = Future<T?> Function<T>(Route<T> route, {String? id});

class WidePane {
  final key = GlobalKey<NavigatorState>();
  final stack = RouteStack();
  final pages = RouteObserver<PageRoute<dynamic>>();
  late final watch = _Watch(this);
  // the pane's own: one controller per navigator
  final heroes = HeroController();

  /// routes over the empty one
  final depth = ValueNotifier<int>(0);

  /// the app's route the pane stands in, the home
  Route<dynamic>? host;

  String? _openId;
  Route<dynamic>? _openRoute;

  NavigatorState? get nav => key.currentState;

  List<NavigatorObserver> get observers => [stack, pages, watch];

  /// whether a page opened from [context] goes into the pane: one from the
  /// list, the rail or a sheet over the home. a page in the pane keeps its
  /// own navigator, and so does one over the whole window
  bool takes(BuildContext context) {
    final h = host;
    final r = ModalRoute.of(context);
    if (h == null || nav == null || r == null) return false;
    if (r == h) return true;
    return r is! PageRoute && r.navigator == h.navigator && h.isActive;
  }

  /// [route] in the pane in place of what it shows. the chat already there
  /// is gone back to instead
  Future<T?> show<T>(Route<T> route, {String? id}) {
    final n = nav!;
    final open = _openRoute;
    if (id != null && id == _openId && open != null && open.isActive) {
      n.popUntil((r) => r == open);
      return Future.value();
    }
    _openId = id;
    _openRoute = route;
    wideOnScreen.value = id;
    if (depth.value == 0) return n.push(route);
    // the page under stays until the new one is in, so nothing flashes
    return n.pushAndRemoveUntil(route, (r) => r.isFirst);
  }

  /// back one page. false when the pane was empty
  bool back() {
    if (depth.value == 0) return false;
    nav?.maybePop();
    return true;
  }

  bool _gone = false;

  void dispose() {
    _gone = true;
    depth.dispose();
    heroes.dispose();
  }
}

class _Watch extends NavigatorObserver {
  _Watch(this.pane);
  final WidePane pane;
  int _n = 0;

  void _set(int n) {
    _n = n < 0 ? 0 : n;
    if (_n == 0) {
      pane._openId = null;
      pane._openRoute = null;
    }
    // told mid-build at times: the count follows after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pane._gone) return;
      if (pane.depth.value != _n) pane.depth.value = _n;
      if (_n == 0) wideOnScreen.value = null;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _set(_n + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(_n - 1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(_n - 1);
}

/// the pane on screen. null on the phone, and before the home is built
WidePane? widePane;

/// the chat or group the list opened in the pane (a group as 'group:'
/// and its id), for the mark on its row
final wideOnScreen = ValueNotifier<String?>(null);

/// true while the window is wide: list and pane side by side
final wideNow = ValueNotifier<bool>(false);

/// how a page opened from [context] is pushed: into the pane when it has
/// one, else on its own navigator. read before any await
DeskPush deskPusher(BuildContext context) {
  final pane = widePane;
  if (pane != null && pane.takes(context)) {
    return <T>(Route<T> route, {String? id}) => pane.show(route, id: id);
  }
  final nav = Navigator.of(context);
  return <T>(Route<T> route, {String? id}) => nav.push(route);
}

/// [route] pushed from [context]: see [deskPusher]
Future<T?> deskPush<T>(BuildContext context, Route<T> route, {String? id}) =>
    deskPusher(context)<T>(route, id: id);

/// the navigator a chat opened from outside the screens goes on: the pane,
/// else the app's own
NavigatorState? chatNavigator(NavigatorState? app) => widePane?.nav ?? app;
