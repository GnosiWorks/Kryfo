// SPDX-License-Identifier: GPL-3.0-or-later
// a screen that has had its turn fades out over the one that follows. the
// next one is built under it from the first frame and stays where it is
// once the fade is done, so it is never made twice. with less movement it
// is a plain cut.
import 'package:flutter/material.dart';

import 'motion.dart';

class FadeOver extends StatefulWidget {
  static const duration = Duration(milliseconds: 360);

  /// the screen that stays
  final Widget child;

  /// the screen going out. each new one fades once, then is let go
  final Widget? leaving;

  const FadeOver({super.key, required this.child, this.leaving});

  @override
  State<FadeOver> createState() => _FadeOverState();
}

class _FadeOverState extends State<FadeOver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: FadeOver.duration,
  )..addStatusListener(_done);
  late final _shown = ReverseAnimation(
    CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
  );
  Widget? _over;

  @override
  void initState() {
    super.initState();
    _take(widget.leaving);
  }

  @override
  void didUpdateWidget(FadeOver old) {
    super.didUpdateWidget(old);
    if (!identical(old.leaving, widget.leaving)) _take(widget.leaving);
  }

  void _take(Widget? w) {
    _over = w;
    if (w != null) _c.forward(from: 0);
  }

  void _done(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() => _over = null);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final over = motionStill(context) ? null : _over;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (over != null)
          IgnorePointer(
            child: ExcludeSemantics(
              child: FadeTransition(opacity: _shown, child: over),
            ),
          ),
      ],
    );
  }
}
