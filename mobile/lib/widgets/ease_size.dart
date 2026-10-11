// SPDX-License-Identifier: GPL-3.0-or-later
// a box that eases to its child's new height instead of jumping. with less
// movement it is simply the new size: an AnimatedSize given no time trips
// over its own layout
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class EaseSize extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;
  const EaseSize({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _HeldHeight(
      child: AnimatedSize(
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: alignment,
        child: child,
      ),
    );
  }
}

// an AnimatedSize answers intrinsic height with where it is going, not
// where it is. while it shrinks, a FitColumn would size the page too short
// and it runs off the bottom, so the height on screen counts too
class _HeldHeight extends SingleChildRenderObjectWidget {
  const _HeldHeight({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeldHeight();
}

class _RenderHeldHeight extends RenderProxyBox {
  double _last = 0;
  bool _recheck = false;

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(super.computeMinIntrinsicHeight(width), _last);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(super.computeMaxIntrinsicHeight(width), _last);

  @override
  void performLayout() {
    super.performLayout();
    if (size.height == _last) return;
    _last = size.height;
    // the answer given this frame was the old height: ask again once more
    if (_recheck) return;
    _recheck = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _recheck = false;
      if (attached) markNeedsLayout();
    });
  }
}
