// SPDX-License-Identifier: GPL-3.0-or-later
// the toggle: an amber pill and a thumb that slides with a little overshoot,
// to match the rest of the app rather than Material.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'motion.dart' show motionStill;

class HaloSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const HaloSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = value;
    final enabled = onChanged != null;
    final still = motionStill(context);
    final flip = enabled
        ? () {
            HapticFeedback.selectionClick();
            onChanged!(!on);
          }
        : null;
    // a switch to a screen reader. a row around it wraps itself in
    // MergeSemantics so its title and line name this node
    return Semantics(
      toggled: on,
      enabled: enabled,
      onTap: flip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: flip,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: on ? HaloColors.amber : HaloColors.surface3,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: on ? HaloColors.amber : HaloColors.line2,
                width: 0.6,
              ),
            ),
            child: AnimatedAlign(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              alignment: on
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? HaloColors.onAmber : HaloColors.text3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
