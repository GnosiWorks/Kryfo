// SPDX-License-Identifier: GPL-3.0-or-later
// lock_guard.dart - nothing opens over the app lock. what comes from
// outside while it is up, a notification tap or a link, waits until it
// lifts, and a screen pushed on top of it goes before it paints.
import 'dart:async';

import 'package:flutter/widgets.dart';

class LockGuard extends NavigatorObserver {
  LockGuard({required this.isLocked});

  final bool Function() isLocked;

  // the lock's own route, while it is up
  Route<dynamic>? lock;
  final List<Future<void> Function()> _held = [];

  // done now, or once the lock lifts
  Future<void> afterUnlock(Future<void> Function() act) async {
    if (isLocked()) {
      _held.add(act);
      return;
    }
    await act();
  }

  // the lock lifted: what waited happens now, in the order it came
  void lifted() {
    final held = List.of(_held);
    _held.clear();
    for (final act in held) {
      unawaited(act());
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final l = lock;
    if (l == null || route == l || !isLocked()) return;
    scheduleMicrotask(() {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }
}
