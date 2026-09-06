// SPDX-License-Identifier: GPL-3.0-or-later
// swipe right on a bubble to reply. the reply icon peeks from the left and
// haptics fire when you cross the trigger. one widget for the 1:1 chat and
// the group chat, so they cannot drift apart again.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

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
  // built in initState, not on first use: a bubble nobody swiped would
  // otherwise create this inside dispose, and a ticker made that late
  // throws, which stops the whole route from unmounting.
  late final AnimationController _spring;
  Animation<double> _back = const AlwaysStoppedAnimation(0);

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _settle() {
    _back = Tween(begin: _dx, end: 0.0).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    )..addListener(() => setState(() => _dx = _back.value));
    _spring
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        if (_spring.isAnimating) return;
        var nx = _dx + d.delta.dx;
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
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Icon(
                    Icons.reply_rounded,
                    size: 20,
                    color: HaloColors.amber,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}
