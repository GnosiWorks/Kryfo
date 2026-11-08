// SPDX-License-Identifier: GPL-3.0-or-later
// shared press-scale wrapper: shrinks a little on tap-down.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import 'key_ring.dart';

class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  // what a screen reader calls it. null leaves the child's own words
  final String? label;
  // the keyboard focus ring's corners
  final BorderRadius ring;
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.haptic = true,
    this.label,
    this.ring = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if ((widget.onTap ?? widget.onLongPress) != null && _down != v) {
      setState(() => _down = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    // the whole box takes the tap, like an ink well, a row's empty end too
    final tap = widget.onTap;
    final g = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      // a right click on a computer is the hold
      onSecondaryTap: onDesktop ? widget.onLongPress : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
    final w = KeyRing(
      onActivate: tap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              tap();
            },
      radius: widget.ring,
      onMenu: widget.onLongPress,
      pointer: (widget.onTap ?? widget.onLongPress) != null,
      tooltip: widget.label,
      child: g,
    );
    if (widget.label == null) return w;
    // its own node: merged, a button over a page takes the page's whole
    // rect and a tap on its centre lands on the page
    return Semantics(
      container: true,
      label: widget.label,
      button: true,
      child: w,
    );
  }
}
