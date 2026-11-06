// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// a frame now, drawn even while dart thinks the window hidden
void deskFrameNow() => SchedulerBinding.instance.scheduleForcedFrame();

/// a new root, and a frame for it once it is attached: runApp attaches in
/// a timer of its own, before this one
void deskRunApp(Widget app) {
  runApp(app);
  Timer.run(deskFrameNow);
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
