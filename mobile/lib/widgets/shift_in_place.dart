// SPDX-License-Identifier: GPL-3.0-or-later
// a list row that slides to its new place instead of jumping there. keyed
// rows keep their state across a reorder, so this widget can remember where
// it was drawn last and glide from there. positions are read inside the
// scroll content, not on screen, so scrolling never counts as a move.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ShiftInPlace extends StatefulWidget {
  final Widget child;
  final Duration duration;
  // the row's place in the list. a rebuild that keeps it costs nothing;
  // only a change of place measures and glides.
  final int index;
  const ShiftInPlace({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  State<ShiftInPlace> createState() => _ShiftInPlaceState();
}

class _ShiftInPlaceState extends State<ShiftInPlace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  double? _lastY;
  double _delta = 0;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void didUpdateWidget(ShiftInPlace old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _measure();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return;
      final vp = RenderAbstractViewport.maybeOf(box);
      final y = vp == null
          ? box.localToGlobal(Offset.zero).dy
          : vp.getOffsetToReveal(box, 0).offset;
      final last = _lastY;
      _lastY = y;
      if (last == null) return;
      // where it was, minus where it is. carry any slide still in flight
      final moved = last - y;
      if (moved.abs() < 1 || moved.abs() > 1200) return;
      _delta = moved + _delta * (1 - _c.value);
      _c.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, _delta * (1 - t)),
          child: child,
        );
      },
    );
  }
}
