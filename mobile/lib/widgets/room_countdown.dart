// SPDX-License-Identifier: GPL-3.0-or-later
// how long a burner room has left, in mono. ticks once a minute until the
// last five minutes, then once a second. calm text until an hour is left,
// amber under that, rose under five minutes. it sets no timer while the app
// is away or a page covers it, and reads the clock afresh when it is back.
import 'dart:async';
import 'package:flutter/material.dart';
import '../rooms.dart';
import '../stickers/sticker_view.dart' show AppFront;
import '../theme.dart';
import 'motion.dart' show motionStill;

class RoomCountdown extends StatefulWidget {
  final int expiresAt;
  final double size;
  final String prefix;
  const RoomCountdown({
    super.key,
    required this.expiresAt,
    this.size = 10,
    this.prefix = '',
  });

  @override
  State<RoomCountdown> createState() => _RoomCountdownState();
}

class _RoomCountdownState extends State<RoomCountdown> {
  Timer? _t;
  // false under a covering page, or off screen in a list that keeps it
  bool _seen = true;

  // a timer is set for the next change
  @visibleForTesting
  bool get ticking => _t?.isActive ?? false;

  Duration get _left => DateTime.fromMillisecondsSinceEpoch(
    widget.expiresAt,
  ).difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    AppFront.changes.addListener(_front);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final seen = TickerMode.valuesOf(context).enabled;
    if (seen == _seen && _t != null) return;
    _seen = seen;
    // a build follows this anyway
    _wake(rebuild: false);
  }

  void _front() {
    if (mounted) _wake();
  }

  // back in view: the clock may have moved on meanwhile
  void _wake({bool rebuild = true}) {
    if (_seen && AppFront.now) {
      if (rebuild) setState(() {});
      _arm();
    } else {
      _t?.cancel();
      _t = null;
    }
  }

  void _arm() {
    _t?.cancel();
    _t = null;
    final left = _left;
    if (left.isNegative || !_seen || !AppFront.now) return;
    _t = Timer(countdownTick(left), () {
      if (mounted) {
        setState(() {});
        _arm();
      }
    });
  }

  @override
  void didUpdateWidget(covariant RoomCountdown old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt) _arm();
  }

  @override
  void dispose() {
    AppFront.changes.removeListener(_front);
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final left = _left;
    final color = switch (countdownTone(left)) {
      CountdownTone.calm => HaloColors.text2,
      CountdownTone.amber => HaloColors.amber,
      CountdownTone.rose => HaloColors.rose,
    };
    final label = '${widget.prefix}${countdownLabel(left)}';
    return AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 120 : 220),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        // time running down: the new figure drops in from above
        child: still
            ? c
            : SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                    ),
                child: c,
              ),
      ),
      child: Text(
        label,
        key: ValueKey(label),
        style: HaloType.mono(size: widget.size, color: color),
      ),
    );
  }
}
