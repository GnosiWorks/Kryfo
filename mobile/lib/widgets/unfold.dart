// SPDX-License-Identifier: GPL-3.0-or-later
// a part of a card that opens and closes in place. it opens its height and
// fades up; closing, it stays drawn and fades as it folds shut, so the card
// never shrinks round nothing. with less movement it is simply there or gone
import 'package:flutter/widgets.dart';

import 'motion.dart' show motionStill;

class Unfold extends StatelessWidget {
  final bool open;
  final Widget child;
  final Duration duration;
  const Unfold({
    super.key,
    required this.open,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionStill(context) ? Duration.zero : duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, a) => SizeTransition(
        sizeFactor: a,
        axisAlignment: -1,
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: a,
            curve: const Interval(0.25, 1, curve: Curves.easeOut),
          ),
          child: c,
        ),
      ),
      layoutBuilder: (top, gone) => Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.topCenter,
        children: [...gone, ?top],
      ),
      child: open
          ? KeyedSubtree(key: const ValueKey(true), child: child)
          : const SizedBox(
              key: ValueKey(false),
              width: double.infinity,
              height: 0,
            ),
    );
  }
}
