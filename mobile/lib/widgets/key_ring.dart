// SPDX-License-Identifier: GPL-3.0-or-later
// keyboard reach for the house's own buttons: tab finds them, enter and
// space press them, and a ring shows which one has focus. the ring shows
// only while a keyboard is in use, so touch looks as it did.
import 'package:flutter/material.dart';

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
  const KeyRing({
    super.key,
    required this.child,
    required this.onActivate,
    this.radius = const BorderRadius.all(Radius.circular(12)),
    this.circle = false,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<KeyRing> createState() => _KeyRingState();
}

class _KeyRingState extends State<KeyRing> {
  bool _ring = false;

  @override
  Widget build(BuildContext context) {
    final go = widget.onActivate;
    return FocusableActionDetector(
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
                    shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
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
  }
}
