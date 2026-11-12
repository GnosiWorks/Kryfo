// SPDX-License-Identifier: GPL-3.0-or-later
// a page's own reads wait until its way in has played: the first frames
// draw the page as it will stand, quiet places held, and nothing it reads
// can stall the slide in
import 'dart:async';

import 'package:flutter/widgets.dart';

/// done once the route that holds [context] is fully in (at once when there
/// is no route, or it is in already)
Future<void> routeSettled(BuildContext context) {
  final a = ModalRoute.of(context)?.animation;
  if (a == null || a.status == AnimationStatus.completed) {
    return Future.value();
  }
  final done = Completer<void>();
  void watch(AnimationStatus s) {
    if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
      a.removeStatusListener(watch);
      if (!done.isCompleted) done.complete();
    }
  }

  a.addStatusListener(watch);
  // a route that never settles still reads, a beat later
  return done.future.timeout(
    const Duration(milliseconds: 900),
    onTimeout: () => a.removeStatusListener(watch),
  );
}
