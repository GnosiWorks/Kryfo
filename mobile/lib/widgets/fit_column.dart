// SPDX-License-Identifier: GPL-3.0-or-later
// a column for a whole screen: on a tall phone a spacer still pushes the
// button to the bottom, on a short one or with a large display zoom the page
// scrolls instead of dropping the button under the navigation bar.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class FitColumn extends StatelessWidget {
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;
  const FitColumn({
    super.key,
    this.padding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (c.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

// a fixed width for a child of FitColumn. a SizedBox measures its child at
// the column's full width in the intrinsic pass, so wrapped text comes out
// shorter than it lays out and the page overflows instead of scrolling
class FitWidth extends SingleChildRenderObjectWidget {
  final double width;
  const FitWidth({super.key, required this.width, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFitWidth(width);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderFitWidth).width = width;
  }
}

class _RenderFitWidth extends RenderConstrainedBox {
  _RenderFitWidth(double width)
    : super(additionalConstraints: BoxConstraints.tightFor(width: width));

  set width(double w) =>
      additionalConstraints = BoxConstraints.tightFor(width: w);

  double _narrow(double w) => math.min(w, additionalConstraints.maxWidth);

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(_narrow(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(_narrow(width));
}
