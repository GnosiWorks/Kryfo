// SPDX-License-Identifier: GPL-3.0-or-later
// entrances only decorate. what comes in is laid out where it ends, and
// shows at once when motion is off, the ticker is held or the clock stalls.
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../desktop/desktop_trace.dart' show trace;

// motion off on the phone, a screen reader, or a held ticker (a page under
// the lock or another route): no entrance would be seen through
bool entranceOff(BuildContext context) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
    (MediaQuery.maybeAccessibleNavigationOf(context) ?? false) ||
    !TickerMode.valuesOf(context).enabled;

// past this, an entrance that has not ended is put at its end
const _grace = Duration(milliseconds: 300);

// plays one entrance controller and ends it if the ticker never gets there
class Entrance {
  AnimationController? _c;
  Timer? _cap;
  bool _gone = false;

  // run c up from [from], or set it at its end when it would not be seen
  void play(BuildContext context, AnimationController c, {double? from}) {
    _cap?.cancel();
    _c = c;
    if (entranceOff(context)) {
      c.value = c.upperBound;
      return;
    }
    c.forward(from: from);
    _cap = Timer((c.duration ?? Duration.zero) + _grace, end);
    _watch(c.value, 0);
  }

  // frames that come with no clock time: the ticker will not move it
  void _watch(double at, int n) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final c = _c;
      if (_gone || c == null || c.status != AnimationStatus.forward) return;
      if (c.value != at) return;
      if (n >= 2) return end();
      _watch(at, n + 1);
    });
  }

  // the end state now. only an entrance still on its way: an exit run on
  // the same controller is left alone
  void end() {
    final c = _c;
    if (_gone || c == null || c.status != AnimationStatus.forward) return;
    c.value = c.upperBound;
    // the ticker did not get there: with the trace on, a line says so
    trace('entrance put at its end');
    // drawn even where no frame was coming: the end state must show
    SchedulerBinding.instance.scheduleForcedFrame();
  }

  void dispose() {
    _gone = true;
    _cap?.cancel();
  }
}
