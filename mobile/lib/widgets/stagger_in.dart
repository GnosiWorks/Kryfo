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

class _StaggerInState extends State<StaggerIn> {
  // made under the lock after the app was first shown: no entrance at the
  // reveal (lock_guard.dart, entranceDone)
  late double _t = entranceDone ? 1 : 0;
  Timer? _wait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t == 1 || _wait != null) return;
    // with less movement a list is simply there
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _t = 1;
      return;
    }
    final delay = (widget.index * 45).clamp(0, 400);
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
    return AnimatedOpacity(
      opacity: _t,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: Offset(0, (1 - _t) * 0.08),
        duration: const Duration(milliseconds: 320),
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
