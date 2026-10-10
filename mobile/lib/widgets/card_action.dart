// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart' show motionStill;
import 'press_scale.dart';
import 'swap.dart' show RiseSwap;

// an answer on a home card: a filled pill for the one the card is for, or
// quiet words beside it. each dips under the finger with a click
class CardAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  // the pill's fill; null draws quiet words in [ink]
  final Color? fill;
  final Color ink;
  final bool bold;
  // a label that changes while its action runs rises in
  final bool swap;
  const CardAction({
    super.key,
    required this.label,
    required this.onTap,
    required this.ink,
    this.fill,
    this.bold = false,
    this.swap = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final text = Text(
      label,
      key: ValueKey(label),
      style: HaloType.mono(
        size: 11.5,
        color: ink,
        weight: fill != null || bold ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    final f = fill;
    return PressScale(
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: f == null
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: text,
              )
            : AnimatedContainer(
                duration: Duration(milliseconds: still ? 0 : 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: onTap == null ? f.withValues(alpha: 0.45) : f,
                  borderRadius: BorderRadius.circular(999),
                ),
                // no movement asked for: the label just changes. an
                // animated size of no length re-dirties itself in layout
                child: still
                    ? text
                    : AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: swap ? RiseSwap(child: text) : text,
                      ),
              ),
      ),
    );
  }
}
