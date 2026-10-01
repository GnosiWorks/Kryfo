// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart' show motionStill;
import 'press_scale.dart';
import 'swap.dart';

class HaloPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  // working on it: stays lit but takes no second tap
  final bool busy;
  // what the label says, when its words change within one state (a
  // percent): a new phase rises in, the same one updates in place
  final String? phase;
  const HaloPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final on = onTap != null || busy;
    return PressScale(
      label: label,
      onTap: busy ? null : onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: motionStill(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? HaloColors.amber : HaloColors.surface3,
          borderRadius: BorderRadius.circular(13),
        ),
        // a label that changes in place (claim, claiming) rises in
        child: ExcludeSemantics(
          child: RiseSwap(
            alignment: Alignment.center,
            child: Text(
              label,
              key: ValueKey(phase ?? label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.sans(
                size: 14,
                weight: FontWeight.w600,
                color: on ? HaloColors.onAmber : HaloColors.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HaloGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool quiet;
  const HaloGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: label,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: quiet
              ? Border.all(color: HaloColors.line)
              : Border.all(color: HaloColors.amber, width: 1),
        ),
        child: ExcludeSemantics(
          child: RiseSwap(
            alignment: Alignment.center,
            child: Text(
              label,
              key: ValueKey(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: quiet
                  ? HaloType.sans(size: 14, color: HaloColors.text2)
                  : HaloType.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: HaloColors.amber,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
