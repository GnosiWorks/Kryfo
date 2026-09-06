// SPDX-License-Identifier: GPL-3.0-or-later
// one-time fade + slide-up entrance for list items. delay scales with index
// (capped) so a list assembles gracefully instead of popping in at once.
import 'package:flutter/material.dart';

class StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggerIn({super.key, required this.index, required this.child});

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    final delay = (widget.index * 45).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) setState(() => _t = 1);
    });
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

// wrap a literal list of children so they assemble one after another
List<Widget> staggerAll(List<Widget> children, {int from = 0}) => [
  for (var i = 0; i < children.length; i++)
    StaggerIn(index: from + i, child: children[i]),
];
