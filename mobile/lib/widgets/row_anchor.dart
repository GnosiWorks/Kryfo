// SPDX-License-Identifier: GPL-3.0-or-later
// finding a message's row in a lazy list, and landing on it.
// a lazy list only has the rows near the viewport and estimates the rest, so
// a built row says where it is, an unbuilt one is walked towards a viewport
// at a time, and once it exists the landing is corrected every frame until
// it holds still.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class RowAnchors {
  final Map<String, BuildContext> _at = {};
  BuildContext? of(String id) => _at[id];
  Iterable<String> get built => _at.keys;
}

class RowAnchor extends StatefulWidget {
  final RowAnchors anchors;
  final String id;
  final Widget child;
  const RowAnchor({
    super.key,
    required this.anchors,
    required this.id,
    required this.child,
  });
  @override
  State<RowAnchor> createState() => _RowAnchorState();
}

class _RowAnchorState extends State<RowAnchor> {
  @override
  void initState() {
    super.initState();
    widget.anchors._at[widget.id] = context;
  }

  @override
  void didUpdateWidget(RowAnchor old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || !identical(old.anchors, widget.anchors)) {
      if (identical(old.anchors._at[old.id], context)) {
        old.anchors._at.remove(old.id);
      }
    }
    widget.anchors._at[widget.id] = context;
  }

  @override
  void dispose() {
    if (identical(widget.anchors._at[widget.id], context)) {
      widget.anchors._at.remove(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// brings row [id] to the middle of the viewport. [indexOf] gives a row's
/// place in the list, oldest first, or null when it is gone; [reversed] is
/// the list's own flag. [rough] is a first guess at the offset, used once
/// when nothing built says which way to go. [done] is called when the row
/// has held still, when the person takes over the scroll, or when the row
/// cannot be found.
void landOnRow({
  required ScrollController ctrl,
  required RowAnchors anchors,
  required String id,
  required bool Function() alive,
  required int? Function(String id) indexOf,
  required bool reversed,
  required double Function() rough,
  required void Function(bool landed) done,
}) {
  var attempt = 0;
  var still = 0;
  var guessed = false;

  bool ready() =>
      ctrl.positions.length == 1 && ctrl.positions.first.hasContentDimensions;

  late final void Function() step;
  // a frame that changes nothing schedules no other; ask for one, or the
  // quiet frames being counted never come
  void next() {
    WidgetsBinding.instance.addPostFrameCallback((_) => step());
    WidgetsBinding.instance.scheduleFrame();
  }

  step = () {
    if (!alive()) return;
    if (!ready()) {
      if (++attempt > 90) return done(false);
      return next();
    }
    final pos = ctrl.positions.first;
    // a finger on the list outranks us
    if (attempt > 0 && pos.userScrollDirection != ScrollDirection.idle) {
      return done(false);
    }
    final target = indexOf(id);
    if (target == null) return done(false);
    final ctx = anchors.of(id);
    final ro = ctx == null || !ctx.mounted ? null : ctx.findRenderObject();
    if (ro != null && ro.attached) {
      try {
        final want = RenderAbstractViewport.of(ro)
            .getOffsetToReveal(ro, 0.5)
            .offset
            .clamp(pos.minScrollExtent, pos.maxScrollExtent)
            .toDouble();
        if ((want - pos.pixels).abs() > 2) {
          ctrl.jumpTo(want);
          still = 0;
        } else {
          still++;
        }
      } catch (_) {
        // the element was swapped under us; the next frame finds it again
        still = 0;
      }
      // six quiet frames: long enough for a photo near it to decode
      if (still >= 6) return done(true);
    } else {
      still = 0;
      // which way: ask the rows that do exist
      int? lo, hi;
      for (final b in anchors.built) {
        final i = indexOf(b);
        if (i == null) continue;
        lo = lo == null || i < lo ? i : lo;
        hi = hi == null || i > hi ? i : hi;
      }
      double to;
      if (!guessed && (lo == null || (target - lo).abs() > 60)) {
        // far away or nothing to go by: one guess, then walk from there
        guessed = true;
        to = rough();
      } else {
        final older = lo == null || target < lo;
        final up = older == reversed; // towards a larger offset
        to = pos.pixels + (up ? 1 : -1) * pos.viewportDimension * 0.85;
      }
      ctrl.jumpTo(
        to.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble(),
      );
    }
    if (++attempt > 90) return done(false);
    next();
  };

  next();
}

/// a scroll controller whose offset can be moved along with the rows under
/// it, for [holdRowsInView]
class HoldScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _HoldPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _HoldPosition extends ScrollPositionWithSingleContext {
  _HoldPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  // the rows moved, not the reader: a drag goes on from here, a fling
  // starts again from here at the speed it had, and listeners hear of it
  void shiftTo(double to) {
    correctPixels(to);
    activity?.resetActivity();
    notifyListeners();
  }
}

/// keeps the rows on screen where they are while rows are added out of
/// view. call it before the change. a lazy list places its rows by index,
/// so rows added at the start push the rest along by their height; the
/// offset is put back after the next layout. with a [HoldScrollController]
/// this holds through a fling too; an animation to a set place keeps its
/// target
void holdRowsInView({
  required ScrollController ctrl,
  required RowAnchors anchors,
  required bool Function() alive,
}) {
  if (ctrl.positions.length != 1) return;
  final pixels = ctrl.positions.first.pixels;
  // the built row nearest the viewport's edge: they all move together
  String? id;
  double? was;
  for (final k in anchors.built) {
    final at = _offsetOf(anchors, k);
    if (at == null) continue;
    if (was == null || (at - pixels).abs() < (was - pixels).abs()) {
      id = k;
      was = at;
    }
  }
  if (id == null || was == null) return;
  final key = id;
  final before = was;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!alive() || ctrl.positions.length != 1) return;
    final now = _offsetOf(anchors, key);
    if (now == null) return;
    final moved = now - before;
    if (moved.abs() < 0.5) return;
    final pos = ctrl.positions.first;
    final to = (pos.pixels + moved)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if (pos is _HoldPosition) {
      pos.shiftTo(to);
      return;
    }
    // without ending a drag under way: the reader did not scroll, the rows did
    pos.correctPixels(to);
    final ro = anchors.of(key)?.findRenderObject();
    if (ro != null && ro.attached) {
      (RenderAbstractViewport.of(ro) as RenderObject).markNeedsLayout();
    }
  });
}

// the scroll offset that puts the row at the viewport's leading edge
double? _offsetOf(RowAnchors anchors, String id) {
  final ctx = anchors.of(id);
  final ro = ctx == null || !ctx.mounted ? null : ctx.findRenderObject();
  if (ro == null || !ro.attached) return null;
  try {
    return RenderAbstractViewport.of(ro).getOffsetToReveal(ro, 0).offset;
  } catch (_) {
    return null;
  }
}
