// SPDX-License-Identifier: GPL-3.0-or-later
// a screen's own timers, run only while the screen can be seen: the app in
// front and its route not covered. a page over it and the lock pane turn
// tickers off below them, which is what says covered; a sheet leaves the
// screen in view, so its timers go on. back in view, a job that fell due
// while away runs at once and then keeps its beat, so the screen shows what
// it would have shown had it run all along.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// [back] is true for the run that makes up for time out of view
typedef SeenRun = void Function(bool back);

class SeenTimers with WidgetsBindingObserver {
  SeenTimers({int Function()? clock}) : _clock = clock ?? _wall {
    WidgetsBinding.instance.addObserver(this);
    final s = WidgetsBinding.instance.lifecycleState;
    _front = s == null || s == AppLifecycleState.resumed;
  }

  static int _wall() => DateTime.now().millisecondsSinceEpoch;

  final int Function() _clock;
  final List<SeenJob> _jobs = [];
  ValueListenable<TickerModeData>? _mode;
  bool _front = true;
  bool _shown = true;
  bool _gone = false;
  // back in view, the catch-up not run yet: a poke then would take its place
  bool _waking = false;

  bool get seen => _front && _shown && !_gone;

  /// [run] every [period] while seen, the first time one period from now
  SeenJob every(Duration period, VoidCallback run) =>
      _add(SeenJob._(this, (_) => run(), () => period, eager: false));

  /// [run] after the wait [next] gives, null while nothing is pending. it
  /// runs at once on coming back into view. poke it when what [next] reads
  /// has changed
  SeenJob until(Duration? Function() next, SeenRun run) =>
      _add(SeenJob._(this, run, next, eager: true));

  SeenJob _add(SeenJob j) {
    _jobs.add(j);
    j._plan();
    return j;
  }

  /// from didChangeDependencies: follows the ticker mode above [context]
  void watch(BuildContext context) {
    final m = TickerMode.getValuesNotifier(context);
    if (identical(m, _mode)) return;
    _mode?.removeListener(_onMode);
    _mode = m..addListener(_onMode);
    _onMode();
  }

  void _onMode() => _set(_front, _mode?.value.enabled ?? true);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _set(state == AppLifecycleState.resumed, _shown);

  void _set(bool front, bool shown) {
    final was = seen;
    _front = front;
    _shown = shown;
    if (was == seen) return;
    if (!seen) {
      for (final j in _jobs) {
        j._pause();
      }
      return;
    }
    // the ticker mode flips while the tree builds, and a job may touch
    // other screens' state: it runs once that is over
    _waking = true;
    scheduleMicrotask(() {
      _waking = false;
      if (!seen) return;
      for (final j in List.of(_jobs)) {
        j._resume();
      }
    });
  }

  void dispose() {
    _gone = true;
    WidgetsBinding.instance.removeObserver(this);
    _mode?.removeListener(_onMode);
    _mode = null;
    for (final j in _jobs) {
      j._pause();
    }
    _jobs.clear();
  }
}

class SeenJob {
  SeenJob._(this._owner, this._run, this._next, {required bool eager})
    : _eager = eager;

  final SeenTimers _owner;
  final SeenRun _run;
  final Duration? Function() _next;
  // runs on every return, not only when it fell due while away
  final bool _eager;
  Timer? _timer;
  // when it wants to run, kept through time out of view
  int? _due;

  /// a timer is waiting, for the tests
  @visibleForTesting
  bool get pending => _timer != null;

  /// what [_next] reads has changed: an earlier wait takes over
  void poke() {
    if (!_owner.seen || _owner._waking) return;
    final wait = _next();
    if (wait == null) return;
    final due = _owner._clock() + wait.inMilliseconds;
    if (_timer != null && due >= _due!) return;
    _arm(due);
  }

  void _plan() {
    _timer?.cancel();
    _timer = null;
    final wait = _next();
    if (wait == null) {
      _due = null;
      return;
    }
    final due = _owner._clock() + wait.inMilliseconds;
    if (_owner.seen) {
      _arm(due);
    } else {
      _due = due;
    }
  }

  void _arm(int due) {
    _timer?.cancel();
    _due = due;
    final wait = due - _owner._clock();
    _timer = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), _fire);
  }

  void _fire({bool back = false}) {
    _timer = null;
    _due = null;
    _run(back);
    if (!_owner._gone && _owner._jobs.contains(this)) _plan();
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  void _resume() {
    if (_timer != null || _owner._gone) return;
    final due = _due;
    final now = _owner._clock();
    if (_eager || due == null || due <= now) {
      _fire(back: true);
      return;
    }
    // a clock set back must not push the beat out past one wait
    final most = _next();
    _arm(most == null ? due : math.min(due, now + most.inMilliseconds));
  }
}

/// the wait to a burn tick: the next deadline, or the next whole second
/// while a countdown shows, whichever comes first. [soonest] is the nearest
/// deadline of a message that can still burn. null: nothing counts down
Duration? burnWait(int now, {required bool ghosts, int? soonest}) {
  if (!ghosts) return null;
  var ms = 1000 - now % 1000;
  if (soonest != null && soonest - now < ms) ms = soonest - now;
  return Duration(milliseconds: ms < 0 ? 0 : ms);
}
