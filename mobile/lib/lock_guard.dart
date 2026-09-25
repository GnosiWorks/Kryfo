// SPDX-License-Identifier: GPL-3.0-or-later
// lock_guard.dart - nothing gets past the app lock. what comes from outside
// while it is up, a notification tap or a link, waits until it lifts. a
// screen pushed while it is up waits under it. if the lock's own route is
// popped or removed while locked, a new one goes straight back on top. and
// what the app has open above its routes or running in the background (a
// message menu, a recorder, a voice note, the camera) closes as it goes up.
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

  // the lock lifted: what waited happens now, in the order it came
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
    _closers.add(close);
    return () => _closers.remove(close);
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
