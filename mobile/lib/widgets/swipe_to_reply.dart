// SPDX-License-Identifier: GPL-3.0-or-later
// swipe right on a bubble to reply. one widget for the 1:1 chat and the
// group chat, so they cannot drift apart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'motion.dart' show kHouseCurve, kHouseTime, motionStill;

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const SwipeToReply({super.key, required this.child, required this.onReply});
  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _armed = false;
  static const double _trigger = 56;
  static const double _max = 80;
  // built in initState, not lazily: made inside dispose for an unswiped
  // bubble, the ticker throws and the route never unmounts
  late final AnimationController _spring;
  Animation<double> _back = const AlwaysStoppedAnimation(0);

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(vsync: this, duration: kHouseTime);
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  // back to its place on the house spring, a touch past it and home; at
  // once when the phone asks for no movement
  void _settle() {
    if (motionStill(context)) {
      setState(() => _dx = 0);
      return;
    }
    _back = Tween(begin: _dx, end: 0.0).animate(
      CurvedAnimation(parent: _spring, curve: kHouseCurve),
    )..addListener(() => setState(() => _dx = _back.value));
    _spring
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    // the reply arrow sits at the start edge: a swipe away from it, to the
    // right, or to the left in a right-to-left language
    final way = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        if (_spring.isAnimating) return;
        var nx = _dx + way * d.delta.dx;
        if (nx < 0) nx = 0;
        if (nx > _trigger) nx = _trigger + (nx - _trigger) * 0.35;
        if (nx > _max) nx = _max;
        final wasArmed = _armed;
        _armed = nx >= _trigger;
        if (_armed && !wasArmed) HapticFeedback.selectionClick();
        setState(() => _dx = nx);
      },
      onHorizontalDragEnd: (_) {
        if (_armed) widget.onReply();
        _armed = false;
        _settle();
      },
      child: Stack(
        children: [
          PositionedDirectional(
            start: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress.clamp(0.0, 1.0),
                  // armed, the arrow gives a small nod so the thumb knows
                  child: AnimatedScale(
                    scale: _armed && !motionStill(context) ? 1.18 : 1,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.reply_rounded,
                      size: 20,
                      color: HaloColors.amber,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(way * _dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
