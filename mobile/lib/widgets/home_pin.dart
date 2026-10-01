// SPDX-License-Identifier: GPL-3.0-or-later
// one of the cards pinned over the chat list: requests, the support inbox,
// the archive. a tinted tile, a title with a line under it, and something
// at the end, all three the same shape, dipping under the finger alike
import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart' show motionStill;
import 'press_scale.dart';

class HomePin extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  // beside the title: a dot that breathes while someone waits
  final Widget? mark;
  final Widget? trailing;
  // an amber edge while it holds something new
  final bool lit;
  final VoidCallback onTap;
  const HomePin({
    super.key,
    required this.icon,
    required this.title,
    required this.line,
    required this.onTap,
    this.mark,
    this.trailing,
    this.lit = true,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return PressScale(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: Duration(milliseconds: still ? 0 : 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: lit
                ? HaloColors.amber.withValues(alpha: 0.35)
                : HaloColors.line,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: HaloColors.amber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.serif(
                            size: 14,
                            color: HaloColors.text,
                            italic: true,
                          ),
                        ),
                      ),
                      if (mark != null) ...[const SizedBox(width: 7), mark!],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.sans(size: 11, color: HaloColors.text2),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
