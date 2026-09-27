// SPDX-License-Identifier: GPL-3.0-or-later
// one-time fade + slide-up entrance for list items. delay scales with index
// (capped) so a list assembles gracefully instead of popping in at once.
import 'dart:async';

import 'package:flutter/material.dart';
import '../lock_guard.dart' show entranceDone;

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

class _StaggerInState extends State<StaggerIn> {
  // made under the lock after the app was first shown: no entrance at the
  // reveal (lock_guard.dart, entranceDone)
  late double _t = entranceDone ? 1 : 0;
  Timer? _wait;
  bool _late = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t == 1 || _wait != null) return;
    // with less movement a list is simply there
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _t = 1;
      return;
    }
    final now = DateTime.now();
    final quiet =
        _lastAt == null || now.difference(_lastAt!).inMilliseconds > 400;
    if (quiet) _burstAt = now;
    _lastAt = now;
    _late = now.difference(_burstAt!).inMilliseconds > 200;
    final delay = _late ? 0 : (widget.index * 30).clamp(0, 180);
    _wait = Timer(Duration(milliseconds: delay), () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = Duration(milliseconds: _late ? 140 : 220);
    return AnimatedOpacity(
      opacity: _t,
      duration: d,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: Offset(0, (1 - _t) * (_late ? 0.03 : 0.08)),
        duration: d,
        curve: Curves.easeOut,
        child: widget.child,
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

// the same, all at once when motion is reduced
List<Widget> staggerAllIn(BuildContext context, List<Widget> children) =>
    MediaQuery.of(context).disableAnimations ? children : staggerAll(children);
