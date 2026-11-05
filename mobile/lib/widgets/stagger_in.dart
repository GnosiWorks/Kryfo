// SPDX-License-Identifier: GPL-3.0-or-later
// one-time fade + slide-up entrance for list items. delay scales with index
// (capped) so a list comes in row by row, not all at once.
import 'package:flutter/material.dart';
import '../lock_guard.dart' show entranceDone;
import 'entrance.dart';

class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggerIn({super.key, required this.index, required this.child});

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

// the first rows of a list that opens come in one after another; rows built
// later by scrolling are late and only fade, at once
DateTime? _burstAt;
DateTime? _lastAt;

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  // the wait before a row moves is the start of its own run, so one ticker
  // and one fallback cover both
  AnimationController? _c;
  final _entrance = Entrance();
  Animation<double> _v = const AlwaysStoppedAnimation(1);
  bool _late = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      // held on the way in (a lock, a route over it): the row at rest
      if (entranceOff(context)) _entrance.end();
      return;
    }
    _started = true;
    // made under the lock after the app was first shown, or motion off: the
    // row at rest (lock_guard.dart, entranceDone)
    if (entranceDone || entranceOff(context)) return;
    final now = DateTime.now();
    final quiet =
        _lastAt == null || now.difference(_lastAt!).inMilliseconds > 400;
    if (quiet) _burstAt = now;
    _lastAt = now;
    _late = now.difference(_burstAt!).inMilliseconds > 200;
    final delay = _late ? 0 : (widget.index * 30).clamp(0, 180);
    final run = _late ? 140 : 220;
    final total = delay + run;
    final c = _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _v = CurvedAnimation(
      parent: c,
      curve: Interval(delay / total, 1, curve: Curves.easeOut),
    );
    _entrance.play(context, c, from: 0);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lift = _late ? 0.03 : 0.08;
    return FadeTransition(
      opacity: _v,
      // a reader gets the row at once. left out while at zero, a row built
      // after a page jump never comes back into the tree
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: _v,
        child: widget.child,
        // only the paint moves: a tap lands where the row ends up
        builder: (_, child) => FractionalTranslation(
          translation: Offset(0, (1 - _v.value) * lift),
          transformHitTests: false,
          child: child,
        ),
      ),
    );
  }
}

// wrap a literal list of children so they assemble one after another. a
// spacer or an expanded stays a direct child of the column: wrapped it
// throws a parent-data error, which release paints as a light box.
List<Widget> staggerAll(List<Widget> children, {int from = 0}) => [
  for (var i = 0; i < children.length; i++)
    if (children[i] is Spacer || children[i] is Expanded)
      children[i]
    else
      StaggerIn(index: from + i, child: children[i]),
];

// the same, all at once with reduced motion
List<Widget> staggerAllIn(BuildContext context, List<Widget> children) =>
    MediaQuery.of(context).disableAnimations ? children : staggerAll(children);
