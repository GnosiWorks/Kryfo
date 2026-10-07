// SPDX-License-Identifier: GPL-3.0-or-later
// what the lock layer cannot cover by drawing over it. taps, links and
// system dialogs wait until it lifts, players, recorders and the camera stop
// as it goes up, and a decoy unlock drops what waited.
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'dlog.dart';
import 'lock_state.dart';

class LockGuard {
  LockGuard({required this.isLocked});

  final bool Function() isLocked;

  // what waits, by its slot, with the key it is told apart by
  final Map<Object, (Object?, Future<void> Function())> _held = {};
  int _unkeyed = 0;
  // work waiting to open a system dialog once the lock lifts
  final List<Completer<void>> _waiting = [];
  // the same, for what may come after a decoy unlock too
  final List<Completer<void>> _anyWaiting = [];
  final Set<VoidCallback> _closers = {};

  // done now, or once the lock lifts. a key keeps one of a kind, so a link
  // that arrives by two routes at a cold start is handled once. a slot
  // keeps only the latest of what waits in it, whatever its key
  Future<void> afterUnlock(
    Future<void> Function() act, {
    Object? key,
    Object? slot,
  }) async {
    if (isLocked()) {
      final at = slot ?? key;
      _held.remove(at);
      _held[at ?? _unkeyed++] = (key, act);
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

  // done once the lock lifts, whatever it opened: for what shows nothing
  // of either session, like android's notification permission dialog
  Future<void> anyUnlock() {
    if (!isLocked()) return Future.value();
    final done = Completer<void>();
    _anyWaiting.add(done);
    return done.future;
  }

  void _liftedAny() {
    for (final w in _anyWaiting) {
      w.complete();
    }
    _anyWaiting.clear();
  }

  // the lock lifted: what waited starts now, in the order it came
  void lifted() {
    _liftedAny();
    for (final w in _waiting) {
      w.complete();
    }
    _waiting.clear();
    if (_held.isEmpty) return;
    final held = Map.of(_held);
    _held.clear();
    for (final (key, act) in held.values) {
      if (_justRan(key)) continue;
      unawaited(act());
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
        } catch (e) {
          dlog('lock: a close threw (${e.runtimeType})');
        }
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
    _liftedAny();
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
      } catch (e) {
        // one that throws must not keep the rest running under the lock
        dlog('lock: a close threw (${e.runtimeType})');
      }
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

// the app has been shown once since the process started
bool appRevealed = false;

// a first build under the lock, once the app has been shown, starts its
// animation finished: a session switch builds a new home there, and it has
// to come up as still as the everyday one
bool get entranceDone => appRevealed && lockGuard.isLocked();

// a screen is being looked at: its route is on top and no lock is over it
bool onScreen(BuildContext context) =>
    !lockGuard.isLocked() && (ModalRoute.of(context)?.isCurrent ?? false);
