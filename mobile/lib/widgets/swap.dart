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

/// one line giving way to the next with no frame where both show: the old
/// fades out in the first half, the new fades in over the second
class OutInSwap extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;
  const OutInSwap({
    super.key,
    required this.child,
    this.alignment = AlignmentDirectional.centerStart,
  });

  static final _half = CurveTween(
    curve: const Interval(0.5, 1, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      transitionBuilder: (c, a) =>
          FadeTransition(opacity: a.drive(_half), child: c),
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
      // both pages fill the same room while they cross, so nothing jumps.
      // the leaving one gives up its heroes: both pages may carry the same
      // tag, and a cross held still under a covering page would clash on
      // the way back
      layoutBuilder: (top, gone) => Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.topCenter,
        children: [
          for (final g in gone) HeroMode(key: g.key, enabled: false, child: g),
          if (top != null) HeroMode(key: top.key, child: top),
        ],
      ),
      child: child,
    );
  }
}
