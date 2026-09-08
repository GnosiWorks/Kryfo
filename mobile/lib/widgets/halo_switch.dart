// SPDX-License-Identifier: GPL-3.0-or-later
// the toggle. a pill that fills amber and a thumb that slides with a little
// overshoot, so a setting flipping feels like the rest of the app and not
// like Material.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class HaloSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const HaloSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = value;
    final enabled = onChanged != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged!(!on);
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
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
    );
  }
}
