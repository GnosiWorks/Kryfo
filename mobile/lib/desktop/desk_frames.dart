// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ui' show FramePhase, FrameTiming;

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
/// every frame back, the entrances' with them. none heard yet counts as
/// hidden
void deskWindowFrame(Object? args) {
  final m = args is Map ? args : const {};
  final binding = WidgetsBinding.instance;
  final life = binding.lifecycleState;
  if (m['shown'] == true &&
      (life == null ||
          life == AppLifecycleState.hidden ||
          life == AppLifecycleState.paused)) {
    binding.handleAppLifecycleStateChanged(
      m['active'] == true
          ? AppLifecycleState.resumed
          : AppLifecycleState.inactive,
    );
  }
  deskFrameNow();
}

/// a frame's phases past [kSlowFrame] as one line: the wait from its vsync
/// to its build, the build, the wait for the raster thread and the raster.
/// the raster's own share names a held raster thread (a shader compiled,
/// a present stuck); the queue names work there that was not a frame. null
/// when every phase was quick
const kSlowFrame = Duration(milliseconds: 250);

String? slowFrameLine(FrameTiming t) {
  int ms(FramePhase a, FramePhase b) =>
      (t.timestampInMicroseconds(b) - t.timestampInMicroseconds(a)) ~/ 1000;
  final vsync = ms(FramePhase.vsyncStart, FramePhase.buildStart);
  final build = ms(FramePhase.buildStart, FramePhase.buildFinish);
  final queue = ms(FramePhase.buildFinish, FramePhase.rasterStart);
  final raster = ms(FramePhase.rasterStart, FramePhase.rasterFinish);
  final slow = kSlowFrame.inMilliseconds;
  if (vsync < slow && build < slow && queue < slow && raster < slow) {
    return null;
  }
  return 'frame slow: vsync to build ${vsync}ms, build ${build}ms, '
      'raster queue ${queue}ms, raster ${raster}ms';
}

/// a frame asked for that does not begin: one forced, and a round trip to
/// the runner, which wakes its thread as a mouse move does. with the trace
/// on, the wait, how long it took, the runner's slowest answer meanwhile,
/// every slow frame and every lifecycle change are lines
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
  // the runner's slowest answer to a nudge in this wait
  int _answerMs = 0;

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
    if (tracing) b.addTimingsCallback(timings);
    _tick = Timer.periodic(every, (_) => check());
  }

  void stop() {
    _tick?.cancel();
    final b = WidgetsBinding.instance;
    b.removeObserver(this);
    b.removeTimingsCallback(timings);
  }

  /// the engine's timings of drawn frames: a slow one is a line
  @visibleForTesting
  void timings(List<FrameTiming> list) {
    for (final t in list) {
      final line = slowFrameLine(t);
      if (line != null) trace(line);
    }
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
      if (_stuck) {
        trace(
          'frame came after ${_waited.inMilliseconds}ms '
          '(runner answered within ${_answerMs}ms)',
        );
      }
      _stuck = false;
      _waited = Duration.zero;
      _answerMs = 0;
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
    final asked = Stopwatch()..start();
    unawaited(
      nudge().then((_) {
        final ms = asked.elapsedMilliseconds;
        if (ms > _answerMs) _answerMs = ms;
      }, onError: (Object _) {}),
    );
  }
}
