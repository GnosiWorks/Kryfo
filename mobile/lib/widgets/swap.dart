// SPDX-License-Identifier: GPL-3.0-or-later
// something that changes in place. a value's new words rise in over the old
// ones, the way a protection's state does in settings; a page's new state
// fades in over the last. both are instant when the phone asks for no
// movement. [child] is keyed by what it shows
import 'package:flutter/widgets.dart';

import 'motion.dart' show motionStill;

class RiseSwap extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;
  const RiseSwap({
    super.key,
    required this.child,
    this.alignment = AlignmentDirectional.centerStart,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(a),
          child: c,
        ),
      ),
      layoutBuilder: (top, gone) =>
          Stack(alignment: alignment, children: [...gone, ?top]),
      child: child,
    );
  }
}

class FadeSwap extends StatelessWidget {
  final Widget child;
  const FadeSwap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // both pages fill the same room while they cross, so nothing jumps
      layoutBuilder: (top, gone) => Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.topCenter,
        children: [...gone, ?top],
      ),
      child: child,
    );
  }
}
