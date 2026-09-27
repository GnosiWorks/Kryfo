// SPDX-License-Identifier: GPL-3.0-or-later
// an amber count that pops in, rolls to its new number and pops away at
// zero, so a message arriving while you look is never a silent swap. still
// on its first build, and only fades when the phone asks for no movement.
import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

class CountBadge extends StatefulWidget {
  final int count;
  // above this it reads as the cap and a plus
  final int cap;
  final double fontSize;
  final double minWidth;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? ink;
  // a ring in the colour behind, so it reads as cut out of what it sits on
  final Color? ring;
  final String Function(int n)? format;
  // room before it, taken only while it shows
  final double lead;
  const CountBadge({
    super.key,
    required this.count,
    this.cap = 99,
    this.fontSize = 10,
    this.minWidth = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
    this.color,
    this.ink,
    this.ring,
    this.format,
    this.lead = 0,
  });

  @override
  State<CountBadge> createState() => _CountBadgeState();
}

class _CountBadgeState extends State<CountBadge> {
  // which way the digits roll: up for more, down for fewer
  bool _up = true;

  @override
  void didUpdateWidget(CountBadge old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _up = widget.count > old.count;
  }

  String _text(int n) {
    final f = widget.format;
    if (f != null) return f(n);
    return n > widget.cap ? '${widget.cap}+' : '$n';
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final n = widget.count;
    final on = n > 0;
    final text = _text(n);
    final digits = AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 120 : 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      transitionBuilder: (child, a) {
        if (still) return FadeTransition(opacity: a, child: child);
        final incoming = child.key == ValueKey(text);
        final from = (incoming == _up) ? 0.9 : -0.9;
        return ClipRect(
          child: SlideTransition(
            position: Tween(
              begin: Offset(0, from),
              end: Offset.zero,
            ).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        maxLines: 1,
        style: HaloType.mono(
          size: widget.fontSize,
          weight: FontWeight.w600,
          color: widget.ink ?? HaloColors.onAmber,
          letter: 0,
        ).copyWith(height: 1.25),
      ),
    );
    final badge = Container(
      key: const ValueKey('badge'),
      margin: EdgeInsetsDirectional.only(start: widget.lead),
      padding: widget.padding,
      constraints: BoxConstraints(minWidth: widget.minWidth),
      decoration: BoxDecoration(
        color: widget.color ?? HaloColors.amber,
        borderRadius: BorderRadius.circular(999),
        border: widget.ring == null
            ? null
            : Border.all(color: widget.ring!, width: 1.5),
      ),
      // an AnimatedSize given no time trips over its own layout: still, it
      // is left out
      child: still
          ? digits
          : AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              child: digits,
            ),
    );
    return AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 120 : 260),
      reverseDuration: Duration(milliseconds: still ? 120 : 160),
      transitionBuilder: (child, a) {
        if (still) return FadeTransition(opacity: a, child: child);
        return FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(
                parent: a,
                curve: kHouseCurve,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
            child: child,
          ),
        );
      },
      child: on ? badge : const SizedBox.shrink(key: ValueKey('none')),
    );
  }
}
