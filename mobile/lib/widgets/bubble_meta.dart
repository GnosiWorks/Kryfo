// SPDX-License-Identifier: GPL-3.0-or-later
// a bubble's time and tick at the end of its last line of words when they
// fit there, else on a line of their own at the end. the words are measured
// as laid out, so it holds at any text size and in either direction
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// marks the words whose last line the meta may share. anything below them
// in the body (a link card, a place) sends the meta to its own line
class MetaAnchor extends SingleChildRenderObjectWidget {
  const MetaAnchor({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMetaAnchor();
}

class _RenderMetaAnchor extends RenderProxyBox {}

// the body and the meta. [textDirection]: the words' own direction, which
// decides the end the meta sits at
class MetaFlow extends MultiChildRenderObjectWidget {
  final TextDirection? textDirection;
  // room between the last word and the meta
  final double gap;
  // room above the meta when it takes its own line
  final double lineGap;
  MetaFlow({
    super.key,
    required Widget body,
    required Widget meta,
    this.textDirection,
    this.gap = 6,
    this.lineGap = 3,
  }) : super(children: [body, meta]);

  @override
  RenderMetaFlow createRenderObject(BuildContext context) => RenderMetaFlow(
    textDirection: textDirection ?? Directionality.of(context),
    gap: gap,
    lineGap: lineGap,
  );

  @override
  void updateRenderObject(BuildContext context, RenderMetaFlow renderObject) =>
      renderObject
        ..textDirection = textDirection ?? Directionality.of(context)
        ..gap = gap
        ..lineGap = lineGap;
}

class _FlowData extends ContainerBoxParentData<RenderBox> {}

class RenderMetaFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FlowData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FlowData> {
  RenderMetaFlow({
    required TextDirection textDirection,
    required double gap,
    required double lineGap,
  }) : _dir = textDirection,
       _gap = gap,
       _lineGap = lineGap;

  TextDirection _dir;
  set textDirection(TextDirection v) {
    if (v == _dir) return;
    _dir = v;
    markNeedsLayout();
  }

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  double _lineGap;
  set lineGap(double v) {
    if (v == _lineGap) return;
    _lineGap = v;
    markNeedsLayout();
  }

  // whether the last layout put the meta on the last line, for tests
  bool inline = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FlowData) child.parentData = _FlowData();
  }

  RenderBox get _body => firstChild!;
  RenderBox get _meta => childAfter(firstChild!)!;

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _body.getMinIntrinsicWidth(height),
    _meta.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final m = _meta.getMaxIntrinsicWidth(height);
    final b = _body.getMaxIntrinsicWidth(height);
    return m <= 0 ? b : b + _gap + m;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _body.getMinIntrinsicHeight(width) + _meta.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _body.getMaxIntrinsicHeight(width) +
      _lineGap +
      _meta.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = constraints.loosen();
    final b = _body.getDryLayout(c);
    final m = _meta.getDryLayout(c);
    if (m.isEmpty) return constraints.constrain(b);
    return constraints.constrain(
      Size(math.max(b.width, m.width), b.height + _lineGap + m.height),
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void performLayout() {
    final c = constraints.loosen();
    final body = _body, meta = _meta;
    meta.layout(c, parentUsesSize: true);
    body.layout(c, parentUsesSize: true);
    final bs = body.size, ms = meta.size;
    final bodyAt = body.parentData! as _FlowData;
    final metaAt = meta.parentData! as _FlowData;
    final ltr = _dir == TextDirection.ltr;
    inline = false;
    if (ms.isEmpty) {
      size = constraints.constrain(bs);
      bodyAt.offset = Offset.zero;
      metaAt.offset = ltr
          ? Offset(size.width - ms.width, size.height)
          : Offset(0, size.height);
      return;
    }
    final last = lastLineOf(body);
    if (last != null && (bs.height - last.bottom).abs() <= 2) {
      final need = ltr
          ? last.right + _gap + ms.width
          : (bs.width - last.left) + _gap + ms.width;
      if (need <= c.maxWidth + 0.5) {
        inline = true;
        final w = math.max(bs.width, need);
        final h = math.max(bs.height, ms.height);
        size = constraints.constrain(Size(w, h));
        bodyAt.offset = Offset(ltr ? 0 : size.width - bs.width, h - bs.height);
        metaAt.offset = Offset(
          ltr ? size.width - ms.width : 0,
          // level with the last line's foot
          h - ms.height,
        );
        return;
      }
    }
    final w = math.max(bs.width, ms.width);
    // nothing above it, nothing to keep apart from
    final gapV = bs.height > 0 ? _lineGap : 0.0;
    size = constraints.constrain(Size(w, bs.height + gapV + ms.height));
    bodyAt.offset = Offset(ltr ? 0 : size.width - bs.width, 0);
    metaAt.offset = Offset(ltr ? size.width - ms.width : 0, bs.height + gapV);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

// the last line of the anchored words in [body], in body coordinates, or
// null when there are none
Rect? lastLineOf(RenderBox body) {
  _RenderMetaAnchor? anchor;
  void findAnchor(RenderObject o) {
    if (anchor != null) return;
    if (o is _RenderMetaAnchor) {
      anchor = o;
      return;
    }
    o.visitChildren(findAnchor);
  }

  findAnchor(body);
  if (anchor == null || !anchor!.hasSize) return null;
  RenderParagraph? para;
  void findPara(RenderObject o) {
    if (o is RenderParagraph) para = o;
    o.visitChildren(findPara);
  }

  findPara(anchor!);
  final p = para;
  if (p == null || !p.hasSize) return null;
  final len = p.text.toPlainText(includeSemanticsLabels: false).length;
  if (len == 0) return null;
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: len),
  );
  if (boxes.isEmpty) return null;
  var bottom = boxes.first.bottom;
  var top = boxes.first.top;
  for (final b in boxes) {
    if (b.bottom > bottom) {
      bottom = b.bottom;
      top = b.top;
    }
  }
  double? left, right;
  for (final b in boxes) {
    if (b.bottom <= top + 1) continue;
    left = left == null ? b.left : math.min(left, b.left);
    right = right == null ? b.right : math.max(right, b.right);
  }
  if (left == null || right == null) return null;
  // the paragraph's own foot, not the box's: a line of emoji stands taller
  final foot = math.max(bottom, p.textSize.height);
  final m = p.getTransformTo(body);
  final tl = MatrixUtils.transformPoint(m, Offset(left, top));
  final br = MatrixUtils.transformPoint(m, Offset(right, foot));
  return Rect.fromPoints(tl, br);
}
