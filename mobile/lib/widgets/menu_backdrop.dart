// SPDX-License-Identifier: GPL-3.0-or-later
// what sits behind every long-press menu: the page blurs and dims in one
// short fade.
import 'dart:ui';

import 'package:flutter/material.dart';

class MenuBackdrop extends StatefulWidget {
  const MenuBackdrop({super.key});

  @override
  State<MenuBackdrop> createState() => _MenuBackdropState();
}

class _MenuBackdropState extends State<MenuBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOut.transform(_c.value);
        // only the dark overlay animates: an animated blur sigma recomputes
        // the whole blur every frame and janks on weaker phones
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: Colors.black.withValues(alpha: 0.42 * t)),
        );
      },
    );
  }
}

// the menu itself: grows out of the bubble's corner with a little overshoot,
// so it reads as coming from the thing you pressed.
class MenuPop extends StatefulWidget {
  final bool fromRight;
  final Widget child;
  const MenuPop({super.key, required this.fromRight, required this.child});

  @override
  State<MenuPop> createState() => _MenuPopState();
}

class _MenuPopState extends State<MenuPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final v = _c.value.clamp(0.0, 1.0);
        // no growing when the phone asks for no movement: a fade alone
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
          return Opacity(opacity: v, child: child);
        }
        final t = Curves.easeOutBack.transform(v);
        return Opacity(
          opacity: v,
          child: Transform.scale(
            scale: 0.8 + 0.2 * t,
            alignment: widget.fromRight
                ? AlignmentDirectional.bottomEnd
                : AlignmentDirectional.bottomStart,
            child: child,
          ),
        );
      },
    );
  }
}
