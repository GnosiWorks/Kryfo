// SPDX-License-Identifier: GPL-3.0-or-later
// lock_guard.dart - nothing gets past the app lock. what comes from outside
// while it is up, a notification tap or a link, waits until it lifts. a
// screen pushed while it is up waits under it. if the lock's own route is
// popped or removed while locked, a new one goes straight back on top. and
// what the app has open above its routes or running in the background (a
// message menu, a recorder, a voice note, the camera) closes as it goes up.
// a decoy unlock drops what waited instead, and a session changing under
// the lock takes out every screen between home and the lock.
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'lock_state.dart';

class LockGuard extends NavigatorObserver {
  LockGuard({required this.isLocked});

  final bool Function() isLocked;

  // the lock's own route, while it is up
  Route<dynamic>? lock;
  // the gate puts a new lock route up when this one went while locked
  VoidCallback? onLockLost;

  final Map<Object, Future<void> Function()> _held = {};
  int _unkeyed = 0;
  // the root navigator's routes, bottom first
  final List<Route<dynamic>> _routes = [];
  // work waiting to open a system dialog once the lock lifts
  final List<Completer<void>> _waiting = [];
  final Set<VoidCallback> _closers = {};

  // done now, or once the lock lifts. a key keeps one of a kind: the same
  // chat tapped twice while locked opens once, and a link that arrives by
  // two routes at a cold start is handled once
  Future<void> afterUnlock(Future<void> Function() act, {Object? key}) async {
    if (isLocked()) {
      _held.remove(key);
      _held[key ?? _unkeyed++] = act;
      return;
    }
    if (_justRan(key)) return;
    await act();
  }

  final Map<Object, DateTime> _ran = {};
  bool _justRan(Object? key) {
    if (key == null) return false;
    final now = DateTime.now();
    _ran.removeWhere((_, t) => now.difference(t).inSeconds >= 2);
    if (_ran.containsKey(key)) return true;
    _ran[key] = now;
    return false;
  }

  // the lock lifted: what waited starts now, in the order it came
  void lifted() {
    for (final w in _waiting) {
      w.complete();
    }
    _waiting.clear();
    if (_held.isEmpty) return;
    final held = Map.of(_held);
    _held.clear();
    for (final e in held.entries) {
      if (e.key is! int && _justRan(e.key)) continue;
      unawaited(e.value());
    }
  }

  // something open that must close when the lock goes up. returns what
  // takes it off the list again
  VoidCallback closeOnLock(VoidCallback close) {
    // the lock went up while this was still starting: it closes at once,
    // before anything of it is drawn
    if (isLocked()) {
      scheduleMicrotask(() {
        try {
          close();
        } catch (_) {}
      });
      return () {};
    }
    _closers.add(close);
    return () => _closers.remove(close);
  }

  // done once the lock is not up: for work that ends in a system dialog
  Future<void> unlocked() {
    if (!isLocked()) return Future.value();
    final done = Completer<void>();
    _waiting.add(done);
    return done.future;
  }

  // a decoy unlock: what waited for the everyday app never happens, and
  // work waiting for a dialog gives up rather than open it in the decoy
  void dropHeld() {
    _held.clear();
    for (final w in _waiting) {
      w.completeError(const LockDropped());
    }
    _waiting.clear();
  }

  // the session changed under the lock: every screen between home and the
  // lock goes, so none of the other session's is there when it lifts
  void dropUnderLock() {
    final l = lock;
    if (l == null) return;
    for (final r in List.of(_routes)) {
      if (r == l || r.isFirst || !r.isActive) continue;
      r.navigator?.removeRoute(r);
    }
  }

  // the lock is going up
  void locking() {
    for (final close in List.of(_closers)) {
      _closers.remove(close);
      try {
        close();
      } catch (_) {}
    }
  }

  void _lost(Route<dynamic>? route) {
    final l = lock;
    if (l == null || route != l || !isLocked()) return;
    lock = null;
    // the navigator is mid-change inside an observer: the new lock goes
    // up right after, still before anything is drawn
    scheduleMicrotask(() => onLockLost?.call());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    final l = lock;
    if (l == null || route == l || !isLocked()) return;
    // the new screen stays where it is, under a lock put back on top
    scheduleMicrotask(() {
      if (lock == l && l.isActive) l.navigator?.removeRoute(l);
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _lost(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _lost(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i >= 0) {
      newRoute == null ? _routes.removeAt(i) : _routes[i] = newRoute;
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _lost(oldRoute);
  }
}

// what a wait for the lock ends with when a decoy unlock drops it
class LockDropped implements Exception {
  const LockDropped();
}

// the app's one guard. a lock that has not been read yet counts as up
final lockGuard = LockGuard(
  isLocked: () => !lockState.loaded || lockState.locked,
);
