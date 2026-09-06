// SPDX-License-Identifier: GPL-3.0-or-later
// how long a burner room has left, in mono. ticks once a minute until the
// last five minutes, then once a second. calm text until an hour is left,
// amber under that, rose under five minutes.
import 'dart:async';
import 'package:flutter/material.dart';
import '../rooms.dart';
import '../theme.dart';

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

  Duration get _left => DateTime.fromMillisecondsSinceEpoch(
    widget.expiresAt,
  ).difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _t?.cancel();
    final left = _left;
    if (left.isNegative) return;
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
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final color = switch (countdownTone(left)) {
      CountdownTone.calm => HaloColors.text2,
      CountdownTone.amber => HaloColors.amber,
      CountdownTone.rose => HaloColors.rose,
    };
    final label = '${widget.prefix}${countdownLabel(left)}';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
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
