// SPDX-License-Identifier: GPL-3.0-or-later
// one way to open a sheet. same surface, same corner, same dim behind it and
// the same rise, so a sheet from the chat feels like a sheet from home.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

const kSheetRadius = 20.0;

Future<T?> showHaloSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  // true: the sheet manages its own height and scrolling. false, the
  // default: the content scrolls inside a ceiling of nine tenths of the
  // screen, and the keyboard pushes it up.
  bool scroll = false,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) =>
        _SheetPull(child: scroll ? builder(ctx) : _Ceiling(builder: builder)),
    backgroundColor: HaloColors.surface2,
    barrierColor: HaloColors.ink.withValues(alpha: 0.62),
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kSheetRadius)),
    ),
    // reduced motion: no animation in or out
    sheetAnimationStyle: MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            reverseDuration: Duration(milliseconds: 200),
            reverseCurve: Curves.easeInCubic,
          ),
  );
}

// the default sheet: its content scrolls inside a ceiling of nine tenths of
// the screen, and the keyboard pushes it up
class _Ceiling extends StatelessWidget {
  final WidgetBuilder builder;
  const _Ceiling({required this.builder});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // the sheet's route takes the status bar out of its padding, so
    // the window is asked how tall that bar is
    final bar = MediaQueryData.fromView(View.of(context)).padding.top;
    // the keyboard inset is spent here, so content that pads for
    // it too (the confirm sheets) does not pad twice
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: ConstrainedBox(
          // with the keyboard up the sheet still stops below the
          // status bar, and its content scrolls
          constraints: BoxConstraints(
            maxHeight: math.min(
              mq.size.height * 0.9,
              mq.size.height - mq.viewInsets.bottom - bar - 12,
            ),
          ),
          child: SingleChildScrollView(child: builder(context)),
        ),
      ),
    );
  }
}

// flutter's sheet drags only where nothing scrolls, and the app scrolls
// every scroll view always, so a drag on a sheet moved its content and
// never the sheet. inside a sheet a scroll view scrolls only when its
// content is taller than it, and the sheet's own scroll hands the pull at
// its top to the sheet
class _SheetPull extends StatefulWidget {
  final Widget child;
  const _SheetPull({required this.child});
  @override
  State<_SheetPull> createState() => _SheetPullState();
}

// flutter's own sheet: a fling faster than this closes it, a let go below
// half its height closes it
const _flingClose = 700.0;
const _closeBelow = 0.5;

class _SheetPullState extends State<_SheetPull> {
  late final _scroll = _PullScroll(this);
  BottomSheet? _sheet;
  // this drag has moved the sheet
  bool _moved = false;

  AnimationController? get _rise {
    final s = _sheet;
    final c = s?.animationController;
    if (s == null || !s.enableDrag || c == null) return null;
    // already closing: flutter's sheet lets the drag go then too
    if (c.status == AnimationStatus.reverse) return null;
    return c;
  }

  double get _height {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 0;
  }

  bool get canPull => _rise != null && _height > 0;

  // the finger moved [dy], down positive. the sheet takes a move down
  // whole and a move up until it is back up, and returns what is left
  double take(double dy) {
    final c = _rise;
    final h = _height;
    if (c == null || h <= 0 || dy == 0 || dy < 0 && c.value >= 1) return dy;
    if (!_moved) {
      _moved = true;
      // the route follows the finger one to one while it drags
      _sheet!.onDragStart?.call(DragStartDetails());
    }
    final before = c.value;
    c.value = (before - dy / h).clamp(0.0, 1.0);
    return dy - (before - c.value) * h;
  }

  // the finger let go at [v] px/s, down positive. true when the sheet had
  // the drag and the content keeps still
  bool release(double v) {
    if (!_moved) return false;
    _moved = false;
    final s = _sheet!;
    final c = _rise;
    final h = _height;
    final end = DragEndDetails(
      velocity: Velocity(pixelsPerSecond: Offset(0, v)),
      primaryVelocity: v,
    );
    if (c == null || h <= 0) return true;
    // back up and scrolling: the content keeps its fling
    if (c.value >= 1) {
      s.onDragEnd?.call(end, isClosing: false);
      return false;
    }
    var closing = false;
    if (v > _flingClose) {
      if (c.value > 0) c.fling(velocity: -v / h);
      closing = true;
    } else if (c.value < _closeBelow) {
      if (c.value > 0) c.fling(velocity: -1);
      closing = true;
    } else {
      c.forward();
    }
    s.onDragEnd?.call(end, isClosing: closing);
    if (closing) s.onClosing();
    return true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sheet = context.findAncestorWidgetOfExactType<BottomSheet>();
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(physics: const BouncingScrollPhysics()),
      // the sheet's first vertical scroll view takes this controller
      child: PrimaryScrollController(
        controller: _scroll,
        automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
        child: widget.child,
      ),
    );
  }
}

class _PullScroll extends ScrollController {
  final _SheetPullState pull;
  _PullScroll(this.pull) : super(keepScrollOffset: false);

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _PullPosition(
    pull,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

class _PullPosition extends ScrollPositionWithSingleContext {
  final _SheetPullState pull;
  _PullPosition(
    this.pull, {
    required super.physics,
    required super.context,
    super.oldPosition,
  }) : super(keepScrollOffset: false);

  // delta is the finger's move, down positive
  @override
  void applyUserOffset(double delta) {
    if (axisDirection != AxisDirection.down || delta == 0 || !pull.canPull) {
      super.applyUserOffset(delta);
      return;
    }
    if (delta > 0) {
      // down: the content goes back to its top first, then the sheet
      final mine = math.min(delta, math.max(0.0, pixels - minScrollExtent));
      if (mine > 0) super.applyUserOffset(mine);
      if (delta > mine) pull.take(delta - mine);
    } else {
      // up: a sheet pulled down comes back up first, then the content
      final rest = pull.take(delta);
      if (rest < 0) super.applyUserOffset(rest);
    }
  }

  // a drag's end comes here with the scroll's velocity, the finger's
  // reversed
  @override
  void goBallistic(double velocity) {
    super.goBallistic(pull.release(-velocity) ? 0 : velocity);
  }
}
