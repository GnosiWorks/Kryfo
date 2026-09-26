// SPDX-License-Identifier: GPL-3.0-or-later
// nothing gets past the app lock. taps and links wait until it lifts,
// screens pushed while locked wait under it, a lost lock route goes back on
// top, and menus, recorders and the camera close as it goes up.
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
  final Set<VoidCallback> _closers = {};

  // done now, or once the lock lifts. a key keeps one of a kind, so a link
  // that arrives by two routes at a cold start is handled once
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
    _held[_unkeyed++] = () async => done.complete();
    return done.future;
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
    final l = lock;
    if (l == null || route == l || !isLocked()) return;
    // the new screen stays where it is, under a lock put back on top
    scheduleMicrotask(() {
      if (lock == l && l.isActive) l.navigator?.removeRoute(l);
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _lost(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _lost(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _lost(oldRoute);
}

// the app's one guard. a lock that has not been read yet counts as up
final lockGuard = LockGuard(
  isLocked: () => !lockState.loaded || lockState.locked,
);
