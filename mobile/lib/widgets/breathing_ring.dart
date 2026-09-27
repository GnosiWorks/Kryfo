// SPDX-License-Identifier: GPL-3.0-or-later
// a soft amber ring breathing behind its child, shared by the empty states so
// they match
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
  // 1 is a ring grown out and gone: where it rests
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
    value: 1,
  );
  bool _breathed = false;

  // three breaths as it comes in, then it rests: an open empty page must not
  // keep drawing. still with less movement
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_breathed) {
      _breathed = true;
      _pulse.value = 0;
      _pulse.repeat(count: 3).whenComplete(() {
        if (mounted) _pulse.value = 1;
      });
    }
  }

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
