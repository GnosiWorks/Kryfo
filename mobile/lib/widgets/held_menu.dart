// SPDX-License-Identifier: GPL-3.0-or-later
// the long-press menu over a chat: system back folds it before it leaves
// the chat, and it never stays over a route that covers or replaces it
import 'package:flutter/widgets.dart';

mixin HeldMenu<T extends StatefulWidget> on State<T> {
  // folds the open menu away, or with now takes it off in this frame
  void Function({bool now})? _shut;
  var _folding = false;
  var _ending = false;
  // the chat route's own animation: it runs back the moment it is popped
  Animation<double>? _route;

  // false once the chat is going: a menu taken off then leaves it alone
  bool get menuMayTouch => mounted && !_ending;

  void menuOpened(void Function({bool now}) shut) {
    _shut = shut;
    _folding = false;
    _unwatch();
    _route = ModalRoute.of(context)?.animation?..addStatusListener(_leaving);
    if (mounted) setState(() {});
  }

  void _leaving(AnimationStatus s) {
    if (s == AnimationStatus.reverse || s == AnimationStatus.dismissed) {
      _shut?.call(now: true);
    }
  }

  void _unwatch() {
    _route?.removeStatusListener(_leaving);
    _route = null;
  }

  // on its way out: back leaves the chat again
  void menuFolding(void Function({bool now}) shut) {
    if (!identical(_shut, shut) || _folding) return;
    _folding = true;
    if (menuMayTouch) setState(() {});
  }

  void menuRemoved(void Function({bool now}) shut) {
    if (!identical(_shut, shut)) return;
    _shut = null;
    _folding = false;
    _unwatch();
    if (menuMayTouch) setState(() {});
  }

  Widget menuBack({required Widget child}) => PopScope(
    canPop: _shut == null || _folding,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _shut?.call();
    },
    child: child,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // another route on top: no menu over it
    if (ModalRoute.isCurrentOf(context) == false) _shut?.call(now: true);
  }

  @override
  void dispose() {
    _ending = true;
    _shut?.call(now: true);
    _shut = null;
    _unwatch();
    super.dispose();
  }
}
