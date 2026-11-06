// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'desktop_trace.dart' show trace, tracing;

/// a frame now, drawn even while dart thinks the window hidden
void deskFrameNow() => SchedulerBinding.instance.scheduleForcedFrame();

/// a new root, and a frame for it once it is attached: runApp attaches in
/// a timer of its own, before this one
void deskRunApp(Widget app) {
  runApp(app);
  Timer.run(deskFrameNow);
  if (!tracing) return;
  final asked = Stopwatch()..start();
  trace('root ${app.runtimeType}');
  SchedulerBinding.instance.addPostFrameCallback(
    (_) => trace('root drawn +${asked.elapsedMilliseconds}ms'),
  );
}

/// the runner's 'frame' call: the window came up, forward or back from the
/// taskbar. a window on the screen is never hidden to dart: a lifecycle
/// that says so (a hide heard before a show it never heard) would keep
/// every frame back, the entrances' with them
void deskWindowFrame(Object? args) {
  final m = args is Map ? args : const {};
  final binding = WidgetsBinding.instance;
  final life = binding.lifecycleState;
  if (m['shown'] == true &&
      (life == AppLifecycleState.hidden || life == AppLifecycleState.paused)) {
    binding.handleAppLifecycleStateChanged(
      m['active'] == true
          ? AppLifecycleState.resumed
          : AppLifecycleState.inactive,
    );
  }
  deskFrameNow();
}

/// a frame asked for that does not begin: one forced, and a round trip to
/// the runner, which wakes its thread as a mouse move does. with the trace
/// on, the wait, how long it took and every lifecycle change are lines
class DeskFrameWatch with WidgetsBindingObserver {
  DeskFrameWatch({
    required this.nudge,
    this.every = const Duration(milliseconds: 250),
    this.after = const Duration(seconds: 1),
  });

  /// the runner's round trip
  final Future<void> Function() nudge;
  final Duration every;

  /// how long a frame may wait before the nudge
  final Duration after;

  int _begun = 0;
  int _seen = 0;
  Duration _waited = Duration.zero;
  bool _stuck = false;
  Timer? _tick;

  /// frames begun so far
  @visibleForTesting
  int get begun => _begun;

  /// nudges sent so far
  @visibleForTesting
  int nudges = 0;

  void start() {
    final b = WidgetsBinding.instance;
    b.addPersistentFrameCallback((_) => _begun++);
    b.addObserver(this);
    _tick = Timer.periodic(every, (_) => check());
  }

  void stop() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    trace('life ${state.name}');
  }

  /// one look: a frame scheduled and none begun since the last look
  @visibleForTesting
  void check() {
    final b = SchedulerBinding.instance;
    if (!b.hasScheduledFrame || _begun != _seen) {
      if (_stuck) trace('frame came after ${_waited.inMilliseconds}ms');
      _stuck = false;
      _waited = Duration.zero;
      _seen = _begun;
      return;
    }
    _waited += every;
    if (_waited < after) return;
    if (!_stuck) {
      _stuck = true;
      trace(
        'frame waits ${_waited.inMilliseconds}ms '
        '(life ${b.lifecycleState?.name ?? 'none'})',
      );
    }
    deskFrameNow();
    nudges++;
    unawaited(nudge().catchError((Object _) {}));
  }
}
