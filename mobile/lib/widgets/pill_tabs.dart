// SPDX-License-Identifier: GPL-3.0-or-later
// tabs in a pill: the chosen one amber, the light easing between them. the
// sending sheet's and the shared page's
import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart' show kHouseCurve, motionStill;

class PillTabs extends StatelessWidget {
  final List<String> labels;
  final int at;
  final ValueChanged<int> onTap;
  const PillTabs({
    super.key,
    required this.labels,
    required this.at,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HaloColors.surface3,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == at,
                label: labels[i],
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: kHouseCurve,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == at ? HaloColors.amber : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: i == at ? HaloColors.onAmber : HaloColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
