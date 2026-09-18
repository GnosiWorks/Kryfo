// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';
import 'press_scale.dart';

class HaloPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const HaloPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return PressScale(
      label: label,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? HaloColors.amber : HaloColors.surface3,
          borderRadius: BorderRadius.circular(13),
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            style: HaloType.sans(
              size: 14,
              weight: FontWeight.w600,
              color: on ? HaloColors.onAmber : HaloColors.text3,
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
          child: Text(
            label,
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
    );
  }
}
