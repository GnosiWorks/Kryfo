// SPDX-License-Identifier: GPL-3.0-or-later
// a column for a whole screen: on a tall phone a spacer still pushes the
// button to the bottom, on a short one or with a large display zoom the page
// scrolls instead of dropping the button under the navigation bar.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart' show HaloColors;

class FitColumn extends StatefulWidget {
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
  State<FitColumn> createState() => _FitColumnState();
}

// the bottom edge fades out
const _edge = 48.0;

class _FitColumnState extends State<FitColumn> {
  // part of the page sits below the fold: the edge fades and an arrow says
  // there is more, so a card under it is not taken for missing
  bool _more = false;

  bool _metrics(ScrollMetrics m) {
    final more = m.extentAfter > 1;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          // always in the tree, so the scroll keeps its place when the
          // fade comes and goes; it only draws a layer while on
          _EdgeFade(
            on: _more,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => n.depth == 0 && _metrics(n.metrics),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) => n.depth == 0 && _metrics(n.metrics),
                child: SingleChildScrollView(
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // a scaffold's body is loose across, and a column left
                      // to it is only as wide as its widest line, at the
                      // start edge: its centred lines then sit off the
                      // middle of the screen
                      minWidth: c.hasBoundedWidth
                          ? math.max(0, c.maxWidth - padding.horizontal)
                          : 0,
                      minHeight: (c.maxHeight - padding.vertical).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: widget.crossAxisAlignment,
                        children: widget.children,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // only a sign: taps go to the page under it, a reader scrolls
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 2,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedOpacity(
                  key: const ValueKey('fit-more'),
                  opacity: _more ? 1 : 0,
                  duration: Duration(milliseconds: still ? 0 : 180),
                  child: Center(
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      color: HaloColors.amberText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// the bottom edge fades out while on, and the page paints plainly otherwise
class _EdgeFade extends SingleChildRenderObjectWidget {
  final bool on;
  const _EdgeFade({required this.on, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEdgeFade(on);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderEdgeFade).on = on;
  }
}

class _RenderEdgeFade extends RenderProxyBox {
  _RenderEdgeFade(this._on);

  bool _on;
  set on(bool v) {
    if (v == _on) return;
    _on = v;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _on;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_on || child == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final r = offset & size;
    final from = math.max(1 - _edge / math.max(size.height, 1), 0.5);
    final mask = (layer as ShaderMaskLayer?) ?? ShaderMaskLayer();
    mask
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
        stops: [0, from, 1],
      ).createShader(Offset.zero & size)
      ..maskRect = r
      ..blendMode = BlendMode.dstIn;
    layer = mask;
    context.pushLayer(mask, super.paint, offset);
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
