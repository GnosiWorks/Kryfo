// SPDX-License-Identifier: GPL-3.0-or-later
// a soft amber ring that breathes outward behind whatever sits in it. the
// app quietly waiting, used by the empty places so they match.
import 'package:flutter/material.dart';

import '../theme.dart';

class BreathingRing extends StatefulWidget {
  final Widget child;
  final double size;
  final double core;
  const BreathingRing({
    super.key,
    required this.child,
    this.size = 88,
    this.core = 56,
  });
  @override
  State<BreathingRing> createState() => _BreathingRingState();
}

class _BreathingRingState extends State<BreathingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grow = widget.size - widget.core;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Container(
                width: widget.core + grow * t,
                height: widget.core + grow * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HaloColors.amber.withValues(alpha: 0.10 * (1 - t)),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}
