// SPDX-License-Identifier: GPL-3.0-or-later
// keyboard reach for the house's own buttons: tab finds them, enter and
// space press them, and a ring shows which one has focus. the ring shows
// only while a keyboard is in use, so touch looks as it did. on a computer
// the mouse gets a hand, a soft wash while it is over one, and the button's
// words as a tooltip.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerEnterEvent;
import 'package:flutter/material.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../theme.dart';

class KeyRing extends StatefulWidget {
  final Widget child;
  // what enter and space do. null: not reachable by keyboard
  final VoidCallback? onActivate;
  // the ring's corners, or a circle round the child
  final BorderRadius radius;
  final bool circle;
  final bool autofocus;
  final FocusNode? focusNode;
  // a computer: the hand and the wash. null: while it can be pressed
  final bool? pointer;
  // a computer: shown when the mouse rests on it
  final String? tooltip;
  const KeyRing({
    super.key,
    required this.child,
    required this.onActivate,
    this.radius = const BorderRadius.all(Radius.circular(12)),
    this.circle = false,
    this.autofocus = false,
    this.focusNode,
    this.pointer,
    this.tooltip,
  });

  @override
  State<KeyRing> createState() => _KeyRingState();
}

class _KeyRingState extends State<KeyRing> {
  bool _ring = false;
  bool _hover = false;

  void _hovered(bool v) {
    if (v != _hover) setState(() => _hover = v);
  }

  @override
  Widget build(BuildContext context) {
    final go = widget.onActivate;
    final hand = onDesktop && (widget.pointer ?? go != null);
    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    Widget w = FocusableActionDetector(
      enabled: go != null,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      // the button's own node says what it is; focus adds nothing to hear
      includeFocusSemantics: false,
      onShowFocusHighlight: (v) {
        if (v != _ring) setState(() => _ring = v);
      },
      actions: {
        if (go != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              go();
              return null;
            },
          ),
      },
      // passthrough: the child is laid out exactly as without the ring
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (hand)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration:
                      MediaQuery.maybeDisableAnimationsOf(context) ?? false
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: DecoratedBox(
                    key: const ValueKey('hover wash'),
                    decoration: BoxDecoration(
                      shape: shape,
                      borderRadius: widget.circle ? null : widget.radius,
                      color: hoverWash(),
                    ),
                  ),
                ),
              ),
            ),
          if (_ring && go != null)
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('key ring'),
                  decoration: BoxDecoration(
                    shape: shape,
                    borderRadius: widget.circle
                        ? null
                        : widget.radius +
                              const BorderRadius.all(Radius.circular(3)),
                    border: Border.all(color: HaloColors.amber, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!onDesktop) return w;
    w = MouseRegion(
      cursor: hand ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: hand ? (_) => _hovered(true) : null,
      onExit: hand ? (_) => _hovered(false) : null,
      child: w,
    );
    final tip = widget.tooltip;
    if (tip == null || tip.isEmpty) return w;
    return HoverTip(message: tip, child: w);
  }
}

/// the hover wash: the words' own colour, faint, so it lifts on dark and
/// shades on light and words on it keep their contrast
Color hoverWash() => HaloColors.text.withValues(alpha: 0.07);

/// a computer's tooltip in the house colours: the words' colour as its
/// ground, the page's as its words, under the button or over it where the
/// window ends. it shows on a resting mouse, on a button small enough to
/// say nothing itself: a row's words are its own. it adds nothing to the
/// tree a screen reader hears; the button's label says it already
class HoverTip extends StatefulWidget {
  final String message;
  final Widget child;
  const HoverTip({super.key, required this.message, required this.child});

  /// the widest and tallest a button with a tooltip gets
  static const most = 96.0;

  static const wait = Duration(milliseconds: 500);

  @override
  State<HoverTip> createState() => _HoverTipState();
}

class _HoverTipState extends State<HoverTip> {
  Timer? _wait;
  OverlayEntry? _tip;

  void _enter(PointerEnterEvent _) {
    _wait?.cancel();
    _wait = Timer(HoverTip.wait, _show);
  }

  void _hide() {
    _wait?.cancel();
    _wait = null;
    _tip?.remove();
    _tip?.dispose();
    _tip = null;
  }

  void _show() {
    if (!mounted || _tip != null) return;
    final box = context.findRenderObject();
    final overlay = Overlay.maybeOf(context);
    if (box is! RenderBox || !box.attached || overlay == null) return;
    if (box.size.width > HoverTip.most || box.size.height > HoverTip.most) {
      return;
    }
    final ground = overlay.context.findRenderObject();
    if (ground is! RenderBox) return;
    final rect = box.localToGlobal(Offset.zero, ancestor: ground) & box.size;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dir = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _tip = OverlayEntry(
      builder: (_) =>
          _TipBox(rect: rect, message: widget.message, still: still, dir: dir),
    );
    overlay.insert(_tip!);
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: _enter,
    onExit: (_) => _hide(),
    // a press says the button was found: the tip goes
    child: Listener(onPointerDown: (_) => _hide(), child: widget.child),
  );
}

class _TipBox extends StatelessWidget {
  final Rect rect;
  final String message;
  final bool still;
  final TextDirection dir;
  const _TipBox({
    required this.rect,
    required this.message,
    required this.still,
    required this.dir,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: CustomSingleChildLayout(
        delegate: _TipPlace(rect),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: still ? Duration.zero : const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          // its own ground, as every overlay's text has
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              key: const ValueKey('hover tip'),
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HaloColors.text,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(
                message,
                textDirection: dir,
                style: HaloType.sans(size: 12.5, color: HaloColors.surface),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// under the button, centred on it, over it where the window ends below
class _TipPlace extends SingleChildLayoutDelegate {
  final Rect rect;
  const _TipPlace(this.rect);

  static const gap = 6.0;
  static const edge = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => c.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    var y = rect.bottom + gap;
    if (y + child.height > size.height - edge) {
      y = rect.top - gap - child.height;
    }
    final x = (rect.center.dx - child.width / 2)
        .clamp(edge, math.max(edge, size.width - edge - child.width))
        .toDouble();
    return Offset(x, math.max(edge, y));
  }

  @override
  bool shouldRelayout(_TipPlace old) => old.rect != rect;
}
