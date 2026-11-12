// SPDX-License-Identifier: GPL-3.0-or-later
// a file's preview in a chat bubble reaches the bubble's edges, as a photo
// does: no margin of bubble colour around it, the bubble's own corners
// clip it. the bubble says how far its padding reaches; the preview draws
// that much wider and, when it is the first thing in the bubble, that much
// higher. elsewhere (the files tab) nothing is set and previews keep their
// own rounded card
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class PreviewBleed extends InheritedWidget {
  // the bubble's padding at its start, end and top
  final double side;
  final double top;
  const PreviewBleed({
    super.key,
    required this.side,
    required this.top,
    required super.child,
  });

  static PreviewBleed? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreviewBleed>();

  /// the same sides, no top: for what is not first in its bubble
  /// with [keep], as it was. always the same tree, so a row that moves
  /// up keeps its state
  static Widget sidesOnly(
    BuildContext context,
    Widget child, {
    bool keep = false,
  }) {
    final b = of(context);
    if (b == null) return child;
    return PreviewBleed(side: b.side, top: keep ? b.top : 0, child: child);
  }

  @override
  bool updateShouldNotify(PreviewBleed old) =>
      old.side != side || old.top != top;
}

/// the corners a preview rounds itself: none inside a bubble that clips it
BorderRadius previewRadius(BuildContext context) =>
    PreviewBleed.of(context) == null
    ? BorderRadius.circular(12)
    : BorderRadius.zero;

/// [preview] out to the bubble's edges, when it sits in one
Widget bleedPreview(BuildContext context, Widget preview) {
  final b = PreviewBleed.of(context);
  if (b == null) return preview;
  return _Bleed(side: b.side, top: b.top, child: preview);
}

class _Bleed extends SingleChildRenderObjectWidget {
  final double side;
  final double top;
  const _Bleed({required this.side, required this.top, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBleed(side, top);

  @override
  void updateRenderObject(BuildContext context, _RenderBleed r) {
    r
      ..side = side
      ..top = top;
  }
}

// laid out as wide as it may be plus the padding on both sides, placed
// that far out, and as tall as it is less what it reaches up. it measures
// as its child does, so the bubble is no wider for it
class _RenderBleed extends RenderShiftedBox {
  _RenderBleed(this._side, this._top) : super(null);

  double _side;
  set side(double v) {
    if (v == _side) return;
    _side = v;
    markNeedsLayout();
  }

  double _top;
  set top(double v) {
    if (v == _top) return;
    _top = v;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      math0((child?.getMinIntrinsicHeight(width + _side * 2) ?? 0) - _top);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math0((child?.getMaxIntrinsicHeight(width + _side * 2) ?? 0) - _top);

  static double math0(double v) => v < 0 ? 0 : v;

  BoxConstraints _inner(BoxConstraints c) {
    final w = c.hasBoundedWidth ? c.maxWidth : c.minWidth;
    return BoxConstraints(
      minWidth: w + _side * 2,
      maxWidth: w + _side * 2,
      maxHeight: c.maxHeight + _top,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    final s = c.getDryLayout(_inner(constraints));
    return constraints.constrain(
      Size(s.width - _side * 2, math0(s.height - _top)),
    );
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(_inner(constraints), parentUsesSize: true);
    (c.parentData! as BoxParentData).offset = Offset(-_side, -_top);
    size = constraints.constrain(
      Size(c.size.width - _side * 2, math0(c.size.height - _top)),
    );
  }

  // the part reaching past this box still takes taps
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// the widest a file's card draws: the bubble around a file keeps to it,
/// so its preview always meets both edges
double fileCardMost(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) > 12 ? 320 : 260;

/// a bubble's content around a file: its previews reach the bubble's
/// edges ([side], and [above] when [top]: nothing sits above the file)
Widget fileBubbleFrame(
  BuildContext context, {
  required bool on,
  required bool top,
  required Widget child,
  double side = 14,
  double above = 12,
}) {
  if (!on) return child;
  return PreviewBleed(
    side: side,
    top: top ? above : 0,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: fileCardMost(context)),
      child: child,
    ),
  );
}

/// a bubble's IntrinsicWidth, framed for a file when [file] (fileBubbleFrame)
class BubbleWidth extends StatelessWidget {
  final bool file;
  final bool top;
  final double side;
  final double above;
  final Widget child;
  const BubbleWidth({
    super.key,
    required this.file,
    required this.top,
    required this.child,
    this.side = 14,
    this.above = 12,
  });

  @override
  Widget build(BuildContext context) => fileBubbleFrame(
    context,
    on: file,
    top: top,
    side: side,
    above: above,
    child: IntrinsicWidth(child: child),
  );
}
