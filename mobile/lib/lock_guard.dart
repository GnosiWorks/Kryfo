// SPDX-License-Identifier: GPL-3.0-or-later
// lock_guard.dart - what the app lock's layer cannot cover by drawing over
// it. what comes from outside while it is up, a notification tap or a link,
// waits until it lifts, since opening it underneath would still run it. what
// runs outside the widget tree (a voice note, a recorder, the camera, a
// video) stops as it goes up. work that ends in a system dialog waits for it
// to lift. a decoy unlock drops what waited instead.
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'lock_state.dart';

class LockGuard {
  LockGuard({required this.isLocked});

  final bool Function() isLocked;

  final Map<Object, Future<void> Function()> _held = {};
  int _unkeyed = 0;
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

  // something running that must stop when the lock goes up. returns what
  // takes it off the list again
  VoidCallback closeOnLock(VoidCallback close) {
    // the lock went up while this was still starting: it stops at once
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

  // the lock is going up
  void locking() {
    for (final close in List.of(_closers)) {
      _closers.remove(close);
      try {
        close();
      } catch (_) {}
    }
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

// a screen is being looked at: its route is on top and no lock is over it
bool onScreen(BuildContext context) =>
    !lockGuard.isLocked() && (ModalRoute.of(context)?.isCurrent ?? false);
